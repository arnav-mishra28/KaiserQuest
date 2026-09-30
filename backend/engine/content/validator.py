"""
Content validation — the gate between generation and the game.

The vision is unambiguous that AI or procedurally generated questions must never
reach the player unchecked:

    AI generation -> Validation -> Difficulty estimation -> Human verification
                  -> Question bank -> Game

This module is that second box, and it is deliberately paranoid. Structural
checks catch malformed records. Independent verification catches the failure
that actually matters: a question whose stated correct answer is not correct.
For maths it re-derives the answer with a different method than the generator
used (see safemath), so a bug in a generator cannot validate itself.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Sequence

from engine.content import safemath
from engine.content.safemath import SafeExpressionError
from engine.concepts import ConceptGraph, get_concept_graph
from engine.misconceptions import MisconceptionCatalog, get_misconception_catalog

logger = logging.getLogger("kaiserquest.engine.content.validator")

REQUIRED_FIELDS = ("id", "question", "options", "correct_answer")

#: Distractor keys that are documentation rather than real options.
_METADATA_KEYS = {"explanation", "hint", "note"}


@dataclass
class ValidationReport:
    question_id: str
    ok: bool
    errors: List[str] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "question_id": self.question_id,
            "ok": self.ok,
            "errors": list(self.errors),
            "warnings": list(self.warnings),
        }

    def summary(self) -> str:
        state = "PASS" if self.ok else "FAIL"
        parts = [f"[{state}] {self.question_id}"]
        parts.extend(f"  error: {e}" for e in self.errors)
        parts.extend(f"  warn:  {w}" for w in self.warnings)
        return "\n".join(parts)


class QuestionValidator:
    def __init__(
        self,
        graph: Optional[ConceptGraph] = None,
        catalog: Optional[MisconceptionCatalog] = None,
    ):
        self.graph = graph or get_concept_graph()
        self.catalog = catalog or get_misconception_catalog()

    # ------------------------------------------------------------------
    def validate(self, question: dict) -> ValidationReport:
        question_id = str(question.get("id", "<missing-id>"))
        report = ValidationReport(question_id=question_id, ok=True)

        self._check_required(question, report)
        self._check_options(question, report)
        self._check_difficulty(question, report)
        self._check_concept(question, report)
        self._check_misconceptions(question, report)
        self._check_verification(question, report)

        report.ok = not report.errors
        return report

    def validate_many(self, questions: Sequence[dict]) -> List[ValidationReport]:
        return [self.validate(q) for q in questions]

    # ------------------------------------------------------------------
    # Structural checks
    # ------------------------------------------------------------------
    def _check_required(self, question: dict, report: ValidationReport) -> None:
        for field_name in REQUIRED_FIELDS:
            if not question.get(field_name) and question.get(field_name) != 0:
                report.errors.append(f"Missing required field '{field_name}'")
        if not str(question.get("question", "")).strip():
            report.errors.append("Question text is empty")
        if not str(question.get("explanation", "")).strip():
            # Not fatal, but a question with no explanation cannot teach, and
            # teaching is the whole point of this game.
            report.warnings.append("No explanation — the player cannot learn from a wrong answer")

    def _check_options(self, question: dict, report: ValidationReport) -> None:
        options = question.get("options")
        if options is None:
            return
        if not isinstance(options, list):
            report.errors.append("'options' must be a list")
            return
        if len(options) < 2:
            report.errors.append(f"Need at least 2 options, found {len(options)}")
        cleaned = [str(o).strip() for o in options]
        if any(not o for o in cleaned):
            report.errors.append("An option is empty")
        if len(set(cleaned)) != len(cleaned):
            duplicates = sorted({o for o in cleaned if cleaned.count(o) > 1})
            report.errors.append(f"Duplicate options: {duplicates}")
        correct = str(question.get("correct_answer", "")).strip()
        if correct and correct not in cleaned:
            report.errors.append(f"correct_answer '{correct}' is not among the options")

    def _check_difficulty(self, question: dict, report: ValidationReport) -> None:
        difficulty = question.get("difficulty")
        if difficulty is None:
            report.warnings.append("No difficulty — the estimator will supply one")
            return
        try:
            value = int(difficulty)
        except (TypeError, ValueError):
            report.errors.append(f"difficulty must be an integer, got {difficulty!r}")
            return
        if not 1 <= value <= 5:
            report.errors.append(f"difficulty {value} outside the 1-5 scale")

    def _check_concept(self, question: dict, report: ValidationReport) -> None:
        concept = question.get("concept")
        if not concept:
            report.errors.append("No concept assigned — the engine cannot trace what this teaches")
            return
        if not self.graph.has_concept(concept):
            report.errors.append(f"Unknown concept '{concept}' (not in the concept graph)")
            return
        expected = self.graph.concept(concept)
        topic = question.get("topic")
        if topic and topic != expected.domain:
            report.warnings.append(
                f"Concept '{concept}' belongs to domain '{expected.domain}' but topic is '{topic}'"
            )

    def _check_misconceptions(self, question: dict, report: ValidationReport) -> None:
        mapping = question.get("misconceptions")
        if not mapping:
            return
        if not isinstance(mapping, dict):
            report.errors.append("'misconceptions' must be a distractor -> misconception map")
            return
        options = {str(o).strip() for o in question.get("options", [])}
        correct = str(question.get("correct_answer", "")).strip()
        for distractor, misconception_id in mapping.items():
            if str(distractor) not in options:
                report.errors.append(f"Misconception key '{distractor}' is not an option")
            if str(distractor) == correct:
                report.errors.append(
                    f"Misconception '{misconception_id}' is mapped from the *correct* answer"
                )
            if misconception_id not in self.catalog:
                report.errors.append(f"Unknown misconception id '{misconception_id}'")

    # ------------------------------------------------------------------
    # Independent verification — the part that earns its keep
    # ------------------------------------------------------------------
    def _check_verification(self, question: dict, report: ValidationReport) -> None:
        verification = question.get("verify")
        if not verification:
            return
        if not isinstance(verification, dict):
            report.errors.append("'verify' must be a dict")
            return
        kind = verification.get("kind")
        try:
            ok, detail = self._run_verification(kind, verification, question)
        except SafeExpressionError as exc:
            report.errors.append(f"Verification could not run: {exc}")
            return
        if not ok:
            report.errors.append(f"Independent verification failed: {detail}")
        elif detail:
            report.warnings.append(f"verified ({detail})")

    def _run_verification(self, kind: Optional[str], verification: dict, question: dict):
        correct_raw = str(question.get("correct_answer", "")).strip()

        if kind == "numeric":
            expected = safemath.evaluate(verification["expression"])
            claimed = _to_number(correct_raw)
            return _close(expected, claimed), f"expression = {expected:g}"

        if kind == "linear_solution":
            claimed = _to_number(correct_raw)
            equation = verification["equation"]
            root = safemath.linear_root(equation, verification.get("variable", "x"))
            if not _close(root, claimed):
                return False, f"{equation} has root {root:g}, not {claimed:g}"
            if not safemath.check_linear_solution(equation, claimed, verification.get("variable", "x")):
                return False, f"{claimed:g} does not satisfy {equation} by substitution"
            return True, f"{equation} -> x = {root:g}"

        if kind == "quadratic_root":
            claimed = _to_number(correct_raw)
            expression = verification["expression"]
            if not safemath.check_quadratic_root(expression, claimed, verification.get("variable", "x")):
                return False, f"{claimed:g} is not a root of {expression}"
            return True, f"{expression} at x = {claimed:g} is zero"

        if kind == "factorisation":
            expression = verification["expression"]
            factors = verification["factors"]
            expanded = safemath.expand_product(factors, verification.get("variable", "x"))
            coefficients = _coefficients_from_expression(expression, verification.get("variable", "x"))
            expanded_coefficients = _coefficients_from_expression(expanded, verification.get("variable", "x"))
            if len(coefficients) != len(expanded_coefficients):
                return False, f"{expression} is degree {len(coefficients)-1} but the factors expand to degree {len(expanded_coefficients)-1}"
            for index, (a, b) in enumerate(zip(coefficients, expanded_coefficients)):
                if not _close(a, b, tolerance=1e-4):
                    return False, f"coefficient of x^{index}: {a:g} vs expanded {b:g}"
            if str(verification.get("answer_form", "")).strip() and correct_raw != verification["answer_form"]:
                return False, f"correct_answer is '{correct_raw}' but the verified form is '{verification['answer_form']}'"
            return True, f"factors expand to {expanded}"

        if kind == "one_of":
            # Several acceptable answers stated up front, e.g. both roots.
            acceptable = [str(a).strip() for a in verification.get("acceptable", [])]
            if correct_raw not in acceptable:
                return False, f"'{correct_raw}' is not among the verified answers {acceptable}"
            return True, "answer is in the verified set"

        if kind == "equivalent":
            # A simplification/factorisation is correct if the answer is
            # numerically identical to the original at several sample points.
            # Sampling sidesteps the need to implement algebraic equivalence.
            variable = verification.get("variable", "x")
            expression = verification["expression"]
            points = (0.0, 0.5, 1.0, 2.0, 3.7, -1.0, 6.25)
            compared = 0
            try:
                for point in points:
                    try:
                        original = safemath.evaluate(expression, {variable: point})
                        claimed_value = safemath.evaluate(correct_raw, {variable: point})
                    except ZeroDivisionError:
                        # A point where the expression is undefined (division by
                        # a factor that vanishes) proves nothing either way, so
                        # it is skipped rather than treated as a failure.
                        continue
                    if not _close(original, claimed_value, tolerance=1e-6):
                        return False, (
                            f"'{correct_raw}' gives {claimed_value:g} at {variable}={point:g} "
                            f"but {expression} gives {original:g}"
                        )
                    compared += 1
            except SafeExpressionError as exc:
                return False, f"'{correct_raw}' is not a comparable expression: {exc}"
            if compared < 2:
                return False, f"could not compare '{correct_raw}' with {expression} at enough points"
            return True, f"equivalent to {expression} at {compared} sample points"

        if kind == "factor_roots":
            # Independent route: expand the factors (or sample the polynomial),
            # solve the resulting polynomial, then require the stated answer to
            # name exactly those roots.
            variable = verification.get("variable", "x")
            if verification.get("factors"):
                expanded = safemath.expand_product(verification["factors"], variable)
            else:
                expanded = verification["expression"]
            coefficients = _coefficients_from_expression(expanded, variable)
            roots = _roots_of_polynomial(coefficients)
            if roots is None:
                return False, f"could not solve the polynomial {expanded}"
            claimed_numbers = _numbers_in(correct_raw)
            if not _multiset_close(roots, claimed_numbers):
                return False, (
                    f"'{correct_raw}' does not name the roots {[round(r, 4) for r in roots]} "
                    f"of {expanded}"
                )
            return True, f"roots {[round(r, 4) for r in roots]} confirmed from {expanded}"

        if kind == "root_count":
            variable = verification.get("variable", "x")
            coefficients = _coefficients_from_expression(verification["expression"], variable)
            if len(coefficients) != 3:
                return False, "root_count verification expects a quadratic"
            c0, c1, c2 = coefficients
            discriminant = c1 * c1 - 4 * c2 * c0
            count = 2 if discriminant > 1e-9 else 1 if abs(discriminant) <= 1e-9 else 0
            if count != int(verification["expected_count"]):
                return False, (
                    f"discriminant {discriminant:g} implies {count} real roots, "
                    f"not {verification['expected_count']}"
                )
            label = {2: "two", 1: "one", 0: "no"}[count]
            if label not in correct_raw.lower():
                return False, f"answer text '{correct_raw}' does not match {count} real solutions"
            return True, f"discriminant {discriminant:g} -> {count} real solutions"

        if kind == "inverse_function":
            # The cleanest inverse check there is: compose them and see if you
            # get the identity back. The forward function is given in `t`.
            forward = verification["forward"]
            for value in (0.0, 1.0, -2.0, 3.5, 10.0):
                try:
                    inverse_value = safemath.evaluate(correct_raw, {"x": value, "t": value})
                    round_trip = safemath.evaluate(forward, {"t": inverse_value, "x": inverse_value})
                except SafeExpressionError as exc:
                    return False, f"cannot evaluate inverse candidate: {exc}"
                if not _close(round_trip, value, tolerance=1e-6):
                    return False, (
                        f"f(f\u207b\u00b9({value:g})) = {round_trip:g}, not {value:g}"
                    )
            return True, f"f(f\u207b\u00b9(x)) = x for 5 sample inputs against {forward}"

        return False, f"unknown verification kind '{kind}'"


def _coefficients_from_expression(expression: str, variable: str = "x") -> List[float]:
    """
    Recover polynomial coefficients by sampling the expression at enough points
    and solving the resulting Vandermonde system. Sampling rather than parsing
    keeps the check independent of how the expression is written.
    """
    degree_guess = _guess_degree(expression, variable)
    samples = [float(i) for i in range(degree_guess + 1)]
    values = [safemath.evaluate(expression, {variable: x}) for x in samples]
    return _solve_vandermonde(samples, values)


def _guess_degree(expression: str, variable: str = "x") -> int:
    """
    Degree by repeated finite differences — robust for any expression string the
    evaluator accepts, and it needs no parsing at all.
    """
    points = [float(i) for i in range(9)]
    values = [safemath.evaluate(expression, {variable: x}) for x in points]
    for order in range(len(values) - 1):
        diffs = [values[i + 1] - values[i] for i in range(len(values) - 1)]
        if all(abs(d) < 1e-7 for d in diffs):
            return order
        values = diffs
    return len(points) - 2


def _solve_vandermonde(xs: Sequence[float], ys: Sequence[float]) -> List[float]:
    """Gaussian elimination on the Vandermonde system. Coefficients, lowest power first."""
    size = len(xs)
    matrix = [[xs[row] ** column for column in range(size)] + [ys[row]] for row in range(size)]
    for column in range(size):
        pivot = max(range(column, size), key=lambda r: abs(matrix[r][column]))
        if abs(matrix[pivot][column]) < 1e-12:
            raise SafeExpressionError("Singular system while recovering coefficients")
        matrix[column], matrix[pivot] = matrix[pivot], matrix[column]
        for row in range(size):
            if row == column:
                continue
            factor = matrix[row][column] / matrix[column][column]
            for k in range(column, size + 1):
                matrix[row][k] -= factor * matrix[column][k]
    return [matrix[i][size] / matrix[i][i] for i in range(size)]


def _to_number(text: str) -> float:
    cleaned = safemath.normalise_math(text).replace(" ", "")
    if not cleaned:
        raise SafeExpressionError("Answer is empty")
    try:
        return float(cleaned)
    except ValueError:
        return safemath.evaluate(cleaned)


def _roots_of_polynomial(coefficients: List[float]) -> Optional[List[float]]:
    """Real roots of a degree 0-2 polynomial given coefficients lowest-power-first."""
    trimmed = list(coefficients)
    while len(trimmed) > 1 and abs(trimmed[-1]) < 1e-9:
        trimmed.pop()
    degree = len(trimmed) - 1
    if degree <= 0:
        return []
    if degree == 1:
        return [-trimmed[0] / trimmed[1]]
    if degree == 2:
        c0, c1, c2 = trimmed
        discriminant = c1 * c1 - 4 * c2 * c0
        if discriminant < -1e-9:
            return []
        if abs(discriminant) <= 1e-9:
            return [-c1 / (2 * c2)]
        root = discriminant ** 0.5
        return [(-c1 + root) / (2 * c2), (-c1 - root) / (2 * c2)]
    return None


def _numbers_in(text: str) -> List[float]:
    """Every number in a string, keeping signs, e.g. 'x = 3 or x = -5' -> [3, -5]."""
    import re

    return [float(match) for match in re.findall(r"-?\d+(?:\.\d+)?", safemath.normalise_math(text))]


def _multiset_close(left: Sequence[float], right: Sequence[float], tolerance: float = 1e-4) -> bool:
    """Are the two collections the same numbers, order and duplicates aside?"""
    if len(left) != len(right):
        return False
    remaining = list(right)
    for value in left:
        for index, candidate in enumerate(remaining):
            if _close(value, candidate, tolerance):
                remaining.pop(index)
                break
        else:
            return False
    return True


def _close(a: float, b: float, tolerance: float = 1e-4) -> bool:
    return abs(a - b) <= tolerance * max(1.0, abs(a), abs(b))
