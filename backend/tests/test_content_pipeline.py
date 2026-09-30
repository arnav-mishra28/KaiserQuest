import json
import tempfile
import unittest
from pathlib import Path

from engine.concepts import get_concept_graph
from engine.content.difficulty import DifficultyEstimator, extract_features
from engine.content.generator import ContentGenerator, make_options
from engine.content.pipeline import ConceptAssigner, ContentPipeline
from engine.content.validator import QuestionValidator


class StructuralValidationTests(unittest.TestCase):
    def setUp(self):
        self.validator = QuestionValidator()

    def base(self, **overrides):
        question = {
            "id": "t1",
            "subject": "math",
            "topic": "variables",
            "concept": "variables.constants",
            "question": "In 7x + 4, what is the coefficient of x?",
            "options": ["7", "4", "11", "x"],
            "correct_answer": "7",
            "explanation": "The coefficient multiplies x.",
            "difficulty": 1,
        }
        question.update(overrides)
        return question

    def test_valid_question_passes(self):
        report = self.validator.validate(self.base())
        self.assertTrue(report.ok, report.summary())

    def test_missing_required_field_fails(self):
        question = self.base()
        del question["correct_answer"]
        report = self.validator.validate(question)
        self.assertFalse(report.ok)
        self.assertTrue(any("correct_answer" in e for e in report.errors))

    def test_correct_answer_must_be_an_option(self):
        report = self.validator.validate(self.base(correct_answer="42"))
        self.assertFalse(report.ok)
        self.assertTrue(any("not among the options" in e for e in report.errors))

    def test_duplicate_options_fail(self):
        report = self.validator.validate(self.base(options=["7", "7", "4", "11"]))
        self.assertFalse(report.ok)
        self.assertTrue(any("Duplicate" in e for e in report.errors))

    def test_difficulty_outside_scale_fails(self):
        report = self.validator.validate(self.base(difficulty=9))
        self.assertFalse(report.ok)

    def test_unknown_concept_fails(self):
        report = self.validator.validate(self.base(concept="nonsense.thing"))
        self.assertFalse(report.ok)

    def test_missing_concept_fails(self):
        question = self.base()
        del question["concept"]
        report = self.validator.validate(question)
        self.assertFalse(report.ok)

    def test_misconception_keyed_to_the_correct_answer_fails(self):
        report = self.validator.validate(
            self.base(misconceptions={"7": "alg.like_terms_over_combined"})
        )
        self.assertFalse(report.ok)
        self.assertTrue(any("correct" in e for e in report.errors))

    def test_misconception_keyed_to_a_non_option_fails(self):
        report = self.validator.validate(
            self.base(misconceptions={"999": "alg.like_terms_over_combined"})
        )
        self.assertFalse(report.ok)

    def test_unknown_misconception_id_fails(self):
        report = self.validator.validate(self.base(misconceptions={"4": "made.up.tag"}))
        self.assertFalse(report.ok)

    def test_concept_topic_mismatch_is_only_a_warning(self):
        report = self.validator.validate(self.base(topic="music"))
        self.assertTrue(report.ok)
        self.assertTrue(report.warnings)

    def test_missing_explanation_warns_but_passes(self):
        question = self.base()
        del question["explanation"]
        report = self.validator.validate(question)
        self.assertTrue(report.ok)
        self.assertTrue(any("explanation" in w.lower() for w in report.warnings))


