"""
A tiny, auditable expression evaluator used to *verify* generated questions.

Nothing here is user input, but the content pipeline runs untrusted-ish strings
in a loop, so `eval` is not used. Only a whitelisted AST is accepted: numbers,
one variable, + - * / ** //, unary minus, and a handful of maths functions.

The verification trick that makes this worth having: an independent way to check
a claimed answer without re-using the code that produced it. For a linear
equation we never trust the solver's root — we evaluate f(x) = LHS - RHS at two
points to recover the coefficients, then confirm f(claimed) == 0. Solving and
verifying are genuinely different computations, which is what makes the check
meaningful rather than circular.
"""

from __future__ import annotations

import ast
import math
import re
from typing import Callable, Dict, List, Optional, Sequence, Tuple

__all__ = [
    "SafeExpressionError",
    "evaluate",
    "parse_expression",
    "linear_coefficients",
    "linear_root",
    "quadratic_value",
    "check_linear_solution",
    "check_quadratic_root",
    "expand_product",
    "poly_add",
    "poly_multiply",
    "poly_to_string",
    "poly_evaluate",
    "normalise_math",
]

_ALLOWED_FUNCTIONS: Dict[str, Callable[..., float]] = {
    "abs": abs,
    "sqrt": math.sqrt,
    "round": round,
    "min": min,
    "max": max,
    "pow": pow,
}

_ALLOWED_NAMES = {"pi": math.pi, "e": math.e}

_TOLERANCE = 1e-6


class SafeExpressionError(ValueError):
    """Raised when an expression contains anything outside the whitelist."""


_SUPERSCRIPT_DIGITS = {ord("\u2070"): "0", ord("\u00b9"): "1", ord("\u00b2"): "2",
                       ord("\u00b3"): "3", ord("\u2074"): "4", ord("\u2075"): "5",
                       ord("\u2076"): "6", ord("\u2077"): "7", ord("\u2078"): "8",
                       ord("\u2079"): "9"}

_IMPLICIT_MUL_PATTERNS = (
    (re.compile(r"(\d)\s*\("), r"\1*("),          # 3(x + 2)  -> 3*(x + 2)
    (re.compile(r"\)\s*\("), r")*("),            # (x+1)(x+2) -> (x+1)*(x+2)
    (re.compile(r"(\d)([a-zA-Z])"), r"\1*\2"),      # 3x -> 3*x (no space: '3 x' is prose)
    (re.compile(r"\)\s*(\d)"), r")*\1"),          # (x+1)2 -> (x+1)*2
)


def normalise_math(text: str) -> str:
    """
    Convert the things question text likes to write into parseable form:
    unicode operators, superscript powers, and implicit multiplication.

    Implicit multiplication matters because algebra is written '3(x + 2)', and
    '3(x + 2)' is a syntax error in Python. Inserting the `*` here means every
    verification path downstream accepts textbook notation for free.
    """
    cleaned = (
        (text or "")
        .replace("\u00d7", "*")
        .replace("\u00b7", "*")
        .replace("\u2212", "-")  # U+2212 minus
        .replace("\u2013", "-")
        .replace("\u00f7", "/")
    )
    # Caret power first, so '^' never survives into the multiplication pass.
    cleaned = re.sub(r"\^\s*(\d+)", r"**(\1)", cleaned)
    # 'x\u00b2' -> 'x**2', 'x\u00b2\u2075' -> 'x**25'
    buffer: List[str] = []
    index = 0
    while index < len(cleaned):
        char = cleaned[index]
        if ord(char) in _SUPERSCRIPT_DIGITS:
            digits = []
            while index < len(cleaned) and ord(cleaned[index]) in _SUPERSCRIPT_DIGITS:
                digits.append(_SUPERSCRIPT_DIGITS[ord(cleaned[index])])
                index += 1
            buffer.append(f"**({''.join(digits)})")
            continue
        buffer.append(char)
        index += 1
    cleaned = "".join(buffer)
    for pattern, replacement in _IMPLICIT_MUL_PATTERNS:
        cleaned = pattern.sub(replacement, cleaned)
    return cleaned.strip()


def _check_node(node: ast.AST, allowed_names: Sequence[str]) -> None:
    if isinstance(node, ast.Expression):
        return
    if isinstance(node, ast.Constant):
        if not isinstance(node.value, (int, float)):
            raise SafeExpressionError(f"Only numeric constants are allowed: {node.value!r}")
        return
    if isinstance(node, ast.Name):
        if node.id in _ALLOWED_NAMES or node.id in allowed_names:
            return
        raise SafeExpressionError(f"Unknown name '{node.id}'")
    if isinstance(node, ast.BinOp):
        if not isinstance(node.op, (ast.Add, ast.Sub, ast.Mult, ast.Div, ast.Pow, ast.FloorDiv)):
            raise SafeExpressionError("Unsupported operator")
        _check_node(node.left, allowed_names)
        _check_node(node.right, allowed_names)
        return
    if isinstance(node, ast.UnaryOp):
        if not isinstance(node.op, (ast.UAdd, ast.USub)):
            raise SafeExpressionError("Unsupported unary operator")
        _check_node(node.operand, allowed_names)
        return
    if isinstance(node, ast.Call):
        if not isinstance(node.func, ast.Name) or node.func.id not in _ALLOWED_FUNCTIONS:
            raise SafeExpressionError("Unsupported function call")
        for arg in node.args:
            _check_node(arg, allowed_names)
        return
    if isinstance(node, (ast.Tuple, ast.List)):
        for element in node.elts:
            _check_node(element, allowed_names)
        return
    raise SafeExpressionError(f"Disallowed syntax: {type(node).__name__}")


