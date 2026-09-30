import time
import unittest

from engine.attempts import Attempt, AttemptLog, estimate_expected_time_ms
from engine.concepts import get_concept_graph
from engine.tracing import (
    MASTERED_P_KNOWN,
    ConceptKnowledge,
    KnowledgeTracer,
)

DAY = 86400.0

# A realistic base clock: the tracer decays against wall-clock time, so tests
# that pass now=1000.0 would be measuring fifty-six years of forgetting.
NOW = time.time()


def make_attempt(
    concept="linear.two_step",
    correct=True,
    difficulty=3,
    response_time_ms=8000,
    expected_time_ms=8000,
    hints=0,
    tries=1,
    timestamp=None,
    question_id="q",
):
    return Attempt(
        player_id="tester",
        concept=concept,
        question_id=question_id,
        correct=correct,
        difficulty=difficulty,
        response_time_ms=response_time_ms,
        expected_time_ms=expected_time_ms,
        hints_used=hints,
        tries=tries,
        timestamp=timestamp if timestamp is not None else time.time(),
    )


class ConceptKnowledgeTests(unittest.TestCase):
    def test_starts_at_prior(self):
        knowledge = ConceptKnowledge("linear.two_step", params=__import__(
            "engine.tracing", fromlist=["BKTParams"]
        ).BKTParams.for_level(3))
        self.assertGreater(knowledge.p_known, 0.0)
        self.assertEqual(knowledge.attempts, 0)
        self.assertEqual(knowledge.mastery(), 0.0)

    def test_correct_answers_increase_knowledge(self):
        knowledge = ConceptKnowledge("x")
        before = knowledge.p_known
        knowledge.observe(make_attempt(correct=True), now=1000.0)
        self.assertGreater(knowledge.p_known, before)

    def test_wrong_answers_decrease_knowledge(self):
        knowledge = ConceptKnowledge("x")
        for i in range(5):
            knowledge.observe(make_attempt(correct=True, timestamp=1000.0 + i), now=1000.0 + i)
        peak = knowledge.p_known
        knowledge.observe(make_attempt(correct=False, timestamp=1010.0), now=1010.0)
        self.assertLess(knowledge.p_known, peak)

    def test_evidence_repeat_count(self):
        knowledge = ConceptKnowledge("x")
        for i in range(5):
            knowledge.observe(make_attempt(correct=True, timestamp=1000.0 + i), now=1000.0 + i)
        self.assertEqual(knowledge.correct, 5)
        self.assertEqual(knowledge.attempts, 5)

    def test_hinted_correct_is_weaker_evidence(self):
        unaided = ConceptKnowledge("x")
        hinted = ConceptKnowledge("x")
        unaided.observe(make_attempt(correct=True, hints=0), now=1000.0)
        hinted.observe(make_attempt(correct=True, hints=2), now=1000.0)
        self.assertGreater(unaided.p_known, hinted.p_known)

    def test_mastery_requires_attempts_not_just_a_lucky_start(self):
        knowledge = ConceptKnowledge("x", reference_level=3)
        self.assertEqual(knowledge.mastery(), 0.0)
        knowledge.observe(make_attempt(correct=True), now=NOW)
        self.assertLess(knowledge.mastery(), 50.0, "one answer is not mastery")
        self.assertLess(knowledge.mastery(), knowledge.p_known_now() * 100)

    def test_mastery_rises_with_evidence(self):
        knowledge = ConceptKnowledge("x", reference_level=3)
        curve = []
        for _ in range(5):
            knowledge.observe(make_attempt(correct=True, timestamp=NOW), now=NOW)
            curve.append(knowledge.mastery())
        self.assertEqual(curve, sorted(curve), "mastery should not fall as evidence accumulates")
        self.assertGreater(curve[-1], 85.0)
        self.assertLess(curve[0], 50.0)

    def test_difficulty_ceiling_tracks_hardest_success(self):
        knowledge = ConceptKnowledge("x")
        knowledge.observe(make_attempt(correct=True, difficulty=2), now=1000.0)
        knowledge.observe(make_attempt(correct=True, difficulty=5), now=1001.0)
        knowledge.observe(make_attempt(correct=False, difficulty=5), now=1002.0)
        self.assertEqual(knowledge.difficulty_ceiling, 5)

    def test_forgetting_decays_over_time(self):
        knowledge = ConceptKnowledge("x")
        for i in range(8):
            knowledge.observe(make_attempt(correct=True, timestamp=1000.0), now=1000.0)
        fresh = knowledge.p_known_now(now=1000.0)
        later = knowledge.p_known_now(now=1000.0 + 60 * DAY)
        self.assertGreater(fresh, later)
        self.assertGreater(later, 0.0, "retention should have a floor, not reach zero")

    def test_rusty_concept_is_flagged_not_lost(self):
        # Learned solidly, 90 days ago.
        past = NOW - 90 * DAY
        knowledge = ConceptKnowledge("x", reference_level=3)
        for i in range(10):
            knowledge.observe(make_attempt(correct=True, timestamp=past), now=past)

        self.assertGreater(knowledge.p_known, MASTERED_P_KNOWN, "it was genuinely learned")
        self.assertLess(knowledge.p_known_now(), MASTERED_P_KNOWN, "but it has faded")
        self.assertTrue(knowledge.is_rusty, "so the game should offer a recap, not a lesson")
        self.assertFalse(knowledge.is_mastered)

    def test_recently_practised_concept_is_not_flagged_rusty(self):
        knowledge = ConceptKnowledge("x", reference_level=3)
        for i in range(10):
            knowledge.observe(make_attempt(correct=True, timestamp=NOW), now=NOW)
        self.assertTrue(knowledge.is_mastered)
        self.assertFalse(knowledge.is_rusty)

    def test_confidence_buckets_need_evidence(self):
        knowledge = ConceptKnowledge("x", reference_level=3)
        knowledge.observe(make_attempt(correct=True, timestamp=NOW), now=NOW)
        self.assertEqual(knowledge.confidence(NOW), "Weak", "one answer is not confidence")
        for i in range(12):
            knowledge.observe(make_attempt(correct=True, timestamp=NOW), now=NOW)
        self.assertEqual(knowledge.confidence(NOW), "Strong")

    def test_harder_questions_give_stronger_evidence_when_correct(self):
        # reference_level is what a question is judged against, so both concepts
        # are pinned to the same baseline and only the question difficulty varies.
        easy = ConceptKnowledge("x", reference_level=3)
        hard = ConceptKnowledge("x", reference_level=3)
        easy.observe(make_attempt(correct=True, difficulty=1), now=NOW)
        hard.observe(make_attempt(correct=True, difficulty=5), now=NOW)
        self.assertNotAlmostEqual(easy.p_known, hard.p_known, places=3)
        self.assertGreater(hard.p_known, easy.p_known)

    def test_difficulty_adjustment_is_active_on_first_contact(self):
        """Regression: with no baseline, difficulty adjustment used to be inert."""
        first_easy = ConceptKnowledge("x", reference_level=4)
        first_hard = ConceptKnowledge("x", reference_level=4)
        first_easy.observe(make_attempt(correct=True, difficulty=1), now=NOW)
        first_hard.observe(make_attempt(correct=True, difficulty=4), now=NOW)
        self.assertNotAlmostEqual(first_easy.p_known, first_hard.p_known, places=4)

    def test_serialisation_round_trip(self):
        knowledge = ConceptKnowledge("x", reference_level=3)
        for i in range(4):
            knowledge.observe(make_attempt(correct=i % 2 == 0, timestamp=NOW + i), now=NOW + i)
        restored = ConceptKnowledge.from_dict(knowledge.to_dict())
        self.assertEqual(restored.attempts, knowledge.attempts)
        self.assertAlmostEqual(restored.p_known, knowledge.p_known, places=9)
        self.assertEqual(restored.difficulty_ceiling, knowledge.difficulty_ceiling)
        self.assertEqual(restored.reference_level, knowledge.reference_level)


