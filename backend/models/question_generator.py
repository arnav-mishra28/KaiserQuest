"""
KaiserQuest - Dynamic Question Generation System
Loads JSON question banks and dynamically selects / generates questions
for Math (Algebra), English, and Music Theory.
"""

from __future__ import annotations

import json
import logging
import os
import random
from pathlib import Path
from typing import Any, Dict, List, Optional

logger = logging.getLogger("kaiserquest.question_generator")

# Base path for question bank JSON files
DATA_DIR = Path(__file__).resolve().parent.parent / "data" / "questions"

# Cache loaded question banks
_question_cache: Dict[str, List[dict]] = {}


def _load_bank(subject: str, topic: str) -> List[dict]:
    """Load a question bank JSON file and cache it."""
    key = f"{subject}/{topic}"
    if key in _question_cache:
        return _question_cache[key]

    filepath = DATA_DIR / subject / f"{topic}.json"
    if not filepath.exists():
        logger.warning("Question bank not found: %s", filepath)
        return []

    with open(filepath, "r", encoding="utf-8") as f:
        data = json.load(f)

    questions = data.get("questions", [])
    _question_cache[key] = questions
    logger.info("Loaded %d questions from %s", len(questions), filepath)
    return questions


def get_available_subjects() -> Dict[str, List[str]]:
    """Return mapping of subject -> list of available topics."""
    result: Dict[str, List[str]] = {}
    if not DATA_DIR.exists():
        return result
    for subject_dir in sorted(DATA_DIR.iterdir()):
        if subject_dir.is_dir():
            topics = [
                f.stem for f in sorted(subject_dir.iterdir())
                if f.suffix == ".json"
            ]
            if topics:
                result[subject_dir.name] = topics
    return result


def get_questions(
    subject: str,
    topic: str,
    difficulty: Optional[int] = None,
    count: int = 5,
    exclude_ids: Optional[List[str]] = None,
) -> List[dict]:
    """
    Retrieve questions from the bank, filtered by difficulty.

    Args:
        subject: e.g. "math", "english", "music"
        topic: e.g. "variables", "grammar", "scales"
        difficulty: 1-5, or None for all difficulties
        count: number of questions to return
        exclude_ids: question IDs to skip (already seen)

    Returns:
        List of question dicts.
    """
    bank = _load_bank(subject.lower(), topic.lower())
    if not bank:
        # Try dynamic generation for math
        if subject.lower() == "math":
            return _generate_math_questions(topic.lower(), difficulty or 2, count)
        return []

    # Filter by difficulty
    pool = bank
    if difficulty is not None:
        pool = [q for q in bank if q.get("difficulty") == difficulty]
        # If no exact match, include ±1
        if not pool:
            pool = [q for q in bank if abs(q.get("difficulty", 3) - difficulty) <= 1]

    # Exclude already-seen questions
    if exclude_ids:
        excl = set(exclude_ids)
        pool = [q for q in pool if q.get("id") not in excl]

    if not pool:
        pool = bank  # fallback to full bank

    selected = random.sample(pool, min(count, len(pool)))
    return selected


def get_single_question(
    subject: str,
    topic: str,
    difficulty: Optional[int] = None,
    exclude_ids: Optional[List[str]] = None,
) -> Optional[dict]:
    """Get a single question."""
    qs = get_questions(subject, topic, difficulty, count=1, exclude_ids=exclude_ids)
    return qs[0] if qs else None


# ---------------------------------------------------------------------------
# Dynamic math question generation (procedural)
# ---------------------------------------------------------------------------
def _generate_math_questions(topic: str, difficulty: int, count: int) -> List[dict]:
    """Procedurally generate math questions when the bank is insufficient."""
    generators = {
        "variables": _gen_variable_q,
        "linear_equations": _gen_linear_eq_q,
        "quadratics": _gen_quadratic_q,
        "functions": _gen_function_q,
        "polynomials": _gen_polynomial_q,
    }
    gen_fn = generators.get(topic, _gen_variable_q)
    return [gen_fn(difficulty, i) for i in range(count)]


def _gen_variable_q(difficulty: int, idx: int) -> dict:
    a = random.randint(1, 3 * difficulty)
    b = random.randint(1, 5 * difficulty)
    answer = a + b
    return {
        "id": f"gen_var_{difficulty}_{idx}_{random.randint(1000,9999)}",
        "question": f"If x + {a} = {answer}, what is x?",
        "options": _make_options(b, spread=difficulty),
        "correct_answer": str(b),
        "explanation": f"x + {a} = {answer} → x = {answer} - {a} = {b}",
        "difficulty": difficulty,
        "topic": "variables",
        "subject": "math",
    }


