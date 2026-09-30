import tempfile
import time
import unittest
from pathlib import Path

from engine.bank import QuestionBankReader
from engine.concepts import get_concept_graph
from engine.silver_mountain import ATTEMPTS_PER_WINDOW, COOLDOWN_HOURS
from services.save_store import SaveStore
from services.story_service import StoryService


def answer(question, correct=True):
    """Build a submission payload with the right (or a wrong) answer."""
    options = list(question.get("options") or [])
    key = str(question.get("correct_answer"))
    if correct:
        chosen = key
    else:
        wrong = [o for o in options if str(o) != key]
        chosen = wrong[0] if wrong else "definitely not the answer"
    return {
        "question_id": question["id"],
        "chosen": chosen,
        "response_time_ms": 9000,
        "hints_used": 0,
        "tries": 1,
    }


class StoryServiceTestCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.store = SaveStore(Path(self.tmp.name))
        self.bank = QuestionBankReader()
        self.service = StoryService(get_concept_graph(), self.bank, self.store)
        self.graph = get_concept_graph()

    def tearDown(self):
        self.tmp.cleanup()

    def _raw(self, questions):
        """Public questions carry no answer key; look the keys up in the bank."""
        return [self.bank.get(q["id"]) for q in questions]

    def play_milestone(self, player_id, index, correct=True, realm=None):
        started = self.service.start_trial(player_id, realm, index)
        if not started["granted"]:
            return {"granted": False, "reason": started.get("entry")}
        raw = self._raw(started["questions"])
        submission = [answer(question, correct) for question in raw]
        return self.service.submit_trial(player_id, realm, index, submission)


class CharacterAndProfileTests(StoryServiceTestCase):
    def test_realms_are_listed_with_their_campaigns(self):
        realms = self.service.realms()
        self.assertEqual({r["id"] for r in realms}, {"algebra", "english", "music"})
        for realm in realms:
            self.assertEqual(realm["milestones"], 20)
            self.assertGreater(realm["concept_count"], 0)
            self.assertTrue(realm["region"])

    def test_create_character_sets_a_save_point_in_the_first_place(self):
        created = self.service.create_character("p1", "Kai", "scholar", "algebra")
        self.assertEqual(created["name"], "Kai")
        self.assertEqual(created["realm"], "algebra")
        self.assertTrue(created["started_at_place"])
        self.assertGreaterEqual(len(created["appearances_available"]), 3)

    def test_character_name_is_sanitised_and_bounded(self):
        created = self.service.create_character("p2", "   A" * 40, "default", "music")
        self.assertLessEqual(len(created["name"]), 24)

    def test_unknown_realm_is_rejected(self):
        with self.assertRaises(KeyError):
            self.service.create_character("p3", "Kai", "default", "astrophysics")

    def test_profile_starts_empty_and_renders_a_tree(self):
        self.service.create_character("p4", "Kai", "default", "algebra")
        profile = self.service.profile("p4", "algebra")
        self.assertEqual(profile["overall_mastery"], 0.0)
        self.assertIn("Algebra", profile["tree"])
        self.assertEqual(profile["confidence"]["Weak"], 100)
        self.assertTrue(profile["next_up"])

    def test_profile_reports_mastery_after_answering(self):
        self.service.create_character("p5", "Kai", "default", "algebra")
        self.play_milestone("p5", 1, correct=True)
        profile = self.service.profile("p5", "algebra")
        self.assertGreater(profile["overall_mastery"], 0.0)

        attempted = [
            concept
            for domain in profile["domains"]
            for concept in domain["concepts"]
            if concept["attempts"] > 0
        ]
        self.assertTrue(attempted, "the profile must show what was actually answered")
        for concept in attempted:
            self.assertGreater(concept["mastery"], 0.0, concept["id"])
            self.assertNotEqual(concept["confidence"], "Weak")

        self.assertLess(profile["confidence"]["Weak"], 100)
        self.assertGreater(profile["domains"][0]["mastery"], 0.0)