class AttemptTests(unittest.TestCase):
    def test_fast_error_detection(self):
        slow_wrong = make_attempt(correct=False, response_time_ms=9000, expected_time_ms=9000)
        fast_wrong = make_attempt(correct=False, response_time_ms=900, expected_time_ms=9000)
        self.assertFalse(slow_wrong.is_fast_error)
        self.assertTrue(fast_wrong.is_fast_error)

    def test_evidence_weight_ordering(self):
        clean = make_attempt(correct=True)
        hinted = make_attempt(correct=True, hints=3)
        retried = make_attempt(correct=True, tries=3)
        fast_wrong = make_attempt(correct=False, response_time_ms=100, expected_time_ms=9000)
        considered_wrong = make_attempt(correct=False, response_time_ms=9000, expected_time_ms=9000)
        self.assertGreater(clean.evidence_weight, hinted.evidence_weight)
        self.assertGreater(clean.evidence_weight, retried.evidence_weight)
        # A rushed mistake says less about knowledge than a considered one.
        self.assertGreater(considered_wrong.evidence_weight, fast_wrong.evidence_weight)
        self.assertLessEqual(clean.evidence_weight, 1.0)
        self.assertGreaterEqual(fast_wrong.evidence_weight, 0.15)

    def test_expected_time_scales_with_question_length(self):
        short = estimate_expected_time_ms("2 + 2 = ?", ["3", "4"])
        long = estimate_expected_time_ms("A train travels 240 km in 4 hours. " * 3, ["a", "b", "c", "d"])
        self.assertGreater(long, short)

    def test_log_queries(self):
        log = AttemptLog()
        for i in range(4):
            log.add(make_attempt(concept="a", correct=i % 2 == 0, timestamp=NOW + i, question_id=f"q{i}"))
        log.add(make_attempt(concept="b", correct=True, timestamp=NOW + 10))
        self.assertEqual(len(log.for_concept("a")), 4)
        self.assertEqual(log.accuracy("a"), 0.5)
        self.assertEqual(log.accuracy("b"), 1.0)
        self.assertEqual(len(log.fast_errors()), 0)

    def test_log_round_trip(self):
        log = AttemptLog()
        log.add(make_attempt(concept="a"))
        restored = AttemptLog.from_list(log.to_list())
        self.assertEqual(len(restored), 1)
        self.assertEqual(restored.all[0].concept, "a")


