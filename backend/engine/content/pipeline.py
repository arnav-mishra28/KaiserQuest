"""
The content pipeline.

    curated JSON  ─┐
                   ├─►  assign concepts  ─►  validate  ─►  estimate difficulty
    generators  ───┘                                            │
                                                                ▼
                            verified bank  ◄──  quarantine  ◄── gate

This is the only place questions enter the game from. Nothing downstream reads
the raw source files, so a question that fails verification cannot reach a
player by accident.

Output layout:

    data/banks/<subject>/<topic>.json   verified, enriched, game-ready
    data/banks/_quarantine.json         everything that failed, with reasons
    data/banks/_manifest.json           the audit trail: counts, distributions,
                                        difficulty-label disagreements

Run it with:  python -m engine.content.pipeline
"""

from __future__ import annotations

import json
import logging
import zlib
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

from engine.attempts import estimate_expected_time_ms
from engine.concepts import ConceptGraph, get_concept_graph
from engine.content.difficulty import DifficultyEstimator
from engine.content.generator import ContentGenerator
from engine.content.validator import QuestionValidator, ValidationReport
from engine.misconceptions import get_misconception_catalog

logger = logging.getLogger("kaiserquest.engine.content.pipeline")

BACKEND_ROOT = Path(__file__).resolve().parent.parent.parent
SOURCE_DIR = BACKEND_ROOT / "data" / "questions"
BANK_DIR = BACKEND_ROOT / "data" / "banks"

#: The Unity projects' Resources folders, so the game can ship the same verified
#: content the server serves, and be playable with no backend at all.
#:
#: The repo currently carries two Unity projects: `KaiserQuest/` is the live
#: Unity 6 project people open and play, and `KaiserQuest-Unity/` is the
#: 2022.3 development copy. Both must receive the verified banks, or the copy
#: someone actually plays quietly drifts out of sync with what the server
#: serves. Projects whose folders do not exist on disk are skipped, so this
#: degrades gracefully on a machine with only one of them checked out.
DEFAULT_UNITY_DIRS = [
    BACKEND_ROOT.parent / "KaiserQuest" / "Assets" / "Resources",
    BACKEND_ROOT.parent / "KaiserQuest-Unity" / "Assets" / "Resources",
]

# Kept as a single Path for callers that want one canonical export target.
DEFAULT_UNITY_DIR = DEFAULT_UNITY_DIRS[1]

#: How many generated questions to aim for per generatable concept.
DEFAULT_PER_CONCEPT = 15

#: A concept with fewer questions than this cannot run a trial. The pipeline
#: reports gaps rather than failing, because a gap is a content task, not a bug —
#: but it is never allowed to be silent: a concept with no questions makes the
#: milestone that teaches it unpassable, which is how a campaign becomes
#: unfinishable without anyone noticing.
MIN_QUESTIONS_PER_CONCEPT = 6


