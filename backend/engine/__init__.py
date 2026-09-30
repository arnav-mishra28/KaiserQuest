"""
KaiserQuest Knowledge Engine.

The engine is what makes Kaiser Quest an RPG rather than a quiz: it maintains a
live estimate of what the player understands, what they have forgotten, what
they are confusing with what, and what they are ready to learn next. Everything
the world does — which door opens, which NPC appears, what the Archivist asks —
is derived from this package.

Design rule: the engine is pure Python with no I/O and no framework imports, so
it can be unit-tested directly and ported line-for-line to C# for offline play.
"""

from engine.concepts import Concept, ConceptGraph, Domain, Realm, get_concept_graph
from engine.attempts import Attempt, AttemptOutcome, AttemptLog
from engine.tracing import BKTParams, ConceptKnowledge, KnowledgeTracer
from engine.misconceptions import (
    Detection,
    Misconception,
    MisconceptionCatalog,
    MisconceptionDetector,
    get_misconception_catalog,
)
from engine.profile import KnowledgeProfile

__all__ = [
    "Concept",
    "ConceptGraph",
    "Domain",
    "Realm",
    "get_concept_graph",
    "Attempt",
    "AttemptOutcome",
    "AttemptLog",
    "BKTParams",
    "ConceptKnowledge",
    "KnowledgeTracer",
    "Detection",
    "Misconception",
    "MisconceptionCatalog",
    "MisconceptionDetector",
    "get_misconception_catalog",
    "KnowledgeProfile",
]
