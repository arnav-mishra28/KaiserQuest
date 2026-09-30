import time
import unittest

from engine.attempts import Attempt, AttemptLog
from engine.campaign import all_campaigns
from engine.concepts import get_concept_graph
from engine.profile import KnowledgeProfile
from engine.progression import RealmProgress
from engine.silver_mountain import (
    ATTEMPTS_PER_WINDOW,
    COOLDOWN_HOURS,
    EXAM_PASS_RATIO,
    EXAM_QUESTIONS,
    REALM_CLEAR_MASTERY,
    SilverMountain,
    SilverMountainState,
)
from engine.tracing import KnowledgeTracer

NOW = time.time()
HOUR = 3600.0


def build_profile(graph, log=None, strong=(), weak=(), mid=()):
    tracer = KnowledgeTracer("tester", graph)
    for concept in strong:
        for _ in range(8):
            tracer.observe(_attempt(concept, True, graph), now=NOW)
    for concept in mid:
        for index in range(5):
            tracer.observe(_attempt(concept, index % 3 != 0, graph), now=NOW)
    for concept in weak:
        for _ in range(4):
            tracer.observe(_attempt(concept, False, graph), now=NOW)
    return KnowledgeProfile("tester", "algebra", tracer, log or AttemptLog())


def _attempt(concept, correct, graph):
    level = graph.concept(concept).level if graph.has_concept(concept) else 3
    return Attempt(
        player_id="tester",
        concept=concept,
        question_id=f"q-{concept}-{correct}",
        correct=correct,
        difficulty=level,
        response_time_ms=9000,
        expected_time_ms=9000,
        timestamp=NOW,
    )


class AdmissionTests(unittest.TestCase):
    def setUp(self):
        self.graph = get_concept_graph()
        self.campaign = all_campaigns(self.graph)["algebra"]
        self.mountain = SilverMountain(self.graph)
        self.progress = RealmProgress(realm="algebra")

    def test_mountain_is_closed_until_the_realm_is_finished(self):
        admission = self.mountain.admission(self.campaign, self.progress)
        self.assertFalse(admission["allowed"])
        self.assertTrue(admission["milestones_remaining"])
        self.assertEqual(admission["milestones_passed"], 0)

    def test_mountain_opens_when_every_milestone_is_cleared(self):
        for milestone in self.campaign.milestones:
            self.progress.mark_passed(milestone.index, milestone.badge_name)
        admission = self.mountain.admission(self.campaign, self.progress)
        self.assertTrue(admission["allowed"])
        self.assertEqual(admission["milestones_total"], 20)

    def test_levels_are_not_the_gate(self):
        """Regression guard: the old build gated on level >= 100 and 20 badges."""
        for index in range(1, 20):
            self.progress.mark_passed(index, "sigil")
        self.assertFalse(self.mountain.admission(self.campaign, self.progress)["allowed"])
        self.assertEqual(1, len(self.mountain.admission(self.campaign, self.progress)["milestones_remaining"]))


class ExamAssemblyTests(unittest.TestCase):
    def setUp(self):
        self.graph = get_concept_graph()
        self.mountain = SilverMountain(self.graph)
        concepts = [c.id for c in self.graph.realm("algebra").concepts]
        self.profile = build_profile(
            self.graph,
            strong=concepts[:6],
            mid=concepts[6:12],
            weak=concepts[12:20],
        )

    def test_exam_is_the_configured_length(self):
        slots = self.mountain.assemble_exam(self.profile, "algebra")
        self.assertEqual(len(slots), EXAM_QUESTIONS)

    def test_exam_is_weighted_towards_weak_concepts(self):
        slots = self.mountain.assemble_exam(self.profile, "algebra")
        bands = [slot.band for slot in slots]
        weak_count = bands.count("weak")
        strong_count = bands.count("strong")
        self.assertGreater(weak_count, strong_count)
        self.assertGreaterEqual(weak_count, int(EXAM_QUESTIONS * 0.5))

    def test_exam_does_not_skip_what_the_player_is_best_at(self):
        slots = self.mountain.assemble_exam(self.profile, "algebra")
        self.assertIn("strong", [slot.band for slot in slots])

    def test_weak_slots_really_are_the_weakest_concepts(self):
        slots = self.mountain.assemble_exam(self.profile, "algebra")
        weak = [slot for slot in slots if slot.band == "weak"]
        strong = [slot for slot in slots if slot.band == "strong"]
        self.assertTrue(weak and strong)
        self.assertLessEqual(
            max(slot.mastery for slot in weak),
            max(slot.mastery for slot in strong) + 1e-6,
        )

    def test_every_slot_carries_a_reason(self):
        for slot in self.mountain.assemble_exam(self.profile, "algebra"):
            self.assertTrue(slot.reason)
            self.assertTrue(slot.concept_name)
            self.assertGreaterEqual(slot.difficulty, 1)
            self.assertLessEqual(slot.difficulty, 5)

    def test_never_attempted_concepts_are_treated_as_weak(self):
        slots = self.mountain.assemble_exam(self.profile, "algebra")
        untouched = [slot for slot in slots if slot.mastery == 0.0]
        self.assertTrue(untouched, "an empty gap must be examinable")
        self.assertEqual({slot.band for slot in untouched}, {"weak"})