class VerificationMutationTests(unittest.TestCase):
    """
    The important property of the pipeline is not that good questions pass, it is
    that bad ones fail. These tests corrupt correct answers and assert the
    independent verifier notices.
    """

    def setUp(self):
        self.graph = get_concept_graph()
        self.generator = ContentGenerator(self.graph)
        self.validator = QuestionValidator(self.graph)

    def _question(self, concept, predicate=None, count=30):
        for question in self.generator.generate(concept, count, seed=7):
            if question.get("verify") and (predicate is None or predicate(question)):
                return question
        self.fail(f"no verifiable question generated for {concept}")

    def test_corrupted_linear_answer_is_caught(self):
        question = self._question("linear.two_step")
        self.assertTrue(self.validator.validate(question).ok)

        wrong = next(option for option in question["options"] if option != question["correct_answer"])
        question = dict(question, correct_answer=wrong)
        report = self.validator.validate(question)
        self.assertFalse(report.ok, "a corrupted answer must not pass verification")
        self.assertTrue(any("verification" in error.lower() for error in report.errors))

    def test_corrupted_simplification_is_caught(self):
        question = self._question(
            "expressions.distribute", predicate=lambda q: q["verify"]["kind"] == "equivalent"
        )
        wrong = next(option for option in question["options"] if option != question["correct_answer"])
        report = self.validator.validate(dict(question, correct_answer=wrong))
        self.assertFalse(report.ok)

    def test_corrupted_factorisation_is_caught(self):
        question = self._question("quadratics.factor")
        wrong = next(option for option in question["options"] if option != question["correct_answer"])
        report = self.validator.validate(dict(question, correct_answer=wrong))
        self.assertFalse(report.ok)

    def test_corrupted_roots_answer_is_caught(self):
        question = self._question("quadratics.zero_product")
        wrong = next(option for option in question["options"] if option != question["correct_answer"])
        report = self.validator.validate(dict(question, correct_answer=wrong))
        self.assertFalse(report.ok)

    def test_a_lying_verify_block_is_caught(self):
        """If the generator claims a root that is not one, verification must fail."""
        question = {
            "id": "liar",
            "subject": "math",
            "topic": "linear_equations",
            "concept": "linear.two_step",
            "question": "Solve for x: 2x + 5 = 15",
            "options": ["5", "10", "20", "3"],
            "correct_answer": "10",
            "explanation": "Because.",
            "difficulty": 3,
            "verify": {"kind": "linear_solution", "equation": "2*x + 5 = 15"},
        }
        report = self.validator.validate(question)
        self.assertFalse(report.ok)
        self.assertTrue(any("verification" in error.lower() for error in report.errors))

    def test_truthful_verify_block_passes(self):
        question = {
            "id": "honest",
            "subject": "math",
            "topic": "linear_equations",
            "concept": "linear.two_step",
            "question": "Solve for x: 2x + 5 = 15",
            "options": ["5", "10", "20", "3"],
            "correct_answer": "5",
            "explanation": "Subtract 5, then divide by 2.",
            "difficulty": 3,
            "verify": {"kind": "linear_solution", "equation": "2*x + 5 = 15"},
        }
        self.assertTrue(self.validator.validate(question).ok)

    def test_every_generated_question_across_every_concept_validates(self):
        failures = []
        for concept in self.generator.supported_concepts():
            for question in self.generator.generate(concept, 10, seed=11):
                report = self.validator.validate(question)
                if not report.ok:
                    failures.append(report.summary())
        self.assertEqual(failures, [], "\n".join(failures[:5]))

    def test_every_generated_question_has_enough_options(self):
        for concept in self.generator.supported_concepts():
            for question in self.generator.generate(concept, 5, seed=3):
                self.assertGreaterEqual(len(question["options"]), 3, concept)
                self.assertIn(question["correct_answer"], question["options"], concept)

    def test_misconception_tags_only_point_at_surviving_distractors(self):
        for concept in self.generator.supported_concepts():
            for question in self.generator.generate(concept, 8, seed=5):
                for distractor, tag in (question.get("misconceptions") or {}).items():
                    self.assertIn(distractor, question["options"], question["id"])
                    self.assertNotEqual(distractor, question["correct_answer"], question["id"])


class OptionBuilderTests(unittest.TestCase):
    def test_options_are_unique_and_shuffled(self):
        import random

        options = make_options("7x + 2", ["9x", "7x - 2", "14x + 2", "9x"], random.Random(1))
        self.assertEqual(len(options), len(set(options)))
        self.assertIn("7x + 2", options)

    def test_numeric_answers_do_not_duplicate_as_strings(self):
        import random

        options = make_options("8", ["8.0", "9", "10"], random.Random(1))
        self.assertEqual(len(options), len(set(options)))

    def test_root_answers_written_in_another_order_are_still_duplicates(self):
        import random

        options = make_options("x = 3 or x = -5", ["x = -5 or x = 3", "x = 5", "x = 0"], random.Random(1))
        self.assertNotIn("x = -5 or x = 3", options)