class TrialFlowTests(StoryServiceTestCase):
    def setUp(self):
        super().setUp()
        self.service.create_character("hero", "Kai", "default", "algebra")

    def test_trial_serves_questions_without_the_answer_key(self):
        started = self.service.start_trial("hero", "algebra", 1)
        self.assertTrue(started["granted"])
        self.assertTrue(started["questions"])
        for question in started["questions"]:
            self.assertNotIn("correct_answer", question)
            self.assertNotIn("explanation", question)
            self.assertTrue(question["question"])
            self.assertGreaterEqual(len(question["options"]), 2)
            self.assertTrue(question["concept"])

    def test_trial_length_matches_the_mode(self):
        started = self.service.start_trial("hero", "algebra", 1)
        self.assertEqual(len(started["questions"]), started["milestone"]["trial"]["questions"])

    def test_later_milestones_are_locked_at_the_start(self):
        started = self.service.start_trial("hero", "algebra", 5)
        self.assertFalse(started["granted"])
        self.assertTrue(started["entry"]["reasons"])

    def test_perfect_run_passes_and_awards_a_sigil(self):
        result = self.play_milestone("hero", 1, correct=True)
        self.assertTrue(result["outcome"]["passed"], result["outcome"])
        self.assertEqual(result["outcome"]["badge"], result["progress"]["badges"][0])
        self.assertEqual(result["progress"]["passed_count"], 1)

    def test_all_wrong_answers_fail_and_explain(self):
        result = self.play_milestone("hero", 1, correct=False)
        self.assertFalse(result["outcome"]["passed"])
        self.assertTrue(result["outcome"]["blocked_by"])
        self.assertEqual(result["progress"]["passed_count"], 0)

    def test_grading_returns_teaching_feedback_for_every_question(self):
        result = self.play_milestone("hero", 1, correct=False)
        self.assertTrue(result["answers"])
        for graded in result["answers"]:
            self.assertFalse(graded["correct"])
            self.assertTrue(graded["correct_answer"])
            self.assertTrue(graded["explanation"])
            self.assertLess(graded["mastery_after"], 100)

    def test_a_tagged_misconception_comes_back_named(self):
        """Answer every question with a distractor the generator tagged."""
        started = self.service.start_trial("hero", "algebra", 1)
        raw = self._raw(started["questions"])
        submission = []
        for question in raw:
            mapping = question.get("misconceptions") or {}
            chosen = next((d for d in mapping if d in question["options"]), None)
            submission.append(
                {
                    "question_id": question["id"],
                    "chosen": chosen or "nonsense",
                    "response_time_ms": 9000,
                }
            )
        result = self.service.submit_trial("hero", "algebra", 1, submission)
        named = [m for graded in result["answers"] for m in graded["misconceptions"]]
        self.assertTrue(named, "tagged distractors should produce named misconceptions")
        self.assertTrue(all(m.get("remedy") for m in named if m["misconception_id"]))

    def test_mastery_is_traced_against_the_right_concept(self):
        started = self.service.start_trial("hero", "algebra", 1)
        raw = self._raw(started["questions"])
        concepts = {q["concept"] for q in raw}
        self.service.submit_trial(
            "hero", "algebra", 1, [answer(q, True) for q in raw]
        )
        for concept in concepts:
            self.assertGreater(
                self.service.get_session("hero").tracer.get(concept).attempts, 0, concept
            )

    def test_scores_and_attempt_counts_are_recorded(self):
        self.play_milestone("hero", 1, correct=False)
        progress = self.service.progress("hero", "algebra")
        entry = next(e for e in progress["milestones"] if e["index"] == 1)
        self.assertEqual(entry["attempts"], 1)


