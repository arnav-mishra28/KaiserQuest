"""
The concept graph.

A Realm is a subject (Algebra). A Domain is a chapter-sized area inside it
(Variables). A Concept is the atomic unit the Knowledge Engine tracks. This is
the single source of truth for:

  * what a player is ready to learn next   (prereq closure)
  * which milestone a concept belongs to   (campaign ordering)
  * which questions belong to a concept    (keyword tagging, used by the
                                            content pipeline for raw text)

Nothing here knows about players or questions; it is the map, not the journey.
"""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path
from typing import Dict, Iterable, Iterator, List, Optional, Sequence, Set, Tuple

logger = logging.getLogger("kaiserquest.engine.concepts")

DATA_PATH = Path(__file__).resolve().parent.parent / "data" / "knowledge" / "concepts.json"


@dataclass(frozen=True)
class Concept:
    """One atomic thing a learner can know or not know."""

    id: str
    name: str
    domain: str
    realm: str
    prereqs: Tuple[str, ...] = ()
    keywords: Tuple[str, ...] = ()
    level: int = 1

    @property
    def short_name(self) -> str:
        """Just the leaf, e.g. 'quadratics.factor' -> 'factor'."""
        return self.id.split(".", 1)[-1]

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "name": self.name,
            "domain": self.domain,
            "realm": self.realm,
            "prereqs": list(self.prereqs),
            "keywords": list(self.keywords),
            "level": self.level,
        }


@dataclass
class Domain:
    id: str
    name: str
    realm: str
    concepts: List[Concept] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "name": self.name,
            "realm": self.realm,
            "concepts": [c.to_dict() for c in self.concepts],
        }


@dataclass
class Realm:
    id: str
    name: str
    section: str
    sigil: str
    accent: str
    tagline: str
    domains: List[Domain] = field(default_factory=list)

    @property
    def concepts(self) -> List[Concept]:
        return [c for d in self.domains for c in d.concepts]

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "name": self.name,
            "section": self.section,
            "sigil": self.sigil,
            "accent": self.accent,
            "tagline": self.tagline,
            "domains": [d.to_dict() for d in self.domains],
            "concept_count": len(self.concepts),
        }


