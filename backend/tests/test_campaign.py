import unittest

from engine.campaign import (
    ARC,
    REALM_FLAVOR,
    TRIAL_MODES,
    Campaign,
    all_campaigns,
    apportion,
    get_campaign,
    split_evenly,
)
from engine.concepts import get_concept_graph


class ApportionTests(unittest.TestCase):
    def test_apportion_sums_to_total(self):
        for counts in ([5, 4, 5, 5, 5, 5, 4, 4], [5] * 6, [3, 3, 3], [1, 40]):
            allocation = apportion(counts, 20)
            self.assertEqual(sum(allocation), 20, counts)
            self.assertTrue(all(a >= 1 for a in allocation), counts)

    def test_apportion_is_proportional(self):
        allocation = apportion([10, 1, 1], 20, minimum=1)
        self.assertGreater(allocation[0], allocation[1])
        self.assertGreater(allocation[0], allocation[2])

    def test_apportion_rejects_impossible_requests(self):
        with self.assertRaises(ValueError):
            apportion([1, 1, 1], 2, minimum=1)

    def test_split_evenly_is_contiguous_and_complete(self):
        items = list(range(7))
        chunks = split_evenly(items, 3)
        self.assertEqual([len(c) for c in chunks], [3, 2, 2])
        self.assertEqual([item for chunk in chunks for item in chunk], items)

    def test_split_evenly_more_groups_than_items(self):
        self.assertEqual(split_evenly([1, 2], 5), [[1], [2]])


class ArcTests(unittest.TestCase):
    def test_arc_is_twenty_milestones(self):
        self.assertEqual(len(ARC), 20)
        self.assertEqual([a.index for a in ARC], list(range(1, 21)))

    def test_every_arc_mode_exists(self):
        for archetype in ARC:
            self.assertIn(archetype.mode, TRIAL_MODES, archetype.title)

    def test_the_arc_uses_many_distinct_mechanics(self):
        modes = {archetype.mode for archetype in ARC}
        self.assertGreaterEqual(len(modes), 10, "twenty identical trials would be the failure mode")

    def test_mastery_gate_rises_across_the_arc(self):
        self.assertLess(ARC[0].mastery_gate, ARC[19].mastery_gate)
        self.assertLess(ARC[0].mastery_gate, ARC[13].mastery_gate)

    def test_trial_modes_are_coherent(self):
        for mode in TRIAL_MODES.values():
            self.assertGreaterEqual(mode.questions, 2, mode.id)
            self.assertTrue(0 < mode.pass_ratio <= 1.0, mode.id)
            self.assertLessEqual(mode.required_correct, mode.questions, mode.id)
            self.assertTrue(mode.mechanic, mode.id)
            self.assertTrue(mode.description, mode.id)

    def test_guided_mode_cannot_really_fail_the_player(self):
        self.assertEqual(TRIAL_MODES["guided"].stakes, "none")
        self.assertGreater(TRIAL_MODES["guided"].hints_allowed, 0)


class CampaignTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.graph = get_concept_graph()
        cls.campaigns = all_campaigns(cls.graph)

    def test_every_realm_has_a_flavoured_campaign(self):
        self.assertEqual(set(self.campaigns), {r.id for r in self.graph.realms})
        for realm_id, campaign in self.campaigns.items():
            self.assertIn(realm_id, REALM_FLAVOR)
            self.assertEqual(len(campaign.milestones), 20)

    def test_every_concept_is_taught_and_tested_exactly_once(self):
        for realm_id, campaign in self.campaigns.items():
            taught = [c for milestone in campaign.milestones for c in milestone.concepts]
            expected = [c.id for c in self.graph.realm(realm_id).concepts]
            self.assertEqual(sorted(taught), sorted(expected), realm_id)
            self.assertEqual(len(taught), len(set(taught)), f"{realm_id} tests a concept twice")

    def test_no_milestone_is_empty(self):
        for campaign in self.campaigns.values():
            for milestone in campaign.milestones:
                self.assertTrue(milestone.concepts, milestone.id)

    def test_a_milestone_never_tests_a_concept_before_its_prerequisites(self):
        for realm_id, campaign in self.campaigns.items():
            taught_so_far = set()
            for milestone in campaign.milestones:
                for concept_id in milestone.concepts:
                    for prereq in self.graph.prerequisites(concept_id):
                        self.assertTrue(
                            prereq in taught_so_far or prereq in milestone.concepts,
                            f"{realm_id} {milestone.id} tests {concept_id} before {prereq}",
                        )
                taught_so_far.update(milestone.concepts)

    def test_milestones_have_places_keepers_and_narrative(self):
        for campaign in self.campaigns.values():
            for milestone in campaign.milestones:
                self.assertTrue(milestone.place)
                self.assertTrue(milestone.keeper)
                self.assertTrue(milestone.name)
                self.assertTrue(milestone.setup)
                self.assertTrue(milestone.success)
                self.assertTrue(milestone.failure)
                # Placeholders must all have been substituted.
                for text in (milestone.setup, milestone.success, milestone.failure):
                    self.assertNotIn("{", text, milestone.id)

    def test_each_realm_has_its_own_names(self):
        names = {realm_id: [m.name for m in c.milestones] for realm_id, c in self.campaigns.items()}
        self.assertNotEqual(names["algebra"], names["music"])
        self.assertNotEqual(names["english"], names["music"])
        for realm_names in names.values():
            self.assertEqual(len(set(realm_names)), 20)

    def test_concepts_through_accumulates(self):
        campaign = self.campaigns["algebra"]
        self.assertEqual(len(campaign.concepts_through(1)), len(campaign.milestone(1).concepts))
        self.assertEqual(len(campaign.concepts_through(20)), len(self.graph.realm("algebra").concepts))
        self.assertLess(
            len(campaign.concepts_through(5)), len(campaign.concepts_through(10))
        )

    def test_milestone_for_concept_is_unique(self):
        campaign = self.campaigns["english"]
        for concept in self.graph.realm("english").concepts:
            milestone = campaign.milestone_for_concept(concept.id)
            self.assertIsNotNone(milestone, concept.id)
            self.assertIn(concept.id, milestone.concepts)

    def test_first_unpassed_walks_forward(self):
        campaign = self.campaigns["music"]
        self.assertEqual(campaign.first_unpassed([]).index, 1)
        self.assertEqual(campaign.first_unpassed([1, 2, 3]).index, 4)
        self.assertEqual(campaign.first_unpassed(list(range(1, 21))).index, 20)

    def test_milestone_out_of_range_raises(self):
        campaign = self.campaigns["algebra"]
        with self.assertRaises(KeyError):
            campaign.milestone(0)
        with self.assertRaises(KeyError):
            campaign.milestone(21)

    def test_campaign_serialises(self):
        payload = self.campaigns["algebra"].to_dict()
        self.assertEqual(payload["milestone_count"], 20)
        self.assertEqual(len(payload["milestones"]), 20)
        first = payload["milestones"][0]
        self.assertIn("trial", first)
        self.assertIn("narrative", first)

    def test_summary_renders(self):
        text = self.campaigns["algebra"].summary()
        self.assertIn("Champion of Algebra", text)

    def test_get_campaign_is_cached(self):
        self.assertIs(get_campaign("algebra", self.graph), get_campaign("algebra", self.graph))

    def test_unknown_realm_raises(self):
        with self.assertRaises(KeyError):
            Campaign(self.graph, "astrophysics")


if __name__ == "__main__":
    unittest.main()