def _gen_linear_eq_q(difficulty: int, idx: int) -> dict:
    a = random.randint(2, 3 * difficulty)
    x = random.randint(1, 5 * difficulty)
    b = random.randint(0, 4 * difficulty)
    rhs = a * x + b
    return {
        "id": f"gen_lin_{difficulty}_{idx}_{random.randint(1000,9999)}",
        "question": f"Solve for x: {a}x + {b} = {rhs}",
        "options": _make_options(x, spread=difficulty + 1),
        "correct_answer": str(x),
        "explanation": f"{a}x + {b} = {rhs} → {a}x = {rhs - b} → x = {(rhs - b) // a}",
        "difficulty": difficulty,
        "topic": "linear_equations",
        "subject": "math",
    }


def _gen_quadratic_q(difficulty: int, idx: int) -> dict:
    r1 = random.randint(-difficulty, difficulty) or 1
    r2 = random.randint(-difficulty, difficulty) or 2
    # x² - (r1+r2)x + r1*r2 = 0
    b = -(r1 + r2)
    c = r1 * r2
    b_str = f" + {b}x" if b > 0 else f" - {abs(b)}x" if b < 0 else ""
    c_str = f" + {c}" if c > 0 else f" - {abs(c)}" if c < 0 else ""
    roots = sorted([r1, r2])
    answer_str = f"x = {roots[0]} and x = {roots[1]}" if roots[0] != roots[1] else f"x = {roots[0]}"
    return {
        "id": f"gen_quad_{difficulty}_{idx}_{random.randint(1000,9999)}",
        "question": f"Find the roots of: x²{b_str}{c_str} = 0",
        "options": [answer_str, f"x = {roots[0]+1} and x = {roots[1]-1}",
                    f"x = {-roots[0]} and x = {-roots[1]}", f"x = {roots[0]*2}"],
        "correct_answer": answer_str,
        "explanation": f"Factor: (x - {r1})(x - {r2}) = 0, so {answer_str}",
        "difficulty": difficulty,
        "topic": "quadratics",
        "subject": "math",
    }


def _gen_function_q(difficulty: int, idx: int) -> dict:
    a = random.randint(1, difficulty + 1)
    b = random.randint(-3 * difficulty, 3 * difficulty)
    x_val = random.randint(1, 5)
    result = a * x_val + b
    return {
        "id": f"gen_func_{difficulty}_{idx}_{random.randint(1000,9999)}",
        "question": f"If f(x) = {a}x + {b}, what is f({x_val})?",
        "options": _make_options(result, spread=difficulty + 2),
        "correct_answer": str(result),
        "explanation": f"f({x_val}) = {a}×{x_val} + {b} = {a * x_val} + {b} = {result}",
        "difficulty": difficulty,
        "topic": "functions",
        "subject": "math",
    }


def _gen_polynomial_q(difficulty: int, idx: int) -> dict:
    a = random.randint(1, difficulty)
    b = random.randint(-5, 5)
    c = random.randint(-5, 5)
    degree = 2 + (difficulty > 3)
    if degree == 2:
        question = f"What is the degree of {a}x² + {b}x + {c}?"
        answer = "2"
    else:
        question = f"What is the degree of {a}x³ + {b}x² + {c}x + 1?"
        answer = "3"
    return {
        "id": f"gen_poly_{difficulty}_{idx}_{random.randint(1000,9999)}",
        "question": question,
        "options": ["1", "2", "3", "4"],
        "correct_answer": answer,
        "explanation": f"The highest power of x in the polynomial determines the degree.",
        "difficulty": difficulty,
        "topic": "polynomials",
        "subject": "math",
    }


def _make_options(correct: int, spread: int = 3, n: int = 4) -> List[str]:
    """Generate n options including the correct answer."""
    options = {correct}
    attempts = 0
    while len(options) < n and attempts < 50:
        offset = random.randint(-spread, spread)
        if offset != 0:
            options.add(correct + offset)
        attempts += 1
    # Fill remaining if needed
    while len(options) < n:
        options.add(correct + len(options) * 2)
    result = [str(x) for x in sorted(options)]
    random.shuffle(result)
    return result


def check_answer(question: dict, player_answer: str) -> bool:
    """Check if the player's answer matches the correct answer."""
    correct = str(question.get("correct_answer", "")).strip().lower()
    given = str(player_answer).strip().lower()
    return given == correct


def reload_banks():
    """Clear question cache to force reload from disk."""
    _question_cache.clear()
    logger.info("Question bank cache cleared")