@dataclass
class PipelineReport:
    curated_in: int = 0
    curated_accepted: int = 0
    generated: int = 0
    generated_accepted: int = 0
    quarantined: int = 0
    concepts_covered: int = 0
    unity_export: List[str] = field(default_factory=list)
    concept_coverage: Dict[str, int] = field(default_factory=dict)
    coverage_gaps: List[dict] = field(default_factory=list)
    estimator: dict = field(default_factory=dict)
    difficulty_distribution: Dict[str, Dict[str, int]] = field(default_factory=dict)
    label_disagreements: List[dict] = field(default_factory=list)
    warning_counts: Dict[str, int] = field(default_factory=dict)
    quarantine_reasons: Dict[str, int] = field(default_factory=dict)
    topics_written: List[str] = field(default_factory=list)
    generated_at: str = ""

    def to_dict(self) -> dict:
        return {
            "generated_at": self.generated_at,
            "curated_in": self.curated_in,
            "curated_accepted": self.curated_accepted,
            "generated": self.generated,
            "generated_accepted": self.generated_accepted,
            "quarantined": self.quarantined,
            "concepts_covered": self.concepts_covered,
            "unity_export": self.unity_export,
            "concept_coverage": dict(sorted(self.concept_coverage.items())),
            "coverage_gaps": self.coverage_gaps,
            "estimator": self.estimator,
            "difficulty_distribution": self.difficulty_distribution,
            "label_disagreements": self.label_disagreements[:25],
            "warning_counts": dict(sorted(self.warning_counts.items(), key=lambda kv: -kv[1])),
            "quarantine_reasons": dict(
                sorted(self.quarantine_reasons.items(), key=lambda kv: -kv[1])
            ),
            "topics_written": self.topics_written,
        }

    def summary(self) -> str:
        lines = [
            "KaiserQuest content pipeline",
            f"  curated in        : {self.curated_in}",
            f"  curated accepted  : {self.curated_accepted}",
            f"  generated         : {self.generated}",
            f"  generated accepted: {self.generated_accepted}",
            f"  quarantined       : {self.quarantined}",
            f"  concepts covered  : {self.concepts_covered}",
            f"  concepts < {MIN_QUESTIONS_PER_CONCEPT} qs  : {len(self.coverage_gaps)}",
            f"  estimator         : {self.estimator.get('backend')} (MAE {self.estimator.get('mae')})",
            f"  topics written    : {len(self.topics_written)}",
        ]
        if self.quarantine_reasons:
            lines.append("  top quarantines   :")
            for reason, count in list(self.quarantine_reasons.items())[:5]:
                lines.append(f"      {count:>4}  {reason}")
        if self.label_disagreements:
            lines.append("  label disagreements needing review:")
            for item in self.label_disagreements[:3]:
                lines.append(
                    f"      human {item['human_difficulty']} vs estimated "
                    f"{item['estimated_difficulty']}: {item['question'][:60]}"
                )
        return "\n".join(lines)


class ConceptAssigner:
    """
    Decides which concept an untagged question belongs to.

    Order of precedence: what the author said, then keyword evidence in the
    question text, then the difficulty band. The third path is balanced across
    the domain so that a hand-written topic does not collapse onto one concept —
    otherwise the knowledge trace would be blind to most of the domain.
    """

    def __init__(self, graph: ConceptGraph):
        self.graph = graph
        self._assignment_counts: Dict[str, int] = {}

    def assign(self, question: dict) -> str:
        explicit = question.get("concept")
        if explicit and self.graph.has_concept(explicit):
            self._bump(explicit)
            return explicit

        topic = question.get("topic")
        text = f"{question.get('question', '')} {question.get('explanation', '')}"
        matches = self.graph.tag_text(text, topic=topic, top_k=1)
        if matches:
            self._bump(matches[0])
            return matches[0]

        return self._by_band(topic, int(question.get("difficulty", 2) or 2))

    def _by_band(self, topic: Optional[str], difficulty: int) -> str:
        candidates = self._candidates(topic)
        if not candidates:
            return ""

        def score(concept) -> Tuple[int, int, str]:
            band_distance = abs(concept.level - difficulty)
            return (band_distance, self._assignment_counts.get(concept.id, 0), concept.id)

        chosen = min(candidates, key=score)
        self._bump(chosen.id)
        return chosen.id

    def _candidates(self, topic: Optional[str]) -> List:
        if topic and self.graph.has_concept(topic):
            return []
        if topic:
            for realm in self.graph.realms:
                for domain in realm.domains:
                    if domain.id.lower() == str(topic).strip().lower():
                        return list(domain.concepts)
        return []

    def _bump(self, concept_id: str) -> None:
        self._assignment_counts[concept_id] = self._assignment_counts.get(concept_id, 0) + 1

    @property
    def assignment_counts(self) -> Dict[str, int]:
        return dict(self._assignment_counts)


