"""
API-level tests.

These exercise the routes the Unity client actually calls, including the
property that matters most at the boundary: the server must never hand the
answer key to the client.
"""

import tempfile
import unittest
from pathlib import Path

try:
    from fastapi.testclient import TestClient

    HAS_TESTCLIENT = True
except ImportError:  # pragma: no cover - httpx may be absent
    HAS_TESTCLIENT = False

if HAS_TESTCLIENT:
    import main as backend_main
    from services import story_service as story_module
    from services.save_store import SaveStore


@unittest.skipUnless(HAS_TESTCLIENT, "fastapi TestClient (httpx) not installed")
class StoryApiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        # Isolate the API's saves so the test suite never touches real ones.
        story_module._SERVICE = story_module.StoryService(store=SaveStore(Path(cls.tmp.name)))
        cls.client = TestClient(backend_main.app)

    @classmethod
    def tearDownClass(cls):
        story_module._SERVICE = None
        cls.tmp.cleanup()

    def test_health_lists_the_story_endpoints(self):
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertIn("story_profile", payload["endpoints"])
        self.assertIn("silver_mountain", payload["endpoints"])

    def test_realms_are_served(self):
        response = self.client.get("/story/realms")
        self.assertEqual(response.status_code, 200)
        realms = response.json()["realms"]
        self.assertEqual({r["id"] for r in realms}, {"algebra", "english", "music"})
        for realm in realms:
            self.assertEqual(realm["milestones"], 20)

    def test_appearances_are_served(self):
        response = self.client.get("/story/appearances")
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()["appearances"])

    def test_concepts_endpoint(self):
        response = self.client.get("/concepts")
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()["realms"])
        scoped = self.client.get("/concepts", params={"realm": "music"})
        self.assertEqual(scoped.status_code, 200)
        self.assertEqual(scoped.json()["realm"]["id"], "music")
        self.assertEqual(self.client.get("/concepts", params={"realm": "nope"}).status_code, 404)

    def test_content_coverage_endpoint(self):
        response = self.client.get("/content/coverage")
        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertGreater(payload["questions"], 100)
        self.assertGreater(payload["concepts"], 50)

    def test_character_creation_and_profile(self):
        created = self.client.post(
            "/story/character",
            json={"player_id": "api-hero", "name": "Kai", "realm": "algebra"},
        )
        self.assertEqual(created.status_code, 200)
        self.assertEqual(created.json()["realm"], "algebra")

        profile = self.client.get("/story/api-hero/profile")
        self.assertEqual(profile.status_code, 200)
        body = profile.json()
        self.assertIn("tree", body)
        self.assertEqual(body["overall_mastery"], 0.0)

    def test_unknown_realm_is_a_client_error_not_a_crash(self):
        response = self.client.post(
            "/story/character",
            json={"player_id": "api-bad", "name": "Kai", "realm": "astrophysics"},
        )
        self.assertEqual(response.status_code, 400)

    def test_progress_and_milestones_endpoints(self):
        self.client.post(
            "/story/character", json={"player_id": "api-2", "name": "Kai", "realm": "music"}
        )
        progress = self.client.get("/story/api-2/progress")
        self.assertEqual(progress.status_code, 200)
        self.assertEqual(progress.json()["current"]["index"], 1)

        milestones = self.client.get("/story/api-2/milestones")
        self.assertEqual(milestones.status_code, 200)
        self.assertEqual(len(milestones.json()["milestones"]), 20)
        first = milestones.json()["milestones"][0]
        self.assertTrue(first["narrative"]["setup"])
        self.assertIn("trial", first)

    def test_a_full_trial_round_trip_over_http(self):
        self.client.post(
            "/story/character", json={"player_id": "api-3", "name": "Kai", "realm": "english"}
        )
        started = self.client.post("/story/api-3/trial/start", json={})
        self.assertEqual(started.status_code, 200)
        payload = started.json()
        self.assertTrue(payload["granted"])

        # The answer key must never cross this boundary.
        for question in payload["questions"]:
            self.assertNotIn("correct_answer", question)
            self.assertNotIn("explanation", question)

        # Answer with the bank's key via the internal service, then submit.
        service = story_module._SERVICE
        answers = []
        for question in payload["questions"]:
            stored = service.bank.get(question["id"])
            answers.append(
                {
                    "question_id": question["id"],
                    "chosen": stored["correct_answer"],
                    "response_time_ms": 8000,
                }
            )
        result = self.client.post(
            "/story/api-3/trial/submit",
            json={"index": 1, "answers": answers},
        )
        self.assertEqual(result.status_code, 200)
        body = result.json()
        self.assertIn("outcome", body)
        self.assertTrue(body["outcome"]["passed"], body["outcome"])
        self.assertTrue(body["answers"][0]["correct"])

    def test_silver_mountain_is_reported_before_it_is_reachable(self):
        self.client.post(
            "/story/character", json={"player_id": "api-4", "name": "Kai", "realm": "algebra"}
        )
        status = self.client.get("/story/api-4/silver")
        self.assertEqual(status.status_code, 200)
        body = status.json()
        self.assertFalse(body["allowed"])
        self.assertFalse(body["can_challenge"])
        self.assertEqual(body["attempts_remaining"], 3)
        self.assertEqual(body["milestones_total"], 20)

        challenge = self.client.post("/story/api-4/silver/challenge", json={})
        self.assertEqual(challenge.status_code, 200)
        self.assertFalse(challenge.json()["granted"])

    def test_recap_endpoint_returns_steps(self):
        self.client.post(
            "/story/character", json={"player_id": "api-5", "name": "Kai", "realm": "algebra"}
        )
        recap = self.client.get("/story/api-5/recap")
        self.assertEqual(recap.status_code, 200)
        self.assertTrue(recap.json()["steps"])

    def test_save_point_endpoint(self):
        self.client.post(
            "/story/character", json={"player_id": "api-6", "name": "Kai", "realm": "algebra"}
        )
        response = self.client.post(
            "/story/api-6/save-point",
            json={"index": 4, "place": "the stone bridge"},
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["milestone_index"], 4)
        self.assertEqual(response.json()["place"], "the stone bridge")

    def test_saves_are_listed(self):
        response = self.client.get("/story/saves")
        self.assertEqual(response.status_code, 200)
        self.assertGreaterEqual(response.json()["count"], 1)

    def test_index_validation_is_enforced(self):
        self.client.post(
            "/story/character", json={"player_id": "api-7", "name": "Kai", "realm": "algebra"}
        )
        bad = self.client.post("/story/api-7/trial/start", json={"index": 99})
        self.assertEqual(bad.status_code, 422)


if __name__ == "__main__":
    unittest.main()
