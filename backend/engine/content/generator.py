"""
Procedural content generation.

Generating questions is the easy half. The hard half is making a generated
question *trustworthy*, which is why every generator here does two things the
naive version would skip:

1. It attaches a `verify` block that lets the validator re-derive the answer by
   a different route (substitution, expansion, sampling). A generator cannot
   certify its own output.

2. It attaches misconception tags to specific distractors. Because the generator
   constructed the wrong option, it knows precisely which broken rule produces
   it — so a player who picks it gets a *named* misconception and a targeted
   remedy instead of a red cross.

Every generated question is therefore teachable in a way a random question is
not: it carries the lesson for its own most likely failure.

Coverage: the algebra domain in depth, because it is the vertical slice. Other
realms are served by the curated banks plus template generation.
"""

from __future__ import annotations

import logging
import random
import re
from dataclasses import dataclass
from typing import Callable, Dict, List, Optional, Sequence, Tuple

from engine.attempts import estimate_expected_time_ms
from engine.concepts import ConceptGraph, get_concept_graph

logger = logging.getLogger("kaiserquest.engine.content.generator")

# ---------------------------------------------------------------------------
# Small formatting helpers — question text has to read like a textbook, not
# like a repr().
# ---------------------------------------------------------------------------
SUPERSCRIPT = {"0": "\u2070", "1": "\u00b9", "2": "\u00b2", "3": "\u00b3", "4": "\u2074",
               "5": "\u2075", "6": "\u2076", "7": "\u2077", "8": "\u2078", "9": "\u2079"}


def superscript(power: int) -> str:
    return "".join(SUPERSCRIPT[ch] for ch in str(power))


def signed(value: int) -> str:
    return f"+ {value}" if value >= 0 else f"- {abs(value)}"


def term(coefficient: int, variable: str = "x", power: int = 1) -> str:
    """Render '3x', '-x', 'x^2', '3x^2'."""
    if coefficient == 0:
        return "0"
    sign = "-" if coefficient < 0 else ""
    magnitude = abs(coefficient)
    if power == 0:
        return f"{sign}{magnitude}"
    body = variable if magnitude == 1 else f"{magnitude}{variable}"
    if power > 1:
        body += superscript(power)
    return f"{sign}{body}"


def polynomial(coefficients: Sequence[int], variable: str = "x") -> str:
    """Render coefficients (highest power first) as a readable polynomial."""
    parts: List[str] = []
    degree = len(coefficients) - 1
    for index, coefficient in enumerate(coefficients):
        if coefficient == 0:
            continue
        power = degree - index
        rendered = term(coefficient, variable, power)
        if not parts:
            parts.append(rendered)
        else:
            parts.append(f" {'-' if coefficient < 0 else '+'} {rendered.lstrip('-')}")
    return "".join(parts) if parts else "0"


def factor(coefficient: int, constant: int, variable: str = "x") -> str:
    """Render a bracket factor like (x + 5) or (2x - 3)."""
    body = term(coefficient, variable, 1)
    if constant == 0:
        return f"({body})"
    return f"({body} {'+' if constant > 0 else '-'} {abs(constant)})"


@dataclass
class GenContext:
    rng: random.Random

    def int(self, low: int, high: int) -> int:
        return self.rng.randint(low, high)

    def choice(self, items: Sequence):
        return self.rng.choice(list(items))


def make_options(
    correct: str,
    distractors: Sequence[str],
    rng: random.Random,
    minimum: int = 4,
) -> List[str]:
    """
    Build a clean option list: correct answer plus unique distractors, shuffled.

    Numbers are compared as numbers, not strings, so '8' and '8.0' never appear
    as two options on the same question.
    """
    options: List[str] = [correct]
    seen = {_normalise_option(correct)}
    for candidate in distractors:
        key = _normalise_option(candidate)
        if key in seen:
            continue
        seen.add(key)
        options.append(candidate)
        if len(options) >= minimum:
            break
    # Generators are written to supply at least three distinct distractors; if
    # one did not, padding with invented filler would be worse than shipping a
    # three-option question. The validator accepts >= 2.
    rng.shuffle(options)
    return options


#: Matches only genuine answer-lists of roots, e.g. "x = 3 or x = -5".
#: It must be this strict: a looser pattern also matches "x + 7" and "7 + x",
#: which would make two legitimately different distractors look like duplicates
#: and silently drop one of them.
_ROOTS_FORM_RE = re.compile(
    r"^\s*x\s*=\s*-?\d+(?:\.\d+)?\s*(?:(?:,|\bor\b|\band\b)\s*x\s*=\s*-?\d+(?:\.\d+)?\s*)*$",
    re.IGNORECASE,
)


def _normalise_option(text: str) -> str:
    """
    A canonical key for comparing two options.

    Numbers compare numerically so '8' and '8.0' never appear twice. For answers
    of the form 'x = 3 or x = -5' the key is the *set of numbers*, because
    'x = 3 or x = -5' and 'x = -5 or x = 3' are the same answer written twice —
    a duplicate that a string comparison would happily let through.
    """
    cleaned = str(text).strip()
    compact = cleaned.replace(" ", "")
    try:
        return f"{float(compact):.10g}"
    except ValueError:
        pass
    if _ROOTS_FORM_RE.match(cleaned):
        numbers = sorted(re.findall(r"-?\d+(?:\.\d+)?", cleaned))
        if numbers:
            return "roots:" + ",".join(numbers)
    return compact.lower()