class ContentPipeline:
    def __init__(
        self,
        graph: Optional[ConceptGraph] = None,
        source_dir: Optional[Path] = None,
        bank_dir: Optional[Path] = None,
        unity_dir: Optional[Path] = None,
    ):
        self.graph = graph or get_concept_graph()
        self.source_dir = source_dir or SOURCE_DIR
        self.bank_dir = bank_dir or BANK_DIR
        #: Where the Unity client's Resources live. Defaulted rather than
        #: required so the pipeline can be run in tests and on a build server
        #: without a Unity project present.
        # Unity files are only written when we are clearly running against the
        # real project. A caller who supplied their own source/bank directories is
        # in a test or a build script, and must not have files written into the
        # game's Resources folder as a side effect.
        if unity_dir is None:
            custom = source_dir is not None or bank_dir is not None
            unity_dirs = [] if custom else list(DEFAULT_UNITY_DIRS)
        else:
            unity_dirs = [unity_dir]
        # An explicit --unity-dir still gets the existence check: a typo in the
        # flag should fail loudly rather than silently write nowhere.
        if unity_dir is not None and not unity_dir.parent.exists():
            logger.warning("Unity export directory %s does not exist; skipping export", unity_dir)
            unity_dirs = []
        # Every export target must be a real Resources folder. A path that is
        # merely adjacent to one (e.g. `KaiserQuest/Assets` on a machine where
        # only the other project is checked out) is skipped with a note, not an
        # error — the other target still gets its export.
        self.unity_dirs: List[Path] = [
            d for d in unity_dirs if d.parent.exists() or _log_skipped_export(d)
        ]
        # Back-compat: first live target, for reporting.
        self.unity_dir: Optional[Path] = self.unity_dirs[0] if self.unity_dirs else None
        self.validator = QuestionValidator(self.graph)
        self.estimator = DifficultyEstimator(concept_level_lookup=self._concept_level)
        self.generator = ContentGenerator(self.graph)

    def _concept_level(self, concept_id: str) -> int:
        if concept_id and self.graph.has_concept(concept_id):
            return self.graph.concept(concept_id).level
        return 2

    # ------------------------------------------------------------------
    # Reading sources
    # ------------------------------------------------------------------
    def read_curated(self) -> List[dict]:
        """Every hand-written question, carrying its bank's subject and topic."""
        collected: List[dict] = []
        if not self.source_dir.exists():
            return collected
        for path in sorted(self.source_dir.rglob("*.json")):
            if path.name.startswith("_"):
                continue
            try:
                with open(path, "r", encoding="utf-8") as handle:
                    data = json.load(handle)
            except (json.JSONDecodeError, OSError) as exc:
                logger.warning("Skipping unreadable bank %s: %s", path, exc)
                continue
            subject = data.get("subject", path.parent.name)
            topic = data.get("topic", path.stem)
            for raw in data.get("questions", []):
                enriched = dict(raw)
                enriched.setdefault("subject", subject)
                enriched.setdefault("topic", topic)
                enriched["source"] = "curated"
                enriched["review_status"] = "human_authored"
                collected.append(enriched)
        return collected

    # ------------------------------------------------------------------
    # Pipeline stages
    # ------------------------------------------------------------------
    def enrich_curated(self, questions: Sequence[dict], assigner: ConceptAssigner) -> Tuple[List[dict], List[ValidationReport]]:
        reports: List[ValidationReport] = []
        enriched: List[dict] = []
        for question in questions:
            question = dict(question)
            question["concept"] = assigner.assign(question)
            question.setdefault("expected_time_ms", estimate_expected_time_ms(
                question.get("question", ""), question.get("options")
            ))
            question["estimated_difficulty"] = self.estimator.estimate_question(question)
            reports.append(self.validator.validate(question))
            enriched.append(question)
        return enriched, reports

    def generate(self, per_concept: int = DEFAULT_PER_CONCEPT, seed: Optional[int] = None) -> List[dict]:
        produced: List[dict] = []
        for concept_id in self.generator.supported_concepts():
            produced.extend(
                self.generator.generate(
                    concept_id,
                    per_concept,
                    seed=None if seed is None else seed + _stable_hash(concept_id) % 9973,
                )
            )
        for question in produced:
            question["estimated_difficulty"] = self.estimator.estimate_question(question)
        return produced

    def fit_estimator(self, curated: Sequence[dict]) -> dict:
        samples = [
            (
                q.get("question", ""),
                q.get("options"),
                self._concept_level(q.get("concept", "")),
                int(q.get("difficulty", 2) or 2),
            )
            for q in curated
            if q.get("concept")
        ]
        report = self.estimator.fit(samples)
        self._label_samples = samples
        return report.to_dict()

    def label_disagreements(self, tolerance: int = 2) -> List[dict]:
        samples = getattr(self, "_label_samples", [])
        return self.estimator.label_disagreements(samples, tolerance=tolerance)

    # ------------------------------------------------------------------
    # The run
    # ------------------------------------------------------------------
    def run(
        self,
        per_concept: int = DEFAULT_PER_CONCEPT,
        write: bool = True,
        seed: Optional[int] = None,
        verbose: bool = False,
    ) -> PipelineReport:
        report = PipelineReport(generated_at=datetime.now(timezone.utc).isoformat(timespec="seconds"))

        curated = self.read_curated()
        report.curated_in = len(curated)
        logger.info("Read %d curated questions", len(curated))

        # Stage 1: assign concepts to curated questions so the estimator can use
        # the human difficulty labels in context.
        curated_assigner = ConceptAssigner(self.graph)
        curated_enriched, _ = self.enrich_curated(curated, curated_assigner)

        # Stage 2: fit difficulty estimation on the human labels.
        report.estimator = self.fit_estimator(curated_enriched)
        report.label_disagreements = self.label_disagreements()

        # Stage 3: re-estimate and validate now that the model is fitted.
        curated_enriched, curated_reports = self.enrich_curated(curated, ConceptAssigner(self.graph))

        # Stage 4: generate and validate new content.
        generated = self.generate(per_concept=per_concept, seed=seed)
        report.generated = len(generated)
        generated_reports = [self.validator.validate(q) for q in generated]

        # Stage 5: gate.
        accepted: List[dict] = []
        quarantined: List[dict] = []
        for question, validation in zip(curated_enriched, curated_reports):
            if validation.ok:
                accepted.append(question)
            else:
                quarantined.append(self._quarantine_entry(question, validation))
        for question, validation in zip(generated, generated_reports):
            if validation.ok:
                accepted.append(question)
            else:
                quarantined.append(self._quarantine_entry(question, validation))

        report.curated_accepted = sum(1 for q in accepted if q.get("source") == "curated")
        report.generated_accepted = sum(1 for q in accepted if q.get("source") != "curated")
        report.quarantined = len(quarantined)

        all_reports = curated_reports + generated_reports
        report.warning_counts = self._count_warnings(all_reports)
        report.quarantine_reasons = self._count_reasons(quarantined)
        report.concepts_covered = len({q["concept"] for q in accepted if q.get("concept")})
        report.concept_coverage, report.coverage_gaps = self._coverage(accepted)
        report.difficulty_distribution = self._difficulty_distribution(accepted, generated_reports, curated_reports)

        if write:
            report.topics_written = self.write_banks(accepted)
            self.write_quarantine(quarantined)
            self.write_manifest(report)
            for export_dir in self.unity_dirs:
                report.unity_export.extend(self.export_unity(accepted, export_dir))

        if verbose:
            print(report.summary())
        logger.info(
            "Pipeline complete: %d accepted, %d quarantined, %d topics",
            len(accepted),
            len(quarantined),
            len(report.topics_written),
        )
        return report

    # ------------------------------------------------------------------
    # Output
    # ------------------------------------------------------------------
    def write_banks(self, questions: Sequence[dict]) -> List[str]:
        written: List[str] = []
        grouped: Dict[Tuple[str, str], List[dict]] = {}
        for question in questions:
            key = (str(question.get("subject", "math")), str(question.get("topic", "misc")))
            grouped.setdefault(key, []).append(question)

        for (subject, topic), items in sorted(grouped.items()):
            # Stable order: curated first, then generated, by concept then id, so
            # re-running the pipeline produces a clean diff instead of churn.
            ordered = sorted(
                items,
                key=lambda q: (
                    0 if q.get("source") == "curated" else 1,
                    q.get("concept", ""),
                    str(q.get("id", "")),
                ),
            )
            payload = {
                "subject": subject,
                "topic": topic,
                "generated_by": "kaiserquest-content-pipeline",
                "version": 1,
                "concepts": sorted({q["concept"] for q in ordered if q.get("concept")}),
                "counts": {
                    "total": len(ordered),
                    "curated": sum(1 for q in ordered if q.get("source") == "curated"),
                    "generated": sum(1 for q in ordered if q.get("source") != "curated"),
                },
                "questions": ordered,
            }
            target = self.bank_dir / subject / f"{topic}.json"
            target.parent.mkdir(parents=True, exist_ok=True)
            with open(target, "w", encoding="utf-8") as handle:
                json.dump(payload, handle, indent=2, ensure_ascii=False)
            written.append(f"{subject}/{topic}")
        return written

    def write_quarantine(self, quarantined: Sequence[dict]) -> None:
        target = self.bank_dir / "_quarantine.json"
        target.parent.mkdir(parents=True, exist_ok=True)
        with open(target, "w", encoding="utf-8") as handle:
            json.dump({"count": len(quarantined), "questions": list(quarantined)}, handle, indent=2, ensure_ascii=False)

    # ------------------------------------------------------------------
    # Unity export
    # ------------------------------------------------------------------
    def export_unity(self, questions: Sequence[dict], target_dir: Path) -> List[str]:
        """
        Write the bank in a shape `JsonUtility` can actually deserialise.

        Unity's built-in JSON reader has two hard limits that shape this export:
        it cannot deserialise dictionaries, and it cannot deserialise a top-level
        array. The pipeline's own format uses a `misconceptions` object map, which
        is exactly the kind of thing that silently arrives as an empty list. So
        the client copy stores misconception tags as a list of explicit pairs.

        `verify` blocks are dropped: they are a generation-time contract, not
        something the game needs, and shipping them would put the answer key's
        provenance into the player's install for no benefit.
        """
        target_dir.mkdir(parents=True, exist_ok=True)
        written: List[str] = []

        # Concept graph and misconception catalogue.
        knowledge_dir = target_dir / "Knowledge"
        knowledge_dir.mkdir(parents=True, exist_ok=True)
        with open(knowledge_dir / "concepts.json", "w", encoding="utf-8") as handle:
            json.dump(self.graph.to_dict(), handle, indent=2, ensure_ascii=False)
        written.append("Knowledge/concepts.json")

        catalogue = get_misconception_catalog()
        with open(knowledge_dir / "misconceptions.json", "w", encoding="utf-8") as handle:
            json.dump(
                {"misconceptions": [m.to_dict() for m in catalogue]},
                handle,
                indent=2,
                ensure_ascii=False,
            )
        written.append("Knowledge/misconceptions.json")

        # One verified bank per realm. These deliberately do NOT overwrite the
        # legacy `*_questions.json` files the older battle mode uses: that mode
        # keys on display names ('Mathematics' / 'Variables') while this bank keys
        # on ids ('math' / 'variables'), and quietly replacing one with the other
        # would break a working code path without saying so.
        grouped: Dict[str, List[dict]] = {}
        for question in questions:
            grouped.setdefault(str(question.get("subject", "math")), []).append(question)

        questions_dir = target_dir / "Questions"
        questions_dir.mkdir(parents=True, exist_ok=True)
        for subject, items in sorted(grouped.items()):
            payload = {
                "subject": subject,
                "count": len(items),
                "questions": [self._unity_question(q) for q in items],
            }
            name = f"bank_{subject}.json"
            with open(questions_dir / name, "w", encoding="utf-8") as handle:
                json.dump(payload, handle, indent=2, ensure_ascii=False)
            written.append(f"Questions/{name}")

        logger.info("Exported %d questions for the Unity client into %s", len(questions), target_dir)
        return written

    @staticmethod
    def _unity_question(question: dict) -> dict:
        mapping = question.get("misconceptions") or {}
        # Field names here are the C# field names, because JsonUtility matches on
        # name and silently leaves mismatched fields at their default value.
        return {
            "id": question.get("id"),
            "subject": question.get("subject"),
            "topic": question.get("topic"),
            "concept": question.get("concept"),
            "question": question.get("question"),
            "options": list(question.get("options") or []),
            "correctAnswer": question.get("correct_answer"),
            "explanation": question.get("explanation", ""),
            "difficulty": int(question.get("difficulty") or 3),
            "expectedTimeMs": float(question.get("expected_time_ms") or 0.0),
            "misconceptionTags": [
                {"distractor": str(distractor), "misconceptionId": str(tag)}
                for distractor, tag in mapping.items()
            ],
        }

    def write_manifest(self, report: PipelineReport) -> None:
        target = self.bank_dir / "_manifest.json"
        target.parent.mkdir(parents=True, exist_ok=True)
        with open(target, "w", encoding="utf-8") as handle:
            json.dump(report.to_dict(), handle, indent=2, ensure_ascii=False)

    # ------------------------------------------------------------------
    # Reporting helpers
    # ------------------------------------------------------------------
    def _coverage(self, accepted: Sequence[dict]) -> Tuple[Dict[str, int], List[dict]]:
        """
        Questions per concept across the whole graph, plus the concepts that fall
        short of MIN_QUESTIONS_PER_CONCEPT (or have none at all).
        """
        counts: Dict[str, int] = {}
        for question in accepted:
            concept = question.get("concept")
            if concept:
                counts[concept] = counts.get(concept, 0) + 1

        gaps: List[dict] = []
        for concept in self.graph:
            available = counts.get(concept.id, 0)
            if available < MIN_QUESTIONS_PER_CONCEPT:
                gaps.append(
                    {
                        "concept": concept.id,
                        "name": concept.name,
                        "realm": concept.realm,
                        "domain": concept.domain,
                        "questions": available,
                        "generatable": self.generator.supports(concept.id),
                    }
                )
        gaps.sort(key=lambda entry: (entry["questions"], entry["concept"]))
        if gaps:
            logger.warning(
                "%d concepts have fewer than %d questions: %s",
                len(gaps),
                MIN_QUESTIONS_PER_CONCEPT,
                ", ".join(f"{g['concept']}({g['questions']})" for g in gaps[:8]),
            )
        return counts, gaps

    def _quarantine_entry(self, question: dict, validation: ValidationReport) -> dict:
        return {
            "id": question.get("id"),
            "subject": question.get("subject"),
            "topic": question.get("topic"),
            "concept": question.get("concept"),
            "question": question.get("question", "")[:200],
            "source": question.get("source"),
            "errors": list(validation.errors),
            "warnings": [w for w in validation.warnings if not w.startswith("verified")],
        }

    def _count_warnings(self, reports: Iterable[ValidationReport]) -> Dict[str, int]:
        counts: Dict[str, int] = {}
        for report in reports:
            for warning in report.warnings:
                if warning.startswith("verified"):
                    continue
                key = warning.split("—")[0].split(":")[0][:90]
                counts[key] = counts.get(key, 0) + 1
        return counts

    def _count_reasons(self, quarantined: Sequence[dict]) -> Dict[str, int]:
        counts: Dict[str, int] = {}
        for entry in quarantined:
            for error in entry["errors"]:
                key = error.split("—")[0].split(":")[0][:90]
                counts[key] = counts.get(key, 0) + 1
        return counts

    def _difficulty_distribution(
        self,
        accepted: Sequence[dict],
        generated_reports: Sequence[ValidationReport],
        curated_reports: Sequence[ValidationReport],
    ) -> Dict[str, Dict[str, int]]:
        def histogram(questions: Sequence[dict], field_name: str) -> Dict[str, int]:
            buckets = {str(level): 0 for level in range(1, 6)}
            for question in questions:
                value = question.get(field_name)
                if value is None:
                    continue
                key = str(int(value))
                buckets[key] = buckets.get(key, 0) + 1
            return buckets

        generated_questions = [
            q for q in accepted if q.get("source") != "curated"
        ]
        curated_questions = [q for q in accepted if q.get("source") == "curated"]
        return {
            "curated_human_labels": histogram(curated_questions, "difficulty"),
            "curated_estimated": histogram(curated_questions, "estimated_difficulty"),
            "generated_estimated": histogram(generated_questions, "estimated_difficulty"),
        }


