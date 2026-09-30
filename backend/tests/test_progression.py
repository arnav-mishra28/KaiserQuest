import time
import unittest

from engine.attempts import Attempt
from engine.campaign import all_campaigns
from engine.concepts import get_concept_graph
from engine.progression import ProgressionService, RealmProgress, TrialResult
from engine.tracing import KnowledgeTracer

NOW = time.time()


def train(tracer, concept, count=4, correct=True, difficulty=None):
    level = tracer.graph.concept(concept).level if tracer.graph.has_concept(concept) else 3
    difficulty = difficulty or level
    for index in range(count):
        tracer.observe(
            Attempt(
                player_id="tester",
                concept=concept,
                question_id=f"train-{concept}-{index}",
                correct=correct,
                difficulty=difficulty,
                response_time_ms=9000,
                expected_time_ms=9000,
                timestamp=NOW,
            ),
            now=NOW,
        )


class EntryGateTests(unittest.TestCase):
    def setUp(self):
        self.graph = get_concept_graph()
        self.campaign = all_campaigns(self.graph)["algebra"]
        self.progression = ProgressionService(self.graph)
        self.tracer = KnowledgeTracer("tester", self.graph)
        self.progress = RealmProgress(realm="algebra")

    def test_first_milestone_always_open(self):
        milestone = self.campaign.milestone(1)
        check = self.progression.entry_check(self.campaign, milestone, self.progress, self.tracer)
        self.assertTrue(check["allowed"])

    def test_second_milestone_requires_the_first_to_be_cleared(self):
        milestone = self.campaign.milestone(2)
        check = self.progression.entry_check(self.campaign, milestone, self.progress, self.tracer)
        self.assertFalse(check["allowed"])
        self.assertTrue(check["reasons"])

    def test_clearing_the_first_opens_the_second_once_mastery_is_there(self):
        for concept in self.campaign.milestone(1).concepts:
            train(self.tracer, concept, 5)
        self.progress.mark_passed(1, "sigil")
        check = self.progression.entry_check(
            self.campaign, self.campaign.milestone(2), self.progress, self.tracer
        )
        self.assertTrue(check["allowed"])
        self.assertEqual(check["unmet"], [])

    def test_entry_gate_is_local_to_the_previous_milestone(self):
        """Regression: a cumulative gate would fight the forgetting mechanic."""
        check = self.progression.entry_check(
            self.campaign, self.campaign.milestone(6), RealmProgress(realm="algebra", passed=[5]), self.tracer
        )
        self.assertEqual(check["concepts"], list(self.campaign.milestone(5).concepts))

    def test_clearing_on_score_without_mastery_leaves_the_next_step_locked(self):
        self.progress.mark_passed(1, "sigil")
        check = self.progression.entry_check(
            self.campaign, self.campaign.milestone(2), self.progress, self.tracer
        )
        self.assertFalse(check["allowed"])
        self.assertTrue(check["unmet"], "the player should be told which concepts are missing")