def format_number(value: float) -> str:
    """Render a number the way a textbook would: '5', '-2.5', not '5.0'."""
    if abs(value - round(value)) < 1e-9:
        return str(int(round(value)))
    return f"{value:.2f}".rstrip("0").rstrip(".")


# ---------------------------------------------------------------------------
# Generators. Each returns a partial question; the wrapper adds bookkeeping.
# ---------------------------------------------------------------------------
GeneratorFn = Callable[[GenContext], dict]


def _gen_substitution(ctx: GenContext) -> dict:
    a, b, x = ctx.int(2, 6), ctx.int(1, 12), ctx.int(2, 9)
    correct = a * x + b
    return {
        "question": f"Evaluate {a}x + {b} when x = {x}.",
        "correct_answer": str(correct),
        "distractors": [str(a + x + b), str(a * (x + b)), str(a * x - b)],
        "explanation": (
            f"Substitute x = {x}: {a}({x}) + {b} = {a * x} + {b} = {correct}. "
            f"Multiply before adding."
        ),
        "verify": {"kind": "numeric", "expression": f"{a}*{x} + {b}"},
    }


def _gen_constants(ctx: GenContext) -> dict:
    a, b = ctx.int(2, 9), ctx.int(1, 15)
    return {
        "question": f"In the expression {a}x + {b}, what is the coefficient of x?",
        "correct_answer": str(a),
        "distractors": [str(b), str(a + b), "x"],
        "explanation": (
            f"The coefficient is the number multiplying x, which is {a}. "
            f"{b} is a constant because it does not change with x."
        ),
    }


def _gen_evaluate_order(ctx: GenContext) -> dict:
    a, b, c = ctx.int(2, 9), ctx.int(2, 9), ctx.int(2, 9)
    correct = a + b * c
    return {
        "question": f"Evaluate {a} + {b} x {c}.",
        "correct_answer": str(correct),
        "distractors": [str((a + b) * c), str(a * b * c), str(a + b + c)],
        "explanation": (
            f"Multiplication comes before addition: {b} x {c} = {b * c}, "
            f"then {a} + {b * c} = {correct}. Working left to right would give {(a + b) * c}, which is wrong."
        ),
        "verify": {"kind": "numeric", "expression": f"{a} + {b}*{c}"},
    }


def _gen_expressions(ctx: GenContext) -> dict:
    n, k = ctx.int(2, 12), ctx.int(2, 9)
    forms = [
        (f"{k} more than a number x", f"x + {k}", [f"{k}x", f"x - {k}", f"{k} - x"], None),
        (f"a number x decreased by {k}", f"x - {k}", [f"{k} - x", f"x + {k}", f"{k}x"], None),
        (f"{k} times a number x", f"{k}x", [f"x + {k}", f"x - {k}", f"{k} + x"], None),
    ]
    text, correct, distractors, _ = ctx.choice(forms)
    return {
        "question": f"Which expression means '{text}'?",
        "correct_answer": correct,
        "distractors": distractors,
        "explanation": (
            f"Read the words as a description of the amount: '{text}' produces {correct}. "
            f"Translate the meaning, not the word order."
        ),
    }


def _gen_like_terms(ctx: GenContext) -> dict:
    a, b, c = ctx.int(2, 9), ctx.int(2, 9), ctx.int(1, 12)
    total = a + b
    correct = f"{term(total)} + {c}"
    return {
        "question": f"Simplify {term(a)} + {term(b)} + {c}.",
        "correct_answer": correct,
        "distractors": [f"{term(a + b + c)}", f"{term(total)} - {c}", f"{term(a * b)} + {c}"],
        "misconceptions": {f"{term(a + b + c)}": "alg.like_terms_over_combined"},
        "explanation": (
            f"x-terms collect together: {a} + {b} = {total}, giving {term(total)}. "
            f"The constant {c} is a different kind of term, so it stays separate: {correct}."
        ),
        "verify": {"kind": "equivalent", "expression": f"{a}*x + {b}*x + {c}"},
    }


def _gen_distribute(ctx: GenContext) -> dict:
    a, b = ctx.int(2, 8), ctx.int(2, 9)
    correct = f"{term(a)} + {a * b}"
    partial = f"{term(a)} + {b}"
    product = a * b
    return {
        "question": f"Expand {a}(x + {b}).",
        "correct_answer": correct,
        "distractors": [partial, f"{term(a)} - {product}", f"{term(product)} + {product}"],
        "misconceptions": {partial: "alg.distribution_partial"},
        "explanation": (
            f"The {a} outside the bracket multiplies every term inside: "
            f"{a}\u00b7x + {a}\u00b7{b} = {correct}."
        ),
        "verify": {"kind": "equivalent", "expression": f"{a}(x + {b})"},
    }


def _gen_distribute_negative(ctx: GenContext) -> dict:
    a, b = ctx.int(2, 8), ctx.int(2, 9)
    correct = f"-{a}x + {a * b}"
    sign_dropped = f"{a}x - {a * b}"
    partial = f"-{a}x - {b}"
    return {
        "question": f"Expand -{a}(x - {b}).",
        "correct_answer": correct,
        "distractors": [partial, sign_dropped, f"-{a}x - {a * b}"],
        "misconceptions": {partial: "alg.distribution_partial"},
        "explanation": (
            f"Distribute the -{a} over both terms: -{a}\u00b7x + (-{a})(-{b}) = "
            f"-{a}x + {a * b}. The two negatives in the second term make a positive."
        ),
        "verify": {"kind": "equivalent", "expression": f"-{a}(x - {b})"},
    }