def _stable_hash(text: str) -> int:
    # Python's hash() is salted per process for str, so seeding the generator
    # with it would produce different questions on every run and every machine.
    # The pipeline's --seed flag is only meaningful if this is stable.
    return zlib.crc32(text.encode("utf-8"))


def _log_skipped_export(d: Path) -> bool:
    logger.info("Skipping Unity export into %s (no such project on disk)", d)
    return False


def main(argv: Optional[Sequence[str]] = None) -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Run the KaiserQuest content pipeline")
    parser.add_argument("--per-concept", type=int, default=DEFAULT_PER_CONCEPT)
    parser.add_argument("--seed", type=int, default=20260930)
    parser.add_argument("--dry-run", action="store_true", help="validate without writing banks")
    parser.add_argument("--quiet", action="store_true")
    parser.add_argument(
        "--unity-dir",
        type=Path,
        default=None,
        help="Resources folder to export client-ready JSON into (default: every Unity project in the repo)",
    )
    args = parser.parse_args(argv)

    logging.basicConfig(level=logging.INFO if not args.quiet else logging.WARNING, format="%(message)s")
    pipeline = ContentPipeline(unity_dir=args.unity_dir)
    report = pipeline.run(
        per_concept=args.per_concept,
        write=not args.dry_run,
        seed=args.seed,
    )
    print(report.summary())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
