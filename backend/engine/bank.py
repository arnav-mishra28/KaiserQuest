"""
The verified question bank.

Reads only what the content pipeline produced (`data/banks/`), falling back to
the curated sources when the pipeline has not been run yet. Selection is
adaptive: for each question slot the bank is asked for a question at a
difficulty derived from the player's current knowledge of that concept, and —
when the player has active misconceptions — from the distractors that would
surface them. That is how "the next learning sequence specifically addresses
that misconception" gets implemented rather than merely promised.
"""

from __future__ import annotations

import json
import logging
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Set, Tuple

logger = logging.getLogger("kaiserquest.engine.bank")

BACKEND_ROOT = Path(__file__).resolve().parent.parent
BANK_DIR = BACKEND_ROOT / "data" / "banks"
SOURCE_DIR = BACKEND_ROOT / "data" / "questions"


@dataclass
class SelectionSlot:
    """What the selector decided to ask, and why."""

    concept: str
    difficulty: int
    reason: str

    def to_dict(self) -> dict:
        return {"concept": self.concept, "difficulty": self.difficulty, "reason": self.reason}


class QuestionBankReader:
    def __init__(self, bank_dir: Optional[Path] = None, source_dir: Optional[Path] = None):
        self.bank_dir = bank_dir or BANK_DIR
        self.source_dir = source_dir or SOURCE_DIR
        self._questions: List[dict] = []
        self._by_id: Dict[str, dict] = {}
        self._by_concept: Dict[str, List[dict]] = {}
        self._by_subject_topic: Dict[Tuple[str, str], List[dict]] = {}
        self.loaded_from = ""
        self.reload()

    # ------------------------------------------------------------------
    def reload(self) -> None:
        directory = self.bank_dir if (self.bank_dir / "_manifest.json").exists() else self.source_dir
        if not directory.exists():
            logger.warning("No question data found in %s or %s", self.bank_dir, self.source_dir)
            directory = self.source_dir

        self._questions = []
        self._by_id = {}
        self._by_concept = {}
        self._by_subject_topic = {}
        self.loaded_from = str(directory)

        for path in sorted(directory.rglob("*.json")):
            if path.name.startswith("_"):
                continue
            try:
                with open(path, "r", encoding="utf-8") as handle:
                    data = json.load(handle)
            except (json.JSONDecodeError, OSError) as exc:
                logger.warning("Skipping %s: %s", path, exc)
                continue
            subject = data.get("subject", path.parent.name)
            topic = data.get("topic", path.stem)
            for raw in data.get("questions", []):
                question = dict(raw)
                question.setdefault("subject", subject)
                question.setdefault("topic", topic)
                self._questions.append(question)
                if question.get("id"):
                    self._by_id[str(question["id"])] = question
                concept = question.get("concept")
                if concept:
                    self._by_concept.setdefault(str(concept), []).append(question)
                self._by_subject_topic.setdefault((str(subject), str(topic)), []).append(question)
        logger.info("Question bank loaded: %d questions from %s", len(self._questions), self.loaded_from)

    # ------------------------------------------------------------------
    @property
    def size(self) -> int:
        return len(self._questions)

    def subjects(self) -> Dict[str, List[str]]:
        result: Dict[str, List[str]] = {}
        for subject, topic in self._by_subject_topic:
            result.setdefault(subject, []).append(topic)
        return {k: sorted(v) for k, v in sorted(result.items())}

    def get(self, question_id: str) -> Optional[dict]:
        return self._by_id.get(str(question_id))

    def for_concept(self, concept: str) -> List[dict]:
        return list(self._by_concept.get(concept, []))

    def concepts_with_questions(self) -> List[str]:
        return sorted(self._by_concept.keys())

    def coverage_report(self) -> Dict[str, int]:
        return {concept: len(items) for concept, items in sorted(self._by_concept.items())}

    # ------------------------------------------------------------------
    # Selection
    # ------------------------------------------------------------------
    def select(
        self,
        concepts: Sequence[str],
        count: int,
        target_difficulty: Dict[str, int],
        exclude_ids: Optional[Iterable[str]] = None,
        prefer_misconceptions: Optional[Iterable[str]] = None,
        rng: Optional[random.Random] = None,
    ) -> Tuple[List[dict], List[SelectionSlot]]:
        """
        Choose `count` questions spread across `concepts`.

        Round-robins across the concepts rather than sampling globally, so a
        milestone that covers two concepts gets asked about both. Within each
        concept, difficulty comes from `target_difficulty`, and questions that
        can surface one of `prefer_misconceptions` are taken first.
        """
        rng = rng or random.Random()
        excluded: Set[str] = {str(x) for x in (exclude_ids or [])}
        wanted_misconceptions: Set[str] = {m for m in (prefer_misconceptions or []) if m}

        chosen: List[dict] = []
        slots: List[SelectionSlot] = []
        used: Set[str] = set()

        # Concepts that actually have questions, in the given priority order.
        viable = [c for c in concepts if self._by_concept.get(c)]
        if not viable:
            logger.warning("No questions available for concepts %s", list(concepts))
            return [], []

        cursor = 0
        attempts = 0
        max_attempts = count * 30
        while len(chosen) < count and attempts < max_attempts:
            attempts += 1
            concept = viable[cursor % len(viable)]
            cursor += 1
            difficulty = target_difficulty.get(concept, 2)
            pool = [
                q
                for q in self._by_concept[concept]
                if str(q.get("id")) not in excluded and str(q.get("id")) not in used
            ]
            if not pool:
                continue

            question = self._pick(pool, difficulty, wanted_misconceptions, rng)
            if question is None:
                continue

            used.add(str(question.get("id")))
            chosen.append(question)
            slots.append(
                SelectionSlot(
                    concept=concept,
                    difficulty=int(question.get("difficulty") or difficulty),
                    reason=self._reason(question, difficulty, wanted_misconceptions),
                )
            )
        return chosen, slots

    def _pick(
        self,
        pool: List[dict],
        difficulty: int,
        wanted_misconceptions: Set[str],
        rng: random.Random,
    ) -> Optional[dict]:
        """
        Prefer misconception-surfacing questions, then closeness to the target
        difficulty, with a bounded amount of randomness so repeat runs differ.
        """
        scored: List[Tuple[int, int, dict]] = []
        for question in pool:
            tags = set((question.get("misconceptions") or {}).values())
            misconception_hit = 1 if (tags & wanted_misconceptions) else 0
            distance = abs(int(question.get("difficulty") or 3) - difficulty)
            scored.append((misconception_hit, -distance, question))
        best_hit = max(score[0] for score in scored)
        best_distance = max(score[1] for score in scored)
        # Shortlist the top tier and pick randomly from it, so the same trial is
        # not identical every time while still respecting the difficulty target.
        shortlist = [q for hit, distance, q in scored if hit == best_hit and distance >= best_distance - 1]
        return rng.choice(shortlist) if shortlist else None

    def _reason(self, question: dict, difficulty: int, wanted_misconceptions: Set[str]) -> str:
        tags = set((question.get("misconceptions") or {}).values())
        if tags & wanted_misconceptions:
            return f"Chosen to surface {next(iter(tags & wanted_misconceptions))}"
        return f"Difficulty {question.get('difficulty')} against a target of {difficulty}"


_READER: Optional[QuestionBankReader] = None


def get_bank_reader(refresh: bool = False) -> QuestionBankReader:
    global _READER
    if _READER is None or refresh:
        _READER = QuestionBankReader()
    return _READER


def grade(question: dict, chosen: Optional[str]) -> bool:
    """Is `chosen` the right answer for `question`?"""
    if chosen is None:
        return False
    correct = str(question.get("correct_answer", "")).strip()
    given = str(chosen).strip()
    if given == correct:
        return True
    # Numeric answers compare numerically so "8" and "8.0" agree.
    try:
        return abs(float(given) - float(correct)) < 1e-6
    except (TypeError, ValueError):
        return given.lower() == correct.lower()
