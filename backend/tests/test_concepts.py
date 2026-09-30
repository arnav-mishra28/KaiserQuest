import unittest

from engine.concepts import ConceptGraph, get_concept_graph


class ConceptGraphTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.graph = get_concept_graph()

    def test_graph_loads_all_realms(self):
        self.assertEqual({r.id for r in self.graph.realms}, {"algebra", "english", "music"})
        self.assertGreater(len(self.graph), 60)

    def test_every_concept_has_a_name_and_domain(self):
        for concept in self.graph:
            self.assertTrue(concept.name, concept.id)
            self.assertTrue(self.graph.domain(concept.domain).name, concept.id)

    def test_topological_order_respects_prerequisites(self):
        order = self.graph.topological_order("algebra")
        position = {concept_id: index for index, concept_id in enumerate(order)}
        for concept_id in order:
            for prereq in self.graph.prerequisites(concept_id):
                self.assertLess(
                    position[prereq], position[concept_id],
                    f"{prereq} must be taught before {concept_id}",
                )

    def test_prerequisite_closure_is_transitive(self):
        prereqs = self.graph.prerequisites("quadratics.zero_product", recursive=True)
        self.assertIn("quadratics.factor", prereqs)
        self.assertIn("expressions.distribute", prereqs)
        self.assertIn("variables.expressions", prereqs)
        self.assertNotIn("quadratics.zero_product", prereqs)

    def test_missing_prereqs_and_readiness(self):
        self.assertEqual(
            self.graph.missing_prereqs("variables.meaning", []),
            [],
        )
        self.assertIn(
            "variables.meaning",
            self.graph.missing_prereqs("variables.constants", []),
        )
        self.assertTrue(self.graph.is_ready("variables.meaning", []))
        self.assertFalse(self.graph.is_ready("variables.constants", []))

    def test_frontier_is_what_can_be_learned_next(self):
        frontier = self.graph.frontier([])
        for concept_id in frontier:
            self.assertEqual(self.graph.prerequisites(concept_id), [], concept_id)
        self.assertIn("variables.meaning", frontier)
        self.assertNotIn("variables.constants", frontier)

        frontier_after = self.graph.frontier(["variables.meaning"])
        self.assertIn("variables.constants", frontier_after)
        self.assertNotIn("variables.meaning", frontier_after)

    def test_dependents_are_reverse_of_prereqs(self):
        dependents = self.graph.dependents("variables.meaning")
        self.assertIn("variables.constants", dependents)
        self.assertIn("variables.expressions", dependents)

    def test_tag_text_matches_keywords(self):
        tagged = self.graph.tag_text("Apply the inverse operation to undo the addition", "linear_equations")
        self.assertTrue(tagged)
        self.assertEqual(tagged[0], "linear.one_step")

    def test_tag_text_ranks_the_most_specific_match_first(self):
        # 'both sides' is a multi-word keyword and must outrank generic ones.
        tagged = self.graph.tag_text("Solve with x on both sides of the equation", "linear_equations")
        self.assertEqual(tagged[0], "linear.both_sides")

    def test_tag_text_returns_empty_when_nothing_matches(self):
        self.assertEqual(self.graph.tag_text("zzzz nothing here", "variables"), [])

    def test_tag_text_is_scoped_to_topic(self):
        # 'note' appears in Music; asking about the topics of another domain must
        # not leak concepts across domains.
        tagged = self.graph.tag_text("what is the note value", "notes")
        for concept_id in tagged:
            self.assertEqual(self.graph.concept(concept_id).domain, "notes")

    def test_unknown_concept_raises(self):
        with self.assertRaises(KeyError):
            self.graph.concept("does.not.exist")

    def test_invalid_prereq_is_rejected_at_load(self):
        payload = {
            "realms": [
                {
                    "id": "r", "name": "R", "domains": [
                        {"id": "d", "name": "D", "concepts": [
                            {"id": "d.a", "name": "A", "prereqs": ["d.missing"]},
                        ]},
                    ],
                }
            ]
        }
        with self.assertRaises(ValueError):
            ConceptGraph.from_dict(payload)

    def test_cycle_is_rejected(self):
        payload = {
            "realms": [
                {
                    "id": "r", "name": "R", "domains": [
                        {"id": "d", "name": "D", "concepts": [
                            {"id": "d.a", "name": "A", "prereqs": ["d.b"]},
                            {"id": "d.b", "name": "B", "prereqs": ["d.a"]},
                        ]},
                    ],
                }
            ]
        }
        with self.assertRaises(ValueError):
            ConceptGraph.from_dict(payload)

    def test_summary_counts(self):
        summary = self.graph.summary()
        self.assertIn("algebra", summary)
        self.assertGreater(summary["algebra"]["concepts"], 0)


if __name__ == "__main__":
    unittest.main()