class AdaptiveDifficultyTests(StoryServiceTestCase):
    def test_a_mastered_concept_is_asked_about_harder_than_an_unknown_one(self):
        self.service.create_character("hero", "Kai", "default", "algebra")
        session = self.service.get_session("hero")

        from engine.attempts import Attempt

        for index in range(10):
            session.tracer.observe(
                Attempt(
                    player_id="hero",
                    concept="variables.meaning",
                    question_id=f"q{index}",
                    correct=True,
                    difficulty=4,
                    response_time_ms=6000,
                    expected_time_ms=6000,
                )
            )
        mastered = self.service._target_difficulty(session, "variables.meaning")
        # An untouched concept is asked about at its curriculum level, which for
        # a level-2 concept is far below where the mastered one is pushed to.
        unknown = self.service._target_difficulty(session, "graphs.plane")
        self.assertGreater(mastered, unknown)
        self.assertGreaterEqual(mastered, 1)
        self.assertLessEqual(mastered, 5)

    def test_struggling_on_a_concept_lowers_its_target(self):
        self.service.create_character("hero", "Kai", "default", "algebra")
        session = self.service.get_session("hero")
        from engine.attempts import Attempt

        for index in range(8):
            session.tracer.observe(
                Attempt(
                    player_id="hero",
                    concept="linear.two_step",
                    question_id=f"q{index}",
                    correct=False,
                    difficulty=5,
                    response_time_ms=9000,
                    expected_time_ms=9000,
                )
            )
        target = self.service._target_difficulty(session, "linear.two_step")
        self.assertLessEqual(target, 2)


class PersistenceTests(StoryServiceTestCase):
    def test_progress_survives_a_restart(self):
        self.service.create_character("hero", "Kai", "default", "algebra")
        self.play_milestone("hero", 1, correct=True)
        expected = self.service.get_session("hero").tracer.p_known("variables.meaning", decayed=False)
        save_place = self.service.get_session("hero").last_save["place"]

        # A fresh service, as if the backend had been restarted.
        reloaded = StoryService(get_concept_graph(), self.bank, self.store)
        session = reloaded.get_session("hero")
        self.assertEqual(session.name, "Kai")
        self.assertAlmostEqual(
            session.tracer.p_known("variables.meaning", decayed=False), expected, places=9
        )
        self.assertEqual(session.last_save["place"], save_place)
        self.assertIn(1, session.realm_session("algebra").progress.passed)

    def test_attempt_history_survives_a_restart(self):
        self.service.create_character("hero", "Kai", "default", "algebra")
        self.play_milestone("hero", 1, correct=True)
        count = len(self.service.get_session("hero").log)
        reloaded = StoryService(get_concept_graph(), self.bank, self.store)
        self.assertEqual(len(reloaded.get_session("hero").log), count)

    def test_saves_are_listed(self):
        self.service.create_character("hero", "Kai", "default", "algebra")
        saves = self.service.saves()
        self.assertTrue(any(s["player_id"] == "hero" for s in saves))

    def test_save_point_moves_forward_on_a_pass(self):
        self.service.create_character("hero", "Kai", "default", "algebra")
        before = dict(self.service.get_session("hero").last_save)
        self.play_milestone("hero", 1, correct=True)
        after = self.service.get_session("hero").last_save
        self.assertGreaterEqual(after["milestone_index"], before["milestone_index"])

    def test_manual_save_point_is_clamped_to_the_campaign(self):
        self.service.create_character("hero", "Kai", "default", "algebra")
        clamped = self.service.save_point("hero", "algebra", 999, "somewhere")
        self.assertEqual(clamped["milestone_index"], 20)
        self.assertEqual(clamped["place"], "somewhere")


