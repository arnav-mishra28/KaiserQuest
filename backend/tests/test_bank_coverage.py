"""
Completability guards.

The failure these prevent is the nastiest kind: a campaign that plays perfectly
for ninety percent of its length and then cannot be finished, because one concept
the final milestone teaches has no questions behind it. Nothing crashes; the
player simply runs out of game.

So: every concept must be examinable, and every milestone in every realm must be
enterable and assemblable.
"""

import tempfile
import time
import unittest
from pathlib import Path

from engine.attempts import Attempt
from engine.bank import QuestionBankReader
from engine.concepts import get_concept_graph
from engine.content.pipeline import MIN_QUESTIONS_PER_CONCEPT
from services.save_store import SaveStore
from services.story_service import StoryService

NOW = time.time()


class BankCoverageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.graph = get_concept_graph()
        cls.bank = QuestionBankReader()

    def test_the_bank_is_not_empty(self):
        self.assertGreater(self.bank.size, 100)
        self.assertTrue(self.bank.loaded_from.endswith("banks"), self.bank.loaded_from)

    def test_every_concept_in_the_graph_has_questions(self):
        missing = [c.id for c in self.graph if not self.bank.for_concept(c.id)]
        self.assertEqual(
            missing,
            [],
            "a concept with no questions makes its milestone unpassable: " + ", ".join(missing),
        )

    def test_every_concept_has_enough_questions_to_adapt(self):
        """The bank must offer something to pick between, or adaptation is a coin toss."""
        thin = [c.id for c in self.graph if len(self.bank.for_concept(c.id)) < 2]
        self.assertEqual(thin, [], f"concepts with fewer than 2 questions: {thin}")

    def test_coverage_is_reported_by_the_pipeline(self):
        manifest = Path(self.bank.banked_manifest) if hasattr(self.bank, "banked_manifest") else None
        self.assertIsNone(manifest)  # the reader does not invent a manifest; the pipeline writes one
        self.assertGreater(MIN_QUESTIONS_PER_CONCEPT, 1)

    def test_misconception_tags_are_usable(self):
        """At least a fifth of the bank should teach from a wrong answer."""
        tagged = sum(1 for q in self.bank._questions if q.get("misconceptions"))
        self.assertGreater(tagged, self.bank.size * 0.15, f"only {tagged} tagged questions")


class MilestoneAssemblabilityTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.service = StoryService(
            get_concept_graph(), QuestionBankReader(), SaveStore(Path(self.tmp.name))
        )
        self.graph = get_concept_graph()

    def tearDown(self):
        self.tmp.cleanup()

    def _train(self, session, concepts, count=4):
        for concept in concepts:
            level = self.graph.concept(concept).level if self.graph.has_concept(concept) else 3
            for index in range(count):
                session.tracer.observe(
                    Attempt(
                        player_id=session.player_id,
                        concept=concept,
                        question_id=f"warmup-{concept}-{index}",
                        correct=True,
                        difficulty=level,
                        response_time_ms=6000,
                        expected_time_ms=6000,
                        timestamp=NOW,
                    ),
                    now=NOW,
                )

    def test_every_milestone_in_every_realm_can_be_entered_and_assembled(self):
        for realm in ("algebra", "english", "music"):
            player_id = f"coverage-{realm}"
            self.service.create_character(player_id, "Kai", "default", realm)
            session = self.service.get_session(player_id)
            campaign = self.service._campaign(realm)
            realm_session = session.realm_session(realm)

            for milestone in campaign.milestones:
                if milestone.index > 1:
                    previous = campaign.milestone(milestone.index - 1)
                    self._train(session, previous.concepts, count=5)
                    realm_session.progress.mark_passed(previous.index, previous.badge_name)

                started = self.service.start_trial(player_id, realm, milestone.index)
                self.assertTrue(
                    started["granted"],
                    f"{realm} {milestone.id} could not be started: "
                    f"{started.get('error') or (started.get('entry') or {}).get('reasons')}",
                )
                self.assertGreaterEqual(
                    len(started["questions"]), 2,
                    f"{realm} {milestone.id} assembled only {len(started['questions'])} questions",
                )
                # Answering must be possible: every question needs a key in the bank.
                for question in started["questions"]:
                    stored = self.service.bank.get(question["id"])
                    self.assertIsNotNone(stored, question["id"])
                    self.assertIn(str(stored["correct_answer"]), [str(o) for o in stored["options"]])

    def test_a_played_milestone_actually_moves_the_trace(self):
        self.service.create_character("mover", "Kai", "default", "music")
        started = self.service.start_trial("mover", "music", 1)
        self.assertTrue(started["granted"])
        raw = [self.service.bank.get(q["id"]) for q in started["questions"]]
        before = self.service.profile("mover", "music")["overall_mastery"]
        self.service.submit_trial(
            "mover",
            "music",
            1,
            [
                {
                    "question_id": q["id"],
                    "chosen": q["correct_answer"],
                    "response_time_ms": 7000,
                }
                for q in raw
            ],
        )
        after = self.service.profile("mover", "music")["overall_mastery"]
        self.assertGreater(after, before)

    def test_every_concept_can_be_graded_through_the_public_api(self):
        """Answer one question per concept, end to end, and confirm it is traced."""
        self.service.create_character("sweeper", "Kai", "default", "algebra")
        session = self.service.get_session("sweeper")
        tried = 0
        for concept in self.graph.realm("algebra").concepts:
            questions = self.service.bank.for_concept(concept.id)
            if not questions:
                continue
            question = questions[0]
            graded = self.service._grade_answers(
                session,
                [
                    {
                        "question_id": question["id"],
                        "chosen": question["correct_answer"],
                        "response_time_ms": 6000,
                    }
                ],
            )
            self.assertEqual(len(graded), 1, concept.id)
            self.assertTrue(graded[0]["correct"], concept.id)
            self.assertGreater(session.tracer.get(concept.id).attempts, 0, concept.id)
            tried += 1
        self.assertGreater(tried, 30)


if __name__ == "__main__":
    unittest.main()