def _gen_factor_common(ctx: GenContext) -> dict:
    a, b = ctx.int(2, 9), ctx.int(2, 9)
    correct = f"{a}(x + {b})"
    return {
        "question": f"Factorise {term(a)} + {a * b}.",
        "correct_answer": correct,
        "distractors": [f"{a * b}(x + 1)", f"{a}(x - {b})", f"{term(a)} + {b}"],
        "explanation": (
            f"Both terms share a factor of {a}: {term(a)} + {a * b} = "
            f"{a}\u00b7x + {a}\u00b7{b} = {a}(x + {b})."
        ),
        "verify": {"kind": "equivalent", "expression": f"{a}*x + {a * b}"},
    }


def _gen_one_step(ctx: GenContext) -> dict:
    style = ctx.int(0, 2)
    x = ctx.int(2, 12)
    if style == 0:
        b = ctx.int(2, 15)
        c = x + b
        correct = str(x)
        wrong_same_op = str(c + b)
        return {
            "question": f"Solve for x:  x + {b} = {c}",
            "correct_answer": correct,
            "distractors": [wrong_same_op, str(c), str(b)],
            "misconceptions": {wrong_same_op: "alg.inverse_operation_wrong"},
            "explanation": (
                f"Subtract {b} from both sides to undo the addition: "
                f"x = {c} - {b} = {x}."
            ),
            "verify": {"kind": "linear_solution", "equation": f"x + {b} = {c}"},
        }
    if style == 1:
        b = ctx.int(2, 12)
        c = x - b
        correct = str(x)
        wrong_same_op = str(c - b)
        return {
            "question": f"Solve for x:  x - {b} = {c}",
            "correct_answer": correct,
            "distractors": [wrong_same_op, str(c), str(-x)],
            "misconceptions": {wrong_same_op: "alg.inverse_operation_wrong"},
            "explanation": (
                f"Add {b} to both sides to undo the subtraction: "
                f"x = {c} + {b} = {x}."
            ),
            "verify": {"kind": "linear_solution", "equation": f"x - {b} = {c}"},
        }
    a = ctx.int(2, 9)
    c = a * x
    correct = str(x)
    wrong_no_division = str(c)
    return {
        "question": f"Solve for x:  {a}x = {c}",
        "correct_answer": correct,
        "distractors": [wrong_no_division, str(c + a), str(c - a)],
        "misconceptions": {wrong_no_division: "alg.coefficient_not_divided"},
        "explanation": (
            f"{a}x means {a} copies of x. Dividing both sides by {a} gives "
            f"x = {c}/{a} = {x}."
        ),
        "verify": {"kind": "linear_solution", "equation": f"{a}*x = {c}"},
    }