def parse_expression(expression: str, allowed_names: Sequence[str] = ("x",)) -> ast.Expression:
    """Parse and validate, returning a ready-to-evaluate AST."""
    try:
        tree = ast.parse(normalise_math(expression), mode="eval")
    except SyntaxError as exc:
        raise SafeExpressionError(f"Cannot parse '{expression}': {exc}") from exc
    _check_node(tree, allowed_names)
    return tree


def evaluate(expression: str, variables: Optional[Dict[str, float]] = None) -> float:
    """Evaluate a whitelisted expression with the given variable bindings."""
    variables = variables or {}
    tree = parse_expression(expression, allowed_names=tuple(variables.keys()) or ("x",))
    code = compile(tree, "<kaiserquest-expr>", "eval")

    def _resolve(name: str) -> float:
        if name in variables:
            return float(variables[name])
        if name in _ALLOWED_NAMES:
            return float(_ALLOWED_NAMES[name])
        raise SafeExpressionError(f"Unknown name '{name}'")

    # A private namespace object keeps `__builtins__` out of reach entirely.
    class _Namespace(dict):
        def __getitem__(self, key):
            if key in variables:
                return variables[key]
            if key in _ALLOWED_NAMES:
                return _ALLOWED_NAMES[key]
            if key in _ALLOWED_FUNCTIONS:
                return _ALLOWED_FUNCTIONS[key]
            raise KeyError(key)

    return float(eval(code, {"__builtins__": {}}, _Namespace()))  # noqa: S307 - whitelisted AST


# ---------------------------------------------------------------------------
# Polynomial helpers (coefficients are lowest-power-first lists)
# ---------------------------------------------------------------------------
def linear_coefficients(equation: str, variable: str = "x") -> Tuple[float, float]:
    """
    Recover (a, b) for a*x + b == 0 from a linear equation string.

    Uses two evaluations of (lhs - rhs): at 0 and at 1. This deliberately does
    not parse structure, so it cannot share a bug with a solver that does.
    """
    if "=" not in equation:
        raise SafeExpressionError(f"Not an equation: {equation!r}")
    lhs, rhs = equation.split("=", 1)
    at_zero = evaluate(f"({lhs}) - ({rhs})", {variable: 0.0})
    at_one = evaluate(f"({lhs}) - ({rhs})", {variable: 1.0})
    a = at_one - at_zero
    return a, at_zero


def linear_root(equation: str, variable: str = "x") -> float:
    a, b = linear_coefficients(equation, variable)
    if abs(a) < _TOLERANCE:
        raise SafeExpressionError(f"Not a linear equation in {variable}: {equation!r}")
    return -b / a


def quadratic_value(expression: str, x: float, variable: str = "x") -> float:
    return evaluate(expression, {variable: float(x)})


def check_linear_solution(equation: str, claimed: float, variable: str = "x", tolerance: float = 1e-4) -> bool:
    """Does `claimed` actually satisfy the equation? (substitution, not solving)"""
    if "=" not in equation:
        return False
    lhs, rhs = equation.split("=", 1)
    difference = evaluate(f"({lhs}) - ({rhs})", {variable: float(claimed)})
    return abs(difference) <= tolerance


def check_quadratic_root(expression: str, claimed: float, variable: str = "x", tolerance: float = 1e-4) -> bool:
    return abs(quadratic_value(expression, claimed, variable)) <= tolerance


def expand_product(factors: Sequence[str], variable: str = "x") -> str:
    """
    Multiply bracket factors into a single polynomial expression string.

    Used to verify factorisations: expand the claimed factors and compare with
    the original polynomial coefficient by coefficient.
    """
    poly: List[float] = [1.0]
    for factor in factors:
        coefficients = _linear_coefficients_from_expression(factor, variable)
        poly = poly_multiply(poly, coefficients)
    return poly_to_string(poly, variable)


def _linear_coefficients_from_expression(expression: str, variable: str = "x") -> List[float]:
    at_zero = evaluate(expression, {variable: 0.0})
    at_one = evaluate(expression, {variable: 1.0})
    return [at_zero, at_one - at_zero]


def poly_multiply(left: Sequence[float], right: Sequence[float]) -> List[float]:
    result = [0.0] * (len(left) + len(right) - 1)
    for i, a in enumerate(left):
        for j, b in enumerate(right):
            result[i + j] += a * b
    return result


def poly_add(left: Sequence[float], right: Sequence[float]) -> List[float]:
    size = max(len(left), len(right))
    result = [0.0] * size
    for index in range(size):
        a = left[index] if index < len(left) else 0.0
        b = right[index] if index < len(right) else 0.0
        result[index] = a + b
    return result


def poly_evaluate(coefficients: Sequence[float], x: float) -> float:
    total = 0.0
    for power, coefficient in enumerate(coefficients):
        total += coefficient * (x ** power)
    return total


def poly_to_string(coefficients: Sequence[float], variable: str = "x") -> str:
    """Render lowest-power-first coefficients as a readable expression."""
    terms: List[str] = []
    for power in range(len(coefficients) - 1, -1, -1):
        coefficient = coefficients[power]
        if abs(coefficient) < _TOLERANCE:
            continue
        rounded = round(coefficient, 6)
        if abs(rounded - round(rounded)) < _TOLERANCE:
            rounded = int(round(rounded))
        sign = "-" if rounded < 0 else "+"
        magnitude = abs(rounded)
        if power == 0:
            body = f"{magnitude}"
        elif power == 1:
            body = f"{variable}" if magnitude == 1 else f"{magnitude}{variable}"
        else:
            body = f"{variable}^{power}" if magnitude == 1 else f"{magnitude}{variable}^{power}"
        if not terms:
            terms.append(f"-{body}" if sign == "-" else body)
        else:
            terms.append(f" {sign} {body}")
    return "".join(terms) if terms else "0"