class DifficultyEstimatorTests(unittest.TestCase):
    def setUp(self):
        self.estimator = DifficultyEstimator()
        self.pipeline = ContentPipeline()

    def test_rule_based_estimate_within_scale(self):
        for text in ("What is 2 + 2?", "Solve for x: 3x + 4 = 19", "Explain why " + "x " * 60):
            estimate = self.estimator.estimate(text, ["a", "b", "c", "d"])
            self.assertGreaterEqual(estimate, 1)
            self.assertLessEqual(estimate, 5)

    def test_features_are_extracted(self):
        features = extract_features("Solve 3x + 4 = 19", ["1", "2", "3", "4"], 3)
        self.assertEqual(len(features), 10)

    def test_estimator_fits_on_the_curated_bank(self):
        curated = self.pipeline.read_curated()
        self.assertGreater(len(curated), 100)
        enriched = []
        assigner = ConceptAssigner(self.pipeline.graph)
        for question in curated:
            question = dict(question)
            question["concept"] = assigner.assign(question)
            enriched.append(question)
        report = self.pipeline.fit_estimator(enriched)
        self.assertEqual(report["samples"], len(curated))
        self.assertIn(report["backend"], {"Ridge", "rule"})
        if report["backend"] == "Ridge":
            self.assertLess(report["mae"], 1.5)
            self.assertTrue(report["coefficients"])

    def test_label_disagreements_are_surfaced_for_review(self):
        curated = self.pipeline.read_curated()
        assigner = ConceptAssigner(self.pipeline.graph)
        enriched = []
        for question in curated:
            question = dict(question)
            question["concept"] = assigner.assign(question)
            enriched.append(question)
        self.pipeline.fit_estimator(enriched)
        disagreements = self.pipeline.label_disagreements()
        self.assertIsInstance(disagreements, list)
        for item in disagreements:
            self.assertGreaterEqual(abs(item["delta"]), 2)


class PipelineRunTests(unittest.TestCase):
    def test_pipeline_writes_banks_and_quarantines_bad_content(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "questions" / "math"
            source.mkdir(parents=True)
            banks = root / "banks"

            good = {
                "id": "ok1",
                "question": "Solve for x: x + 3 = 7",
                "options": ["4", "10", "3", "7"],
                "correct_answer": "4",
                "explanation": "Subtract 3 from both sides.",
                "difficulty": 2,
            }
            broken = {
                "id": "broken1",
                "question": "Solve for x: x + 3 = 7",
                "options": ["4", "10", "3", "7"],
                "correct_answer": "999",
                "explanation": "Nope.",
                "difficulty": 2,
            }
            (source / "variables.json").write_text(
                json.dumps({"subject": "math", "topic": "variables", "questions": [good, broken]}),
                encoding="utf-8",
            )

            pipeline = ContentPipeline(
                graph=get_concept_graph(), source_dir=root / "questions", bank_dir=banks
            )
            report = pipeline.run(per_concept=3, write=True, seed=1)

            self.assertEqual(report.curated_in, 2)
            self.assertEqual(report.curated_accepted, 1)
            self.assertEqual(report.quarantined, 1)
            self.assertTrue(report.topics_written)

            manifest = json.loads((banks / "_manifest.json").read_text(encoding="utf-8"))
            self.assertEqual(manifest["quarantined"], 1)
            self.assertIn("estimator", manifest)

            quarantine = json.loads((banks / "_quarantine.json").read_text(encoding="utf-8"))
            self.assertEqual(quarantine["count"], 1)
            self.assertEqual(quarantine["questions"][0]["id"], "broken1")
            self.assertTrue(quarantine["questions"][0]["errors"])

            # Every question that made it into a bank must validate.
            validator = QuestionValidator(get_concept_graph())
            checked = 0
            for path in banks.rglob("*.json"):
                if path.name.startswith("_"):
                    continue
                payload = json.loads(path.read_text(encoding="utf-8"))
                for question in payload["questions"]:
                    checked += 1
                    self.assertTrue(validator.validate(question).ok, question.get("id"))
            self.assertGreater(checked, 3)

    def test_curated_questions_are_enriched_not_altered(self):
        pipeline = ContentPipeline()
        curated = pipeline.read_curated()
        sample = curated[0]
        assigner = ConceptAssigner(pipeline.graph)
        enriched, _ = pipeline.enrich_curated([sample], assigner)
        result = enriched[0]
        for field in ("id", "question", "options", "correct_answer", "explanation"):
            self.assertEqual(result[field], sample[field], field)
        self.assertTrue(result["concept"])
        self.assertGreater(result["expected_time_ms"], 0)


if __name__ == "__main__":
    unittest.main()