class TracerTests(unittest.TestCase):
    def setUp(self):
        self.graph = get_concept_graph()
        self.tracer = KnowledgeTracer("tester", self.graph)

    def test_observe_returns_outcome_with_before_and_after(self):
        outcome = self.tracer.observe(make_attempt(correct=True))
        self.assertLess(outcome.p_known_before, outcome.p_known_after)
        self.assertEqual(outcome.confidence_after, "Weak")

    def test_unknown_concept_is_still_tracked(self):
        self.tracer.observe(make_attempt(concept="not.in.graph", correct=True))
        self.assertEqual(self.tracer.get("not.in.graph").attempts, 1)

    def test_realm_mastery_counts_unsampled_concepts_as_zero(self):
        self.assertEqual(self.tracer.realm_mastery("algebra"), 0.0)
        for _ in range(10):
            self.tracer.observe(make_attempt(concept="variables.meaning", correct=True))
        partial = self.tracer.realm_mastery("algebra")
        self.assertGreater(partial, 0.0)
        self.assertLess(partial, 10.0, "one concept out of many must not dominate the realm")

    def test_suggested_next_prefers_learning_new_concepts(self):
        for _ in range(10):
            self.tracer.observe(
                make_attempt(concept="variables.meaning", correct=True, timestamp=NOW),
                now=NOW,
            )
        fresh = self.tracer.suggested_next("algebra")
        self.assertIn("variables.constants", fresh)

    def test_suggested_next_surfaces_rusty_concepts_for_recap(self):
        past = NOW - 120 * DAY
        for _ in range(10):
            self.tracer.observe(
                make_attempt(concept="variables.meaning", correct=True, timestamp=past), now=past
            )
        self.assertIn("variables.meaning", self.tracer.suggested_next("algebra"))
        self.assertEqual(self.tracer.rusty_concepts(), ["variables.meaning"])

    def test_coverage_reports_unmet_concepts(self):
        coverage, unmet = self.tracer.coverage(["variables.meaning", "variables.constants"], gate=70.0)
        self.assertEqual(coverage, 0.0)
        self.assertEqual(len(unmet), 2)

    def test_serialisation_round_trip(self):
        for i in range(6):
            self.tracer.observe(make_attempt(correct=True, timestamp=NOW + i), now=NOW + i)
        restored = KnowledgeTracer.from_dict(self.tracer.to_dict(), self.graph)
        self.assertAlmostEqual(
            restored.p_known("linear.two_step", decayed=False),
            self.tracer.p_known("linear.two_step", decayed=False),
            places=9,
        )


if __name__ == "__main__":
    unittest.main()