class FullCampaignTests(StoryServiceTestCase):
    def test_a_perfect_player_clears_the_whole_realm_and_the_mountain(self):
        self.service.create_character("hero", "Kai", "default", "algebra")
        campaign = self.service._campaign("algebra")

        for milestone in campaign.milestones:
            # A determined player retries until the mastery gate is satisfied.
            for attempt in range(4):
                result = self.play_milestone("hero", milestone.index, correct=True)
                if result["outcome"]["passed"]:
                    break
            self.assertTrue(
                result["outcome"]["passed"],
                f"milestone {milestone.index} ({milestone.mode.id}) not cleared after retries: "
                f"{result['outcome']['blocked_by']}",
            )

        progress = self.service.progress("hero", "algebra")
        self.assertEqual(progress["passed_count"], 20)
        self.assertTrue(progress["completed"])

        status = self.service.silver_status("hero", "algebra")
        self.assertTrue(status["allowed"])
        self.assertTrue(status["can_challenge"])
        self.assertEqual(status["attempts_remaining"], ATTEMPTS_PER_WINDOW)

        challenge = self.service.silver_challenge("hero", "algebra")
        self.assertTrue(challenge["granted"])
        self.assertTrue(challenge["questions"])
        bands = {slot["band"] for slot in challenge["slots"]}
        self.assertTrue(bands, "the exam should be assembled from the profile")

        raw = self._raw(challenge["questions"])
        submission = [answer(q, True) for q in raw]
        result = self.service.silver_submit("hero", "algebra", submission)
        self.assertTrue(result["graded"])
        self.assertTrue(result["result"]["passed"], result["answers"])
        self.assertTrue(result["status"]["cleared"])

    def test_failing_the_mountain_three_times_sends_you_back_with_a_recap(self):
        self.service.create_character("hero", "Kai", "default", "algebra")
        campaign = self.service._campaign("algebra")
        session = self.service.get_session("hero")
        # Fast-forward: the summit only checks the milestone record.
        for milestone in campaign.milestones:
            session.realm_session("algebra").progress.mark_passed(milestone.index, milestone.badge_name)

        final = None
        for attempt in range(ATTEMPTS_PER_WINDOW):
            challenge = self.service.silver_challenge("hero", "algebra")
            self.assertTrue(challenge["granted"], attempt)
            raw = self._raw(challenge["questions"])
            final = self.service.silver_submit("hero", "algebra", [answer(q, False) for q in raw])

        self.assertFalse(final["result"]["passed"])
        self.assertTrue(final["return_to_save"], "the player must be returned to the last save point")
        self.assertEqual(final["status"]["attempts_remaining"], 0)
        self.assertFalse(final["status"]["can_challenge"])
        self.assertGreater(final["status"]["cooldown_remaining_seconds"], 0)

        recap = self.service.recap("hero", "algebra")
        self.assertTrue(recap["steps"])
        self.assertEqual(recap["cooldown_hours"], COOLDOWN_HOURS)
        self.assertTrue(recap["summary"])
        self.assertTrue(any(step["body"] for step in recap["steps"]))

        # And the mountain stays shut until the cooldown expires.
        self.assertFalse(self.service.silver_challenge("hero", "algebra")["granted"])

    def test_cooldown_expiry_reopens_the_mountain(self):
        self.service.create_character("hero", "Kai", "default", "algebra")
        campaign = self.service._campaign("algebra")
        session = self.service.get_session("hero")
        for milestone in campaign.milestones:
            session.realm_session("algebra").progress.mark_passed(milestone.index, milestone.badge_name)

        state = session.realm_session("algebra").silver
        state.attempts_remaining = 0
        state.cooldown_until = time.time() - 1

        status = self.service.silver_status("hero", "algebra")
        self.assertTrue(status["can_challenge"])
        self.assertEqual(status["attempts_remaining"], ATTEMPTS_PER_WINDOW)
        self.assertTrue(self.service.silver_challenge("hero", "algebra")["granted"])

    def test_guessing_does_not_clear_the_first_milestone(self):
        self.service.create_character("guesser", "Kai", "default", "algebra")
        for _ in range(3):
            result = self.play_milestone("guesser", 1, correct=False)
        self.assertFalse(result["outcome"]["passed"])
        progress = self.service.progress("guesser", "algebra")
        self.assertEqual(progress["passed_count"], 0)
        self.assertEqual(progress["current"]["index"], 1)


if __name__ == "__main__":
    unittest.main()