class ConceptGraph:
    """Loaded concept graph with traversal helpers."""

    def __init__(self, realms: Sequence[Realm]):
        self._realms: List[Realm] = list(realms)
        self._concepts: Dict[str, Concept] = {}
        self._domains: Dict[str, Domain] = {}
        self._realm_of: Dict[str, Realm] = {}

        for realm in self._realms:
            for domain in realm.domains:
                key = f"{realm.id}/{domain.id}"
                if key in self._domains:
                    raise ValueError(f"Duplicate domain id: {key}")
                self._domains[key] = domain
                for concept in domain.concepts:
                    if concept.id in self._concepts:
                        raise ValueError(f"Duplicate concept id: {concept.id}")
                    self._concepts[concept.id] = concept
                    realm_of = self._realm_of.setdefault(domain.id, realm)
                    if realm_of is not realm:
                        raise ValueError(f"Domain id reused across realms: {domain.id}")

        self._validate_prereqs()

    # ------------------------------------------------------------------
    # Construction
    # ------------------------------------------------------------------
    @classmethod
    def from_dict(cls, data: dict) -> "ConceptGraph":
        realms: List[Realm] = []
        for raw_realm in data.get("realms", []):
            realm = Realm(
                id=raw_realm["id"],
                name=raw_realm["name"],
                section=raw_realm.get("section", raw_realm["name"]),
                sigil=raw_realm.get("sigil", ""),
                accent=raw_realm.get("accent", "#ffffff"),
                tagline=raw_realm.get("tagline", ""),
            )
            for raw_domain in raw_realm.get("domains", []):
                domain = Domain(id=raw_domain["id"], name=raw_domain["name"], realm=realm.id)
                for raw_concept in raw_domain.get("concepts", []):
                    domain.concepts.append(
                        Concept(
                            id=raw_concept["id"],
                            name=raw_concept["name"],
                            domain=domain.id,
                            realm=realm.id,
                            prereqs=tuple(raw_concept.get("prereqs", [])),
                            keywords=tuple(raw_concept.get("keywords", [])),
                            level=int(raw_concept.get("level", 1)),
                        )
                    )
                realm.domains.append(domain)
            realms.append(realm)
        return cls(realms)

    @classmethod
    def from_file(cls, path: Optional[Path] = None) -> "ConceptGraph":
        path = path or DATA_PATH
        with open(path, "r", encoding="utf-8") as handle:
            return cls.from_dict(json.load(handle))

    def _validate_prereqs(self) -> None:
        for concept in self._concepts.values():
            for prereq in concept.prereqs:
                if prereq not in self._concepts:
                    raise ValueError(
                        f"Concept '{concept.id}' lists unknown prereq '{prereq}'"
                    )
                if prereq == concept.id:
                    raise ValueError(f"Concept '{concept.id}' is its own prereq")
        # Cycle detection over the whole graph.
        self.topological_order()

    # ------------------------------------------------------------------
    # Lookup
    # ------------------------------------------------------------------
    @property
    def realms(self) -> List[Realm]:
        return list(self._realms)

    def realm(self, realm_id: str) -> Realm:
        for realm in self._realms:
            if realm.id == realm_id:
                return realm
        raise KeyError(f"Unknown realm '{realm_id}'")

    def find_realm(self, label: str) -> Optional[Realm]:
        """Resolve a realm by id, name or section name, case-insensitively."""
        wanted = (label or "").strip().lower()
        for realm in self._realms:
            if wanted in {realm.id.lower(), realm.name.lower(), realm.section.lower()}:
                return realm
        return None

    def concept(self, concept_id: str) -> Concept:
        try:
            return self._concepts[concept_id]
        except KeyError:
            raise KeyError(f"Unknown concept '{concept_id}'") from None

    def has_concept(self, concept_id: str) -> bool:
        return concept_id in self._concepts

    def domain(self, domain_id: str) -> Domain:
        for domain in self._domains.values():
            if domain.id == domain_id:
                return domain
        raise KeyError(f"Unknown domain '{domain_id}'")

    def domain_of_concept(self, concept_id: str) -> Domain:
        return self.domain(self.concept(concept_id).domain)

    def concepts_of_domain(self, domain_id: str) -> List[Concept]:
        return list(self.domain(domain_id).concepts)

    def all_concepts(self) -> List[Concept]:
        return list(self._concepts.values())

    def concept_ids(self) -> List[str]:
        return list(self._concepts.keys())

    def __len__(self) -> int:
        return len(self._concepts)

    def __iter__(self) -> Iterator[Concept]:
        return iter(self._concepts.values())

    # ------------------------------------------------------------------
    # Traversal
    # ------------------------------------------------------------------
    def prerequisites(self, concept_id: str, recursive: bool = False) -> List[str]:
        """Direct prereqs, or the full transitive prereq closure."""
        direct = list(self.concept(concept_id).prereqs)
        if not recursive:
            return direct
        seen: Set[str] = set()
        stack = list(direct)
        while stack:
            node = stack.pop()
            if node in seen:
                continue
            seen.add(node)
            stack.extend(self.concept(node).prereqs)
        return sorted(seen)

    def dependents(self, concept_id: str) -> List[str]:
        """Concepts that list `concept_id` as a direct prereq."""
        return [c.id for c in self._concepts.values() if concept_id in c.prereqs]

    def topological_order(self, realm_id: Optional[str] = None) -> List[str]:
        """
        Concept ids ordered so that every concept follows its prereqs.

        Kahn's algorithm; ordered by (level, domain, position) for a stable,
        pedagogically sensible sequence rather than an arbitrary one.
        """
        nodes = [
            c.id
            for c in self._concepts.values()
            if realm_id is None or c.realm == realm_id
        ]
        node_set = set(nodes)
        indegree: Dict[str, int] = {n: 0 for n in nodes}
        for node in nodes:
            for prereq in self.concept(node).prereqs:
                if prereq in node_set:
                    indegree[node] += 1

        def sort_key(concept_id: str) -> Tuple[int, str, int]:
            concept = self.concept(concept_id)
            domain = self.domain(concept.domain)
            position = [c.id for c in domain.concepts].index(concept_id)
            return (concept.level, concept.domain, position)

        ready = sorted([n for n in nodes if indegree[n] == 0], key=sort_key)
        ordered: List[str] = []
        while ready:
            node = ready.pop(0)
            ordered.append(node)
            for dependent in self.dependents(node):
                if dependent not in indegree:
                    continue
                indegree[dependent] -= 1
                if indegree[dependent] == 0:
                    ready.append(dependent)
            ready.sort(key=sort_key)

        if len(ordered) != len(nodes):
            unresolved = sorted(node_set - set(ordered))
            raise ValueError(f"Prerequisite cycle detected among: {unresolved}")
        return ordered

    def missing_prereqs(self, concept_id: str, known: Iterable[str]) -> List[str]:
        """Prereqs of `concept_id` that the player has not mastered yet."""
        known_set = set(known)
        return [p for p in self.prerequisites(concept_id) if p not in known_set]

    def is_ready(self, concept_id: str, known: Iterable[str]) -> bool:
        return not self.missing_prereqs(concept_id, known)

    def frontier(self, known: Iterable[str]) -> List[str]:
        """
        The learning frontier: concepts whose prereqs are all mastered but which
        are not mastered themselves. This is literally "what you are ready to
        learn next" and is what the world should be offering the player.
        """
        known_set = set(known)
        return [
            c.id for c in self._concepts.values() if c.id not in known_set and self.is_ready(c.id, known_set)
        ]

    # ------------------------------------------------------------------
    # Tagging raw text onto concepts (used by the content pipeline)
    # ------------------------------------------------------------------
    def tag_text(self, text: str, topic: Optional[str] = None, top_k: int = 1) -> List[str]:
        """
        Best-effort tagging of a raw question onto concept ids.

        Strategy: keyword scoring, restricted to `topic`'s domain when given,
        with ties broken towards the lowest level (you learn the simple thing
        first). Returns concept ids, best first.
        """
        haystack = (text or "").lower()
        if not haystack:
            return []
        candidates = self._candidate_concepts(topic)
        scored: List[Tuple[float, Concept]] = []
        for concept in candidates:
            score = 0.0
            for keyword in concept.keywords:
                if keyword.lower() in haystack:
                    # Multi-word keywords are far more specific than single words.
                    score += 2.0 + 0.5 * keyword.count(" ")
            if score > 0:
                scored.append((score, concept))
        if not scored:
            return []
        scored.sort(key=lambda pair: (-pair[0], pair[1].level, pair[1].id))
        return [concept.id for _, concept in scored[:top_k]]

    def _candidate_concepts(self, topic: Optional[str]) -> List[Concept]:
        if not topic:
            return self.all_concepts()
        wanted = topic.strip().lower()
        for realm in self._realms:
            for domain in realm.domains:
                if domain.id.lower() == wanted:
                    return list(domain.concepts)
        return self.all_concepts()

    # ------------------------------------------------------------------
    # Serialisation
    # ------------------------------------------------------------------
    def to_dict(self) -> dict:
        return {"version": 1, "realms": [realm.to_dict() for realm in self._realms]}

    def summary(self) -> Dict[str, Dict[str, int]]:
        return {
            realm.id: {
                "domains": len(realm.domains),
                "concepts": len(realm.concepts),
            }
            for realm in self._realms
        }


@lru_cache(maxsize=1)
def get_concept_graph(path: str | None = None) -> ConceptGraph:
    """Process-wide cached concept graph."""
    graph = ConceptGraph.from_file(Path(path) if path else None)
    logger.info(
        "Concept graph loaded: %s",
        ", ".join(f"{r.id}={len(r.concepts)}" for r in graph.realms),
    )
    return graph