def _gen_two_step(ctx: GenContext) -> dict:
    a, b, x = ctx.int(2, 7), ctx.int(2, 12), ctx.int(1, 9)
    c = a * x + b
    correct = str(x)
    stopped_early = str(c - b)
    adde = str(c + b)
    return {
        "question": f"Solve for x:  {a}x + {b} = {c}",
        "correct_answer": correct,
        "distractors": [stopped_early, adde, str((c + b) // a) if (c + b) % a == 0 else str(c)],
        "misconceptions": {
            stopped_early: "alg.coefficient_not_divided",
            adde: "alg.inverse_operation_wrong",
        },
        "explanation": (
            f"Undo the +{b} first: {a}x = {c} - {b} = {c - b}. Then undo the "
            f"multiply: x = {c - b}/{a} = {x}. Stopping at {c - b} leaves the {a} still attached to x."
        ),
        "verify": {"kind": "linear_solution", "equation": f"{a}*x + {b} = {c}"},
    }


def _gen_both_sides(ctx: GenContext) -> dict:
    x = ctx.int(1, 9)
    c = ctx.int(1, 6)
    a = c + ctx.int(1, 5)
    b = ctx.int(1, 12)
    d = a * x + b - c * x
    if d < 0:
        # Keep every coefficient positive so the question reads cleanly.
        return _gen_both_sides(ctx)
    correct = str(x)
    # Solving after moving the x-term without flipping its sign gives
    # (a+c)x = d - b, which is a smaller number than the true root.
    sign_error = format_number((d - b) / (a + c))
    return {
        "question": f"Solve for x:  {a}x + {b} = {c}x + {d}",
        "correct_answer": correct,
        "distractors": [sign_error, str(d - b), str(x + 1)],
        "misconceptions": {sign_error: "alg.sign_error_moving_terms"},
        "explanation": (
            f"Subtract {c}x from both sides: {a - c}x + {b} = {d}. Subtract {b}: "
            f"{a - c}x = {d - b}. Divide: x = {x}. Moving a term across the equals sign flips its sign."
        ),
        "verify": {"kind": "linear_solution", "equation": f"{a}*x + {b} = {c}*x + {d}"},
    }


def _gen_parentheses(ctx: GenContext) -> dict:
    a, b, x = ctx.int(2, 6), ctx.int(2, 9), ctx.int(1, 8)
    c = a * (x + b)
    correct = str(x)
    partial = str((c - b) // a) if (c - b) % a == 0 else str(c - b)
    return {
        "question": f"Solve for x:  {a}(x + {b}) = {c}",
        "correct_answer": correct,
        "distractors": [partial, str(c // a + b) if c % a == 0 else str(c + b), str(c - b)],
        "misconceptions": {partial: "alg.distribution_partial"},
        "explanation": (
            f"Divide both sides by {a}: x + {b} = {c // a if c % a == 0 else c}/{a}. "
            f"Then subtract {b} to get x = {x}. Alternatively expand first: {a}x + {a * b} = {c}."
        ),
        "verify": {"kind": "linear_solution", "equation": f"{a}(x + {b}) = {c}"},
    }


def _gen_proportion(ctx: GenContext) -> dict:
    # Build the proportion p/q = x/d so that the answer is a whole number:
    # x = p*d/q, which is exact when d is a multiple of q.
    q = ctx.int(2, 9)
    k = ctx.int(2, 9)
    d = q * k
    p = ctx.int(2, 9)
    answer = p * k
    correct = str(answer)
    return {
        "question": f"Solve for x:  {p}/{q} = x/{d}",
        "correct_answer": correct,
        "distractors": [str(p * d), str(k), str(p)],
        "explanation": (
            f"Cross-multiply: {p} x {d} = {q} x x, so {q}x = {p * d} and "
            f"x = {p * d}/{q} = {answer}."
        ),
        "verify": {"kind": "linear_solution", "equation": f"({p})/({q}) = x/({d})"},
    }


def _gen_standard_form(ctx: GenContext) -> dict:
    a, b, c = ctx.int(2, 6), ctx.int(2, 9), ctx.int(1, 12)
    return {
        "question": (
            f"The equation {a}x{superscript(2)} - {b}x + {c} = 0 is written in standard form. "
            f"What is the value of c in ax{superscript(2)} + bx + c = 0?"
        ),
        "correct_answer": str(c),
        "distractors": [str(a), str(-b), "0"],
        "explanation": (
            f"In ax{superscript(2)} + bx + c = 0 the constant term c is what is left when x = 0. "
            f"Here that is {c}. Note b = -{b}, including its sign."
        ),
    }


def _gen_factorise_quadratic(ctx: GenContext) -> dict:
    p, q = ctx.int(1, 7), ctx.int(1, 7)
    b = p + q
    c = p * q
    correct = f"(x + {p})(x + {q})"
    partial = f"(x + {p})(x - {q})"
    return {
        "question": f"Factorise x{superscript(2)} + {b}x + {c}.",
        "correct_answer": correct,
        "distractors": [partial, f"(x - {p})(x - {q})", f"(x + {b})(x + {c})"],
        "explanation": (
            f"Find two numbers that multiply to {c} and add to {b}: {p} and {q}. "
            f"So x{superscript(2)} + {b}x + {c} = {correct}. Check by expanding: "
            f"{p}\u00b7{q} = {c} and {p} + {q} = {b}."
        ),
        "verify": {
            "kind": "factorisation",
            "expression": f"x**2 + {b}*x + {c}",
            "factors": [f"(x + {p})", f"(x + {q})"],
            "answer_form": correct,
        },
    }


def _gen_zero_product(ctx: GenContext) -> dict:
    p, q = ctx.int(1, 8), ctx.int(1, 8)
    correct = f"x = {p} or x = {-q}"
    only_one = f"x = {p}"
    return {
        "question": f"Solve (x - {p})(x + {q}) = 0.",
        "correct_answer": correct,
        "distractors": [only_one, f"x = {-p} or x = {q}", f"x = {p + q}"],
        "misconceptions": {only_one: "alg.zero_product_ignored"},
        "explanation": (
            f"If a product is zero, at least one factor is zero. So x - {p} = 0 gives x = {p}, "
            f"and x + {q} = 0 gives x = {-q}. Both are solutions — a quadratic normally has two."
        ),
        "verify": {
            "kind": "factor_roots",
            "factors": [f"(x - {p})", f"(x + {q})"],
        },
    }


def _gen_quadratic_formula(ctx: GenContext) -> dict:
    r1 = ctx.int(-6, 6)
    r2 = r1 + ctx.int(1, 6)
    if r1 + r2 == 0:
        # Symmetric roots would make the sign-flip distractor the same answer
        # written the other way round. Pick another equation instead.
        return _gen_quadratic_formula(ctx)
    b = -(r1 + r2)
    c = r1 * r2
    correct = f"x = {r1} or x = {r2}"
    one_root = f"x = {r1}"
    wrong_sign = f"x = {-r1} or x = {-r2}"
    polynomial_text = f"x{superscript(2)} {'+' if b >= 0 else '-'} {abs(b)}x {'+' if c >= 0 else '-'} {abs(c)} = 0"
    return {
        "question": (
            f"Use the quadratic formula to solve {polynomial_text} "
            f"(the roots are whole numbers)."
        ),
        "correct_answer": correct,
        "distractors": [one_root, wrong_sign, f"x = {r1 + r2}"],
        "misconceptions": {one_root: "alg.quadratic_formula_sign"},
        "explanation": (
            f"With a = 1, b = {b}, c = {c}: the discriminant is b{superscript(2)} - 4ac = "
            f"{b * b - 4 * c}. Then x = ( -({b}) \u00b1 {b * b - 4 * c} ) / 2, "
            f"giving x = {r1} and x = {r2}. The \u00b1 produces both roots."
        ),
        "verify": {"kind": "factor_roots", "expression": f"x**2 + ({b})*x + ({c})"},
    }


def _gen_discriminant(ctx: GenContext) -> dict:
    kind = ctx.int(0, 2)
    if kind == 0:
        r1 = ctx.int(-5, 5)
        r2 = r1 + ctx.int(1, 5)
        b, c = -(r1 + r2), r1 * r2
        expected = "Two real solutions"
    elif kind == 1:
        r = ctx.int(-5, 5)
        b, c = -2 * r, r * r
        expected = "One real solution"
    else:
        # Deliberately constructed so the discriminant is negative: choose c
        # large enough that 4c always exceeds b^2.
        b = ctx.int(-4, 4)
        c = (b * b) // 4 + ctx.int(1, 6)
        expected = "No real solutions"
    discriminant = b * b - 4 * c
    return {
        "question": (
            f"How many real solutions does x{superscript(2)} + ({b})x + ({c}) = 0 have?"
        ),
        "correct_answer": expected,
        "distractors": [
            other
            for other in ("Two real solutions", "One real solution", "No real solutions")
            if other != expected
        ],
        "explanation": (
            f"The discriminant b{superscript(2)} - 4ac = ({b}){superscript(2)} - 4(1)({c}) = "
            f"{discriminant}. "
            + (
                "A positive discriminant means two real solutions."
                if discriminant > 0
                else "A zero discriminant means exactly one real solution (a repeated root)."
                if discriminant == 0
                else "A negative discriminant means no real solutions."
            )
        ),
        "verify": {
            "kind": "root_count",
            "expression": f"x**2 + ({b})*x + ({c})",
            "expected_count": 2 if discriminant > 0 else 1 if discriminant == 0 else 0,
        },
    }


def _gen_function_notation(ctx: GenContext) -> dict:
    a, b, k = ctx.int(2, 6), ctx.int(1, 9), ctx.int(2, 7)
    correct = a * k + b
    returns_input = str(k)
    return {
        "question": f"If f(x) = {a}x + {b}, what is f({k})?",
        "correct_answer": str(correct),
        "distractors": [returns_input, str(a * k * b), str(a + k + b)],
        "misconceptions": {returns_input: "alg.function_substitution"},
        "explanation": (
            f"In function notation f({k}) means 'apply the rule to the input {k}'. "
            f"So f({k}) = {a}({k}) + {b} = {correct}. The input is not the output."
        ),
        "verify": {"kind": "numeric", "expression": f"{a}*({k}) + {b}"},
    }


def _gen_composition(ctx: GenContext) -> dict:
    a, b = ctx.int(2, 5), ctx.int(1, 9)
    c, d = ctx.int(2, 5), ctx.int(1, 9)
    k = ctx.int(2, 6)
    inner = c * k + d
    correct = a * inner + b
    swapped = c * (a * k + b) + d
    forgot_inner = a * c * k + b
    return {
        "question": f"If f(x) = {a}x + {b} and g(x) = {c}x + {d}, what is f(g({k}))?",
        "correct_answer": str(correct),
        "distractors": [str(swapped), str(forgot_inner), str(a * inner)],
        "explanation": (
            f"Work from the inside out. g({k}) = {c}({k}) + {d} = {inner}. "
            f"Then f({inner}) = {a}({inner}) + {b} = {correct}. "
            f"Order matters: f(g(x)) is not g(f(x))."
        ),
        "verify": {"kind": "numeric", "expression": f"{a}*({c}*{k} + {d}) + {b}"},
    }


def _gen_inverse(ctx: GenContext) -> dict:
    a, b = ctx.int(2, 6), ctx.int(1, 9)
    correct = f"(x - {b})/{a}"
    return {
        "question": f"If f(x) = {a}x + {b}, what is the inverse function f\u207b\u00b9(x)?",
        "correct_answer": correct,
        "distractors": [f"1/({a}x + {b})", f"(x + {b})/{a}", f"{a}x - {b}"],
        "explanation": (
            f"To invert, undo the operations in reverse order. Start from y = {a}x + {b}, "
            f"swap and solve: x = (y - {b})/{a}, so f\u207b\u00b9(x) = {correct}. "
            f"Check it: f(f\u207b\u00b9(x)) = x. The reciprocal 1/({a}x + {b}) is not the inverse."
        ),
        "verify": {"kind": "inverse_function", "forward": f"{a}*t + {b}"},
    }


def _gen_slope(ctx: GenContext) -> dict:
    run = ctx.int(2, 6)
    # slope >= 2 keeps rise/run and run/rise distinct, so the inverted-slope
    # distractor can never collapse into the correct answer.
    slope = ctx.int(2, 5)
    rise = slope * run
    y0 = ctx.int(0, 6)
    y1 = y0 + rise
    correct = str(slope)
    inverted = format_number(run / rise)
    return {
        "question": (
            f"A line passes through the points (0, {y0}) and ({run}, {y1}). "
            f"What is its slope?"
        ),
        "correct_answer": correct,
        "distractors": [inverted, str(rise), str(run)],
        "misconceptions": {inverted: "alg.slope_inverted"},
        "explanation": (
            f"Slope is rise over run: the vertical change ({y1} - {y0} = {rise}) divided by "
            f"the horizontal change ({run} - 0 = {run}). So slope = {rise}/{run} = {slope}. "
            f"Dividing run by rise ({inverted}) inverts it."
        ),
        "verify": {"kind": "numeric", "expression": f"({y1} - {y0})/({run})"},
    }


def _gen_intercepts(ctx: GenContext) -> dict:
    m, b = ctx.int(2, 9), ctx.int(-9, 9)
    sign = "+" if b >= 0 else "-"
    return {
        "question": f"For the line y = {m}x {sign} {abs(b)}, what is the y-intercept?",
        "correct_answer": str(b),
        "distractors": [str(m), str(-b), "0"],
        "explanation": (
            f"In y = mx + c the y-intercept is c, the value of y when x = 0: "
            f"y = {m}(0) {sign} {abs(b)} = {b}. The slope {m} is a different thing."
        ),
    }


def _gen_line_equation(ctx: GenContext) -> dict:
    m, b = ctx.int(2, 9), ctx.int(1, 9)
    correct = f"y = {m}x + {b}"
    return {
        "question": (
            f"A straight line has slope {m} and y-intercept {b}. "
            f"What is the equation of the line?"
        ),
        "correct_answer": correct,
        "distractors": [f"y = {b}x + {m}", f"y = {m}x - {b}", f"y = {m} + {b}x"],
        "explanation": (
            f"Slope-intercept form is y = mx + c. The slope {m} multiplies x and the "
            f"intercept {b} is added: {correct}."
        ),
    }


def _gen_polynomial_degree(ctx: GenContext) -> dict:
    degree = ctx.int(2, 5)
    coefficients = [ctx.int(1, 5)] + [ctx.int(0, 4) for _ in range(degree)]
    coefficients[0] = ctx.int(1, 5)
    if all(c == 0 for c in coefficients[1:]):
        coefficients[-1] = ctx.int(1, 5)
    text = polynomial(coefficients)
    return {
        "question": f"What is the degree of the polynomial {text}?",
        "correct_answer": str(degree),
        "distractors": [str(coefficients[0]), str(degree + 1), str(degree - 1)],
        "explanation": (
            f"The degree is the highest power of x present, which is {degree}. "
            f"The leading coefficient {coefficients[0]} is separate from the degree."
        ),
    }


def _gen_polynomial_multiply(ctx: GenContext) -> dict:
    p, q = ctx.int(1, 7), ctx.int(1, 7)
    b, c = p + q, p * q
    correct = f"x{superscript(2)} + {b}x + {c}"
    partial = f"x{superscript(2)} + {c}"
    return {
        "question": f"Expand (x + {p})(x + {q}).",
        "correct_answer": correct,
        "distractors": [partial, f"x{superscript(2)} + {b}x + {b}", f"x{superscript(2)} + {c}x + {b}"],
        "misconceptions": {partial: "alg.distribution_partial"},
        "explanation": (
            f"Multiply every term in the first bracket by every term in the second: "
            f"x\u00b7x + x\u00b7{q} + {p}\u00b7x + {p}\u00b7{q} = x{superscript(2)} + {b}x + {c}."
        ),
        "verify": {"kind": "equivalent", "expression": f"(x + {p})(x + {q})"},
    }


def _gen_word_translate(ctx: GenContext) -> dict:
    n = ctx.int(3, 20)
    styles = [
        (f"{n} less than a number x", f"x - {n}", [f"{n} - x", f"x + {n}", f"{n}x"], f"{n} - x"),
        (f"{n} subtracted from a number x", f"x - {n}", [f"{n} - x", f"x + {n}", f"{n}x"], f"{n} - x"),
        (f"the sum of a number x and {n}", f"x + {n}", [f"{n} - x", f"x - {n}", f"{n}x"], None),
        (f"a number x multiplied by {n}", f"{n}x", [f"x + {n}", f"x - {n}", f"{n} + x"], None),
    ]
    text, correct, distractors, reversed_form = ctx.choice(styles)
    question = {
        "question": f"Write '{text}' as an expression.",
        "correct_answer": correct,
        "distractors": distractors,
        "explanation": (
            f"'{text}' describes the amount {correct}. Name the unknown first, then walk "
            f"through the sentence in order of meaning rather than word order."
        ),
    }
    if reversed_form:
        question["misconceptions"] = {reversed_form: "alg.word_variable_confusion"}
    return question


def _gen_word_consecutive(ctx: GenContext) -> dict:
    n = ctx.int(2, 20)
    total = 3 * n + 3
    correct = str(n)
    return {
        "question": (
            f"The sum of three consecutive whole numbers is {total}. "
            f"What is the smallest of the three numbers?"
        ),
        "correct_answer": correct,
        "distractors": [str(total // 3), str(n + 1), str(total // 3 - 2)],
        "explanation": (
            f"Call the smallest n. Then the others are n + 1 and n + 2, so 3n + 3 = {total}, "
            f"giving 3n = {total - 3} and n = {n}. The three numbers are {n}, {n + 1}, {n + 2}."
        ),
        "verify": {"kind": "numeric", "expression": f"({total} - 3)/3"},
    }


def _gen_domain_range(ctx: GenContext) -> dict:
    style = ctx.int(0, 2)
    if style == 0:
        a = ctx.int(2, 9)
        return {
            "question": f"For the function f(x) = 1/(x - {a}), which value must be excluded from the domain?",
            "correct_answer": str(a),
            "distractors": ["0", str(-a), "No value is excluded"],
            "explanation": (
                f"The domain is every input the rule can actually use. Dividing by zero is not "
                f"allowed, and x - {a} is zero when x = {a}, so {a} must be excluded."
            ),
        }
    if style == 1:
        k = ctx.int(1, 9)
        return {
            "question": f"For the function f(x) = x{superscript(2)} + {k}, what is the smallest value f(x) can take?",
            "correct_answer": str(k),
            "distractors": ["0", str(k + 1), "Any real number"],
            "explanation": (
                f"x{superscript(2)} is never negative, so its smallest value is 0, reached when x = 0. "
                f"That makes the smallest value of f(x) equal to {k}."
            ),
        }
    k = ctx.int(1, 9)
    return {
        "question": f"What is the range of f(x) = x{superscript(2)} + {k}?",
        "correct_answer": f"f(x) \u2265 {k}",
        "distractors": ["All real numbers", f"f(x) \u2264 {k}", "f(x) > 0"],
        "explanation": (
            f"The range is the set of outputs. Since x{superscript(2)} \u2265 0, the output is always "
            f"at least {k}; it is never negative and never smaller than {k}."
        ),
    }


def _gen_polynomial_divide(ctx: GenContext) -> dict:
    m = ctx.int(2, 6)
    k1, k2, k3 = ctx.int(1, 5), ctx.int(1, 5), ctx.int(1, 5)
    dividend = f"{m * k1}x{superscript(3)} + {m * k2}x{superscript(2)} + {m * k3}x"
    divisor = f"{m}x"
    correct = f"{k1}x{superscript(2)} + {k2}x + {k3}"
    wrong_power = f"{k1}x{superscript(2)} + {k2}x{superscript(2)} + {k3}"
    partial = f"{k1}x{superscript(3)} + {k2}x{superscript(2)} + {k3}x"
    return {
        "question": f"Divide {dividend} by {divisor}.",
        "correct_answer": correct,
        "distractors": [partial, wrong_power, f"{k1 + k2 + k3}x{superscript(2)}"],
        "explanation": (
            f"Divide each term separately and subtract the powers: "
            f"{m * k1}x{superscript(3)} \u00f7 {m}x = {k1}x{superscript(2)}, "
            f"{m * k2}x{superscript(2)} \u00f7 {m}x = {k2}x, and "
            f"{m * k3}x \u00f7 {m}x = {k3}. The answer is {correct}. "
            f"Every term needs dividing, not just the first."
        ),
        "misconceptions": {partial: "alg.distribution_partial"},
        "verify": {"kind": "equivalent", "expression": f"({dividend})/({divisor})"},
    }


def _gen_polynomial_remainder(ctx: GenContext) -> dict:
    a = ctx.int(2, 6)
    b, c = ctx.int(1, 9), ctx.int(1, 12)
    polynomial = f"x{superscript(2)} + {b}x + {c}"
    remainder = a * a + b * a + c
    return {
        "question": (
            f"What is the remainder when {polynomial} is divided by (x - {a})?"
        ),
        "correct_answer": str(remainder),
        "distractors": [str(a), str(b + c), str(remainder + a)],
        "explanation": (
            f"The remainder theorem says the remainder of dividing P(x) by (x - {a}) is P({a}). "
            f"So P({a}) = {a}\u00b2 + {b}({a}) + {c} = {a * a} + {b * a} + {c} = {remainder}. "
            f"No long division is needed."
        ),
        "verify": {"kind": "numeric", "expression": f"({a})**2 + {b}*({a}) + {c}"},
    }


def _gen_word_mixture(ctx: GenContext) -> dict:
    # Built so the answer is a whole number of litres:
    #   x*p1 + V2*p2 = (x + V2)*p3  =>  x = V2*(p3 - p2)/(p1 - p3)
    strength_gap_up = ctx.int(2, 5)      # p1 - p3
    scale = ctx.int(1, 6)
    volume = strength_gap_up * scale     # V2
    gap_down = ctx.int(1, 4)             # p3 - p2
    answer = scale * gap_down            # x
    target = 30
    weaker = target - gap_down
    stronger = target + strength_gap_up
    correct = str(answer)
    # Candidate wrong answers are filtered by magnitude rather than picked
    # blindly, because with small numbers the obvious choices collide and
    # collapse the question down to two options.
    candidates = [volume, volume + answer, answer + strength_gap_up, 2 * answer, abs(volume - answer), answer + 1]
    distractors: List[str] = []
    for candidate in candidates:
        if candidate > 0 and candidate != answer and str(candidate) not in distractors:
            distractors.append(str(candidate))
        if len(distractors) == 3:
            break
    return {
        "question": (
            f"A chemist has {volume} litres of a {weaker}% solution and a stock of "
            f"{stronger}% solution. How many litres of the {stronger}% solution must be added "
            f"to make the mixture {target}%?"
        ),
        "correct_answer": correct,
        "distractors": distractors,
        "explanation": (
            f"The amount of dissolved substance is conserved. Adding x litres of {stronger}% "
            f"to {volume} litres of {weaker}% must give {volume + answer} litres at {target}%: "
            f"{stronger}x + {weaker}·{volume} = {target}(x + {volume}), so x = {answer} litres."
        ),
        "verify": {
            "kind": "numeric",
            "expression": f"({volume}*({target} - {weaker}))/({stronger} - {target})",
        },
    }


def _gen_word_rates(ctx: GenContext) -> dict:
    speed = ctx.int(4, 20) * 5
    hours = ctx.int(2, 6)
    distance = speed * hours
    correct = str(speed)
    return {
        "question": (
            f"A train travels {distance} km in {hours} hours at a constant speed. "
            f"What is its average speed in km/h?"
        ),
        "correct_answer": correct,
        "distractors": [str(hours), str(distance * hours), str(distance - hours)],
        "explanation": (
            f"Average speed is distance divided by time: {distance} km / {hours} h = "
            f"{speed} km/h. Dividing the other way round ({hours}/{distance}) is a common slip."
        ),
        "verify": {"kind": "numeric", "expression": f"{distance}/{hours}"},
    }


GENERATORS: Dict[str, GeneratorFn] = {
    "variables.substitution": _gen_substitution,
    "variables.constants": _gen_constants,
    "variables.expressions": _gen_expressions,
    "variables.evaluate": _gen_evaluate_order,
    "expressions.like_terms": _gen_like_terms,
    "expressions.distribute": _gen_distribute,
    "expressions.factor_common": _gen_factor_common,
    "expressions.negatives": _gen_distribute_negative,
    "linear.one_step": _gen_one_step,
    "linear.two_step": _gen_two_step,
    "linear.both_sides": _gen_both_sides,
    "linear.parentheses": _gen_parentheses,
    "linear.proportion": _gen_proportion,
    "quadratics.standard_form": _gen_standard_form,
    "quadratics.factor": _gen_factorise_quadratic,
    "quadratics.zero_product": _gen_zero_product,
    "quadratics.formula": _gen_quadratic_formula,
    "quadratics.discriminant": _gen_discriminant,
    "functions.notation": _gen_function_notation,
    "functions.domain_range": _gen_domain_range,
    "functions.composition": _gen_composition,
    "functions.inverse": _gen_inverse,
    "graphs.slope": _gen_slope,
    "graphs.intercepts": _gen_intercepts,
    "graphs.line_equations": _gen_line_equation,
    "polynomials.degree": _gen_polynomial_degree,
    "polynomials.multiply": _gen_polynomial_multiply,
    "polynomials.divide": _gen_polynomial_divide,
    "polynomials.remainder": _gen_polynomial_remainder,
    "word.translate": _gen_word_translate,
    "word.consecutive": _gen_word_consecutive,
    "word.rates": _gen_word_rates,
    "word.mixture": _gen_word_mixture,
}

#: Add the authored item banks (English word forms and inference, Music
#: composition) to the procedural generators. These concepts cannot be generated
#: — their correctness is a fact, not a computation — but every concept in the
#: graph needs questions behind it or the milestone that teaches it is
#: unpassable.
from engine.templates import build_template_generators  # noqa: E402  (cycle-avoiding)

TEMPLATE_GENERATED = build_template_generators()
GENERATORS.update(TEMPLATE_GENERATED)

#: Which concepts came from an authored bank rather than a solver.
TEMPLATE_CONCEPTS = frozenset(TEMPLATE_GENERATED.keys())

#: Kinds of verification that the validator knows how to run. Used by the
#: pipeline to decide whether a generated question is "fully verified".
VERIFIABLE_KINDS = {
    "numeric",
    "linear_solution",
    "quadratic_root",
    "factorisation",
    "factor_roots",
    "root_count",
    "equivalent",
    "inverse_function",
    "one_of",
}


class ContentGenerator:
    """Turns (concept, count) into candidate questions, not yet validated."""

    def __init__(self, graph: Optional[ConceptGraph] = None):
        self.graph = graph or get_concept_graph()

    def supported_concepts(self) -> List[str]:
        return sorted(GENERATORS.keys())

    def supports(self, concept_id: str) -> bool:
        return concept_id in GENERATORS

    def generate(self, concept_id: str, count: int, seed: Optional[int] = None) -> List[dict]:
        if concept_id not in GENERATORS:
            raise KeyError(f"No generator for concept '{concept_id}'")
        concept = self.graph.concept(concept_id)
        rng = random.Random(seed if seed is not None else hash((concept_id, count)) & 0xFFFF)
        ctx = GenContext(rng=rng)

        produced: List[dict] = []
        seen_texts = set()
        attempt = 0
        while len(produced) < count and attempt < count * 12:
            attempt += 1
            raw = GENERATORS[concept_id](ctx)
            text = raw["question"]
            if text in seen_texts:
                continue
            seen_texts.add(text)
            produced.append(self._wrap(raw, concept, len(produced) + 1, rng))
        if len(produced) < count:
            logger.warning(
                "Generator for %s produced %d of %d requested unique questions",
                concept_id,
                len(produced),
                count,
            )
        return produced

    def _wrap(self, raw: dict, concept, index: int, rng: random.Random) -> dict:
        authored = concept.id in TEMPLATE_CONCEPTS
        options = make_options(raw["correct_answer"], raw.get("distractors", []), rng)
        # Only keep misconception tags whose distractor survived option
        # de-duplication. A tag pointing at a dropped option is a lie: the
        # player can never pick it, so the remedy could never fire.
        allowed = {option.strip() for option in options}
        correct_key = raw["correct_answer"].strip()
        misconceptions = {
            str(distractor): misconception_id
            for distractor, misconception_id in (raw.get("misconceptions") or {}).items()
            if str(distractor).strip() in allowed and str(distractor).strip() != correct_key
        }
        return {
            "id": f"gen_{concept.id.replace('.', '_')}_{index:03d}",
            "subject": "math",
            "topic": concept.domain,
            "concept": concept.id,
            "question": raw["question"],
            "options": options,
            "correct_answer": raw["correct_answer"],
            "explanation": raw.get("explanation", ""),
            "difficulty": concept.level,
            "misconceptions": misconceptions,
            "verify": raw.get("verify"),
            "source": "template" if authored else "procedural",
            "review_status": "authored" if authored else "auto_validated",
            "expected_time_ms": estimate_expected_time_ms(raw["question"], options),
        }