class AttemptWindowTests(unittest.TestCase):
    def setUp(self):
        self.graph = get_concept_graph()
        self.mountain = SilverMountain(self.graph)
        concepts = [c.id for c in self.graph.realm("algebra").concepts]
        self.profile = build_profile(self.graph, strong=concepts[:4], weak=concepts[10:16])
        self.state = SilverMountainState(realm="algebra")

    def test_three_failures_close_the_mountain_for_a_day(self):
        for attempt in range(ATTEMPTS_PER_WINDOW):
            result = self.mountain.record_attempt(self.state, False, 0.4, self.profile, now=NOW)
        self.assertFalse(result["passed"])
        self.assertEqual(result["attempts_remaining"], 0)
        self.assertTrue(result["return_to_save"])
        self.assertAlmostEqual(result["cooldown_until"], NOW + COOLDOWN_HOURS * HOUR, delta=1)

    def test_failure_returns_a_personalised_recap(self):
        result = None
        for _ in range(ATTEMPTS_PER_WINDOW):
            result = self.mountain.record_attempt(self.state, False, 0.35, self.profile, now=NOW)
        self.assertTrue(result["recap"])
        for step in result["recap"]:
            self.assertTrue(step["title"])
            self.assertTrue(step["body"])
            self.assertGreaterEqual(step["order"], 1)

    def test_recap_names_the_weak_concepts(self):
        recap = self.mountain.build_recap(self.profile)
        text = " ".join(f"{step.title} {step.body}" for step in recap)
        weak = self.profile.weak_concepts(threshold=65.0, limit=3)
        self.assertTrue(weak)
        self.assertTrue(
            any(view.name in text for view in weak),
            "the recap should name what the player actually failed on",
        )

    def test_recap_orders_misconceptions_first(self):
        log = AttemptLog()
        for index in range(3):
            record = _attempt("linear.two_step", False, self.graph)
            record.question_id = f"m{index}"
            record.chosen = "10"
            record.misconception_id = "alg.coefficient_not_divided"
            log.add(record)
        profile = KnowledgeProfile("tester", "algebra", self.profile.tracer, log, self.graph)
        recap = self.mountain.build_recap(profile)
        self.assertTrue(recap)
        self.assertEqual(recap[0].kind, "remedy")

    def test_cooldown_blocks_the_challenge_then_expires(self):
        campaign = all_campaigns(self.graph)["algebra"]
        progress = RealmProgress(realm="algebra")
        for milestone in campaign.milestones:
            progress.mark_passed(milestone.index, milestone.badge_name)

        for _ in range(ATTEMPTS_PER_WINDOW):
            self.mountain.record_attempt(self.state, False, 0.2, self.profile, now=NOW)

        blocked = self.mountain.status(campaign, progress, self.state, now=NOW + HOUR)
        self.assertFalse(blocked["can_challenge"])
        self.assertGreater(blocked["cooldown_remaining_seconds"], 0)

        # A day later the mountain reopens and the attempts are restored.
        reopened = self.mountain.status(campaign, progress, self.state, now=NOW + 25 * HOUR)
        self.assertTrue(reopened["can_challenge"])
        self.assertEqual(reopened["attempts_remaining"], ATTEMPTS_PER_WINDOW)
        self.assertTrue(reopened["cooldown_just_expired"])

    def test_first_failure_does_not_start_a_cooldown(self):
        result = self.mountain.record_attempt(self.state, False, 0.5, self.profile, now=NOW)
        self.assertEqual(result["attempts_remaining"], ATTEMPTS_PER_WINDOW - 1)
        self.assertEqual(result["cooldown_until"], 0.0)
        self.assertFalse(result["return_to_save"])

    def test_passing_clears_the_story(self):
        result = self.mountain.record_attempt(self.state, True, 0.9, self.profile, now=NOW)
        self.assertTrue(result["passed"])
        self.assertTrue(result["cleared"])
        self.assertTrue(self.state.cleared)
        self.assertEqual(result["cooldown_until"], 0.0)

    def test_status_reports_the_exam_requirements(self):
        campaign = all_campaigns(self.graph)["algebra"]
        progress = RealmProgress(realm="algebra")
        status = self.mountain.status(campaign, progress, self.state, now=NOW)
        self.assertEqual(status["exam"]["questions"], EXAM_QUESTIONS)
        self.assertAlmostEqual(status["exam"]["pass_ratio"], EXAM_PASS_RATIO)
        self.assertEqual(status["exam"]["required_correct"], 20)


class ArchivistVoiceTests(unittest.TestCase):
    def setUp(self):
        self.graph = get_concept_graph()
        self.mountain = SilverMountain(self.graph)
        concepts = [c.id for c in self.graph.realm("algebra").concepts]
        self.profile = build_profile(self.graph, strong=concepts[:3], weak=concepts[9:14])

    def test_victory_lines_quote_the_opening_line(self):
        lines = self.mountain._victory_lines(self.profile, 0.92)
        self.assertIn(
            "You have collected knowledge. But knowledge collected is not knowledge mastered.",
            lines[0],
        )

    def test_defeat_lines_name_the_players_weakness(self):
        lines = self.mountain._defeat_lines(self.profile, 0.5, final=True)
        joined = " ".join(lines)
        weak = self.profile.weak_concepts(threshold=65.0, limit=1)
        self.assertTrue(weak)
        self.assertIn(weak[0].name, joined)
        self.assertIn("Twenty-four" if False else "day", joined.lower())

    def test_final_defeat_promises_the_cool_down(self):
        lines = self.mountain._defeat_lines(self.profile, 0.5, final=True)
        self.assertIn("Three attempts", " ".join(lines))


if __name__ == "__main__":
    unittest.main()