class EvaluationTests(unittest.TestCase):
    def setUp(self):
        self.graph = get_concept_graph()
        self.campaign = all_campaigns(self.graph)["algebra"]
        self.progression = ProgressionService(self.graph)
        self.tracer = KnowledgeTracer("tester", self.graph)
        self.progress = RealmProgress(realm="algebra")
        self.milestone = self.campaign.milestone(1)

    def _result(self, correct, total):
        return TrialResult(milestone_index=self.milestone.index, correct=correct, total=total)

    def test_perfect_score_with_mastery_passes(self):
        for concept in self.milestone.concepts:
            train(self.tracer, concept, 5)
        outcome = self.progression.evaluate(
            self.campaign, self.milestone, self._result(4, 4), self.progress, self.tracer
        )
        self.assertTrue(outcome.passed)
        self.assertEqual(outcome.unlocked, 2)
        self.assertEqual(outcome.badge, self.milestone.badge_name)
        self.assertIn(self.milestone.index, self.progress.passed)
        self.assertIn(self.milestone.badge_name, self.progress.badges)

    def test_score_below_threshold_fails(self):
        for concept in self.milestone.concepts:
            train(self.tracer, concept, 5)
        outcome = self.progression.evaluate(
            self.campaign, self.milestone, self._result(1, 4), self.progress, self.tracer
        )
        self.assertFalse(outcome.passed)
        self.assertFalse(self.progress.has_passed(self.milestone.index))

    def test_high_score_without_mastery_fails_and_is_flagged_distinctly(self):
        # A run scraped through on guesses: the score is fine, the knowledge is not.
        outcome = self.progression.evaluate(
            self.campaign, self.milestone, self._result(4, 4), self.progress, self.tracer
        )
        self.assertFalse(outcome.passed)
        self.assertTrue(outcome.failed_on_mastery)
        self.assertTrue(outcome.blocked_by)
        self.assertIn("without holding", outcome.feedback)
        self.assertFalse(self.progress.has_passed(self.milestone.index))

    def test_mastery_gate_is_reachable_for_every_milestone(self):
        """A gate the trial cannot satisfy is a bug, not a standard."""
        for campaign in all_campaigns(self.graph).values():
            for milestone in campaign.milestones:
                per_concept = max(2, int(round(milestone.mode.questions * 0.5)) // max(1, len(milestone.concepts)))
                per_concept = max(2, per_concept)
                tracer = KnowledgeTracer("reach", self.graph)
                for concept in milestone.concepts:
                    train(tracer, concept, per_concept + 2)
                coverage, _ = tracer.coverage(list(milestone.concepts), milestone.mastery_gate)
                self.assertGreaterEqual(
                    coverage, 0.5,
                    f"{milestone.id} gates at {milestone.mastery_gate} but cannot be satisfied",
                )

    def test_failure_does_not_award_a_badge(self):
        self.progression.evaluate(
            self.campaign, self.milestone, self._result(0, 4), self.progress, self.tracer
        )
        self.assertEqual(self.progress.badges, [])

    def test_clearing_the_last_milestone_completes_the_realm(self):
        final = self.campaign.milestone(20)
        for concept in final.concepts:
            train(self.tracer, concept, 6)
        outcome = self.progression.evaluate(
            self.campaign, final, TrialResult(final.index, 15, 15), self.progress, self.tracer
        )
        self.assertTrue(outcome.passed)
        self.assertIsNone(outcome.unlocked)
        self.assertTrue(self.progress.completed)

    def test_replaying_a_cleared_milestone_stays_passed(self):
        for concept in self.milestone.concepts:
            train(self.tracer, concept, 5)
        self.progression.evaluate(
            self.campaign, self.milestone, self._result(4, 4), self.progress, self.tracer
        )
        outcome = self.progression.evaluate(
            self.campaign, self.milestone, self._result(4, 4), self.progress, self.tracer
        )
        self.assertTrue(outcome.passed)
        self.assertIn("already earned", outcome.feedback)

    def test_attempts_and_best_score_are_recorded(self):
        self.progress.record_attempt(1, 60.0)
        self.progress.record_attempt(1, 40.0)
        self.assertEqual(self.progress.attempts[1], 2)
        self.assertEqual(self.progress.best_score[1], 60.0)


class StatusTests(unittest.TestCase):
    def setUp(self):
        self.graph = get_concept_graph()
        self.campaign = all_campaigns(self.graph)["english"]
        self.progression = ProgressionService(self.graph)
        self.tracer = KnowledgeTracer("tester", self.graph)
        self.progress = RealmProgress(realm="english")

    def test_status_marks_current_and_locked_states(self):
        status = self.progression.status(self.campaign, self.progress, self.tracer)
        self.assertEqual(status["current"]["index"], 1)
        states = {entry["index"]: entry["state"] for entry in status["milestones"]}
        self.assertEqual(states[1], "available")
        self.assertEqual(states[2], "locked")
        self.assertEqual(status["passed_count"], 0)
        self.assertEqual(status["total"], 20)
        self.assertFalse(status["completed"])

    def test_status_reports_the_concepts_of_the_current_milestone_with_mastery(self):
        status = self.progression.status(self.campaign, self.progress, self.tracer)
        concepts = status["current"]["concepts"]
        self.assertTrue(concepts)
        for item in concepts:
            self.assertIn("name", item)
            self.assertIn("mastery", item)

    def test_cleared_milestones_show_as_cleared(self):
        self.progress.mark_passed(1, "sigil")
        status = self.progression.status(self.campaign, self.progress, self.tracer)
        states = {entry["index"]: entry["state"] for entry in status["milestones"]}
        self.assertEqual(states[1], "cleared")
        self.assertEqual(status["current"]["index"], 2)


if __name__ == "__main__":
    unittest.main()
