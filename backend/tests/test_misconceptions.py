import time
import unittest

from engine.attempts import Attempt, AttemptLog
from engine.concepts import get_concept_graph
from engine.content.generator import ContentGenerator
from engine.misconceptions import (
    GUESSING,
    RUSHING,
    MisconceptionDetector,
    get_misconception_catalog,
)

NOW = time.time()


def attempt(concept="linear.two_step", correct=False, chosen=None, response_ms=8000, expected_ms=8000, question_id="q"):
    return Attempt(
        player_id="tester",
        concept=concept,
        question_id=question_id,
        correct=correct,
        chosen=chosen,
        response_time_ms=response_ms,
        expected_time_ms=expected_ms,
        timestamp=NOW,
    )


class CatalogTests(unittest.TestCase):
    def test_catalog_loads_and_is_well_formed(self):
        catalog = get_misconception_catalog()
        self.assertGreater(len(catalog), 15)
        graph = get_concept_graph()
        for misconception in catalog:
            self.assertTrue(misconception.remedy, misconception.id)
            self.assertTrue(misconception.pattern, misconception.id)
            if not misconception.is_general:
                self.assertTrue(
                    graph.has_concept(misconception.concept),
                    f"{misconception.id} points at unknown concept {misconception.concept}",
                )
            for drill in misconception.drills:
                self.assertTrue(graph.has_concept(drill), f"{misconception.id}: unknown drill {drill}")

    def test_general_patterns_are_marked_general(self):
        catalog = get_misconception_catalog()
        self.assertTrue(catalog.require(RUSHING).is_general)
        self.assertTrue(catalog.require(GUESSING).is_general)
        self.assertFalse(catalog.require("alg.coefficient_not_divided").is_general)


class ExactDetectionTests(unittest.TestCase):
    """The generator knows which broken rule each distractor encodes."""

    def test_tagged_distractor_is_detected_with_certainty(self):
        generated = ContentGenerator().generate("linear.two_step", 25)
        tagged = [q for q in generated if q["misconceptions"]]
        self.assertTrue(tagged, "generator should tag at least some distractors")

        question = None
        for candidate in tagged:
            chosen = next(iter(candidate["misconceptions"]))
            if chosen in candidate["options"]:
                question = candidate
                break
        self.assertIsNotNone(question)

        distractor = next(iter(question["misconceptions"]))
        expected = question["misconceptions"][distractor]

        detector = MisconceptionDetector()
        log = AttemptLog()
        record = attempt(
            concept=question["concept"],
            correct=False,
            chosen=distractor,
            question_id=question["id"],
        )
        log.add(record)
        detections = detector.detect(record, log, question)

        self.assertTrue(detections)
        exact = [d for d in detections if d.is_certain]
        self.assertTrue(exact, "a tagged distractor is an exact detection")
        self.assertEqual(exact[0].misconception_id, expected)

    def test_correct_answer_never_produces_a_detection(self):
        detector = MisconceptionDetector()
        log = AttemptLog()
        record = attempt(correct=True, chosen="5")
        log.add(record)
        self.assertEqual(
            [d for d in detector.detect(record, log, {"misconceptions": {"5": "alg.coefficient_not_divided"}})],
            [],
        )

    def test_unknown_distractor_tag_is_ignored(self):
        detector = MisconceptionDetector()
        log = AttemptLog()
        record = attempt(chosen="99")
        log.add(record)
        detections = detector.detect(record, log, {"misconceptions": {"99": "not.a.real.tag"}})
        self.assertEqual(detections, [])


class BehaviouralDetectionTests(unittest.TestCase):
    def setUp(self):
        self.detector = MisconceptionDetector()

    def test_rushing_is_detected_from_repeated_fast_errors(self):
        log = AttemptLog()
        for index in range(4):
            record = attempt(
                chosen="x",
                response_ms=400,
                expected_ms=8000,
                question_id=f"q{index}",
            )
            log.add(record)
        detections = self.detector.detect(log.all[-1], log)
        self.assertIn(RUSHING, [d.misconception_id for d in detections])

    def test_a_single_fast_error_is_not_a_pattern(self):
        log = AttemptLog()
        record = attempt(chosen="x", response_ms=400, expected_ms=8000)
        log.add(record)
        detections = self.detector.detect(record, log)
        self.assertNotIn(RUSHING, [d.misconception_id for d in detections])

    def test_guessing_is_detected_from_chance_accuracy_at_speed(self):
        log = AttemptLog()
        for index in range(12):
            # 25% accuracy is chance for four options, answered instantly.
            correct = index % 4 == 0
            record = attempt(
                correct=correct,
                chosen="x",
                response_ms=500,
                expected_ms=9000,
                question_id=f"q{index}",
            )
            log.add(record)
            if not correct:
                log.all[-1].chosen = f"w{index}"
        detections = self.detector.detect(log.all[-1], log)
        self.assertIn(GUESSING, [d.misconception_id for d in detections])

    def test_slow_accuracy_does_not_look_like_guessing(self):
        log = AttemptLog()
        for index in range(12):
            record = attempt(
                correct=index % 4 == 0,
                chosen=f"w{index}",
                response_ms=9000,
                expected_ms=9000,
                question_id=f"q{index}",
            )
            log.add(record)
        detections = self.detector.detect(log.all[-1], log)
        self.assertNotIn(GUESSING, [d.misconception_id for d in detections])

    def test_repeated_distractor_is_flagged_for_naming(self):
        log = AttemptLog()
        for index in range(3):
            record = attempt(chosen="18", response_ms=9000, expected_ms=9000, question_id=f"q{index}")
            log.add(record)
        detections = self.detector.detect(log.all[-1], log)
        unlabelled = [d for d in detections if not d.misconception_id]
        self.assertTrue(unlabelled)
        self.assertIn("18", unlabelled[0].evidence)


class SummariseAndRemedyTests(unittest.TestCase):
    def test_summarize_ranks_by_severity(self):
        detector = MisconceptionDetector()
        log = AttemptLog()
        log.add(attempt(chosen="18", question_id="a"))
        log.add(attempt(chosen="18", question_id="b"))
        log.all[-1].misconception_id = "alg.coefficient_not_divided"
        log.add(attempt(concept="variables.meaning", chosen="z", question_id="c"))
        log.all[-1].misconception_id = "gen.rushing_unread_question"

        summary = detector.summarize(log)
        self.assertTrue(summary)
        severities = [detector._severity(d.misconception_id) for d in summary]
        self.assertEqual(severities, sorted(severities, reverse=True))

    def test_remedy_plan_deduplicates_drills(self):
        detector = MisconceptionDetector()
        log = AttemptLog()
        for index in range(2):
            record = attempt(chosen="18", question_id=f"a{index}")
            record.misconception_id = "alg.coefficient_not_divided"
            log.add(record)
        for index in range(2):
            record = attempt(concept="linear.one_step", chosen="4", question_id=f"b{index}")
            record.misconception_id = "alg.inverse_operation_wrong"
            log.add(record)

        plan = detector.remedy_plan(detector.summarize(log))
        self.assertTrue(plan)
        for item in plan:
            self.assertTrue(item["remedy"])
        drills = [drill for item in plan for drill in item["drills"]]
        self.assertEqual(len(drills), len(set(drills)), "the same drill must not be queued twice")


if __name__ == "__main__":
    unittest.main()
