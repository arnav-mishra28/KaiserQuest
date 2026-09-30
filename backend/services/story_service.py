"""
The story service — where the engine meets the player.

This is the only object the API layer talks to. It owns:

  * sessions: a KnowledgeTracer, an AttemptLog, per-realm progress and a Silver
    Mountain state, loaded from and persisted to the save store
  * trials: assembling a milestone's questions adaptively, grading the answers,
    updating the knowledge trace, naming misconceptions, and judging the outcome
    on both score and mastery
  * the summit: the Archivist's exam, his three attempts, and the recap

Keeping all of that here rather than in the route handlers means the API stays a
thin translation layer, and the same logic can be embedded in the Unity client
(the C# port mirrors this file's behaviour for offline play).
"""

from __future__ import annotations

import logging
import random
import time
from dataclasses import dataclass, field
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

from engine.attempts import Attempt, AttemptLog, estimate_expected_time_ms
from engine.bank import QuestionBankReader, get_bank_reader, grade
from engine.campaign import Campaign, get_campaign
from engine.concepts import ConceptGraph, get_concept_graph
from engine.misconceptions import MisconceptionDetector, get_misconception_catalog
from engine.profile import KnowledgeProfile
from engine.progression import ProgressionService, RealmProgress, TrialResult
from engine.silver_mountain import (
    ATTEMPTS_PER_WINDOW,
    COOLDOWN_HOURS,
    EXAM_PASS_RATIO,
    EXAM_QUESTIONS,
    SilverMountain,
    SilverMountainState,
)
from engine.tracing import KnowledgeTracer
from services.save_store import SaveStore, get_save_store

logger = logging.getLogger("kaiserquest.story")

#: Breadth modes draw from everything taught up to this milestone, not just the
#: concepts it introduces. A tournament that only tests the newest chapter is
#: not a tournament.
BREADTH_MODES = {"tournament", "grand_tournament", "champion", "chain", "boss"}

#: How many attempts to keep in a save. Enough for realistic recency analysis,
#: bounded so a save file cannot grow without limit.
MAX_STORED_ATTEMPTS = 3000


@dataclass
class RealmSession:
    realm: str
    progress: RealmProgress
    silver: SilverMountainState

    @classmethod
    def create(cls, realm: str) -> "RealmSession":
        return cls(realm=realm, progress=RealmProgress(realm=realm), silver=SilverMountainState(realm=realm))


@dataclass
class PlayerSession:
    player_id: str
    name: str = "Kai"
    appearance: str = "default"
    realm: str = "algebra"
    created_at: float = field(default_factory=time.time)
    tracer: Optional[KnowledgeTracer] = None
    log: AttemptLog = field(default_factory=AttemptLog)
    realms: Dict[str, RealmSession] = field(default_factory=dict)
    last_save: dict = field(default_factory=dict)
    recent_question_ids: List[str] = field(default_factory=list)

    def realm_session(self, realm: str) -> RealmSession:
        if realm not in self.realms:
            self.realms[realm] = RealmSession.create(realm)
        return self.realms[realm]


class StoryService:
    def __init__(
        self,
        graph: Optional[ConceptGraph] = None,
        bank: Optional[QuestionBankReader] = None,
        store: Optional[SaveStore] = None,
    ):
        self.graph = graph or get_concept_graph()
        self.bank = bank or get_bank_reader()
        self.store = store or get_save_store()
        self.progression = ProgressionService(
            self.graph, coverage_lookup=lambda concept_id: len(self.bank.for_concept(concept_id))
        )
        self.mountain = SilverMountain(self.graph)
        self.detector = MisconceptionDetector(get_misconception_catalog())
        self._sessions: Dict[str, PlayerSession] = {}

    # ------------------------------------------------------------------
    # Sessions and persistence
    # ------------------------------------------------------------------
    def get_session(self, player_id: str) -> PlayerSession:
        if player_id in self._sessions:
            return self._sessions[player_id]

        payload = self.store.load(player_id)
        if payload:
            session = self._deserialise(payload)
        else:
            session = PlayerSession(player_id=player_id, tracer=KnowledgeTracer(player_id, self.graph))
        self._sessions[player_id] = session
        return session

    def persist(self, session: PlayerSession) -> None:
        try:
            self.store.save(session.player_id, self._serialise(session))
        except OSError as exc:
            logger.error("Could not save %s: %s", session.player_id, exc)

    def _serialise(self, session: PlayerSession) -> dict:
        attempts = session.log.all
        if len(attempts) > MAX_STORED_ATTEMPTS:
            attempts = attempts[-MAX_STORED_ATTEMPTS:]
        return {
            "player_id": session.player_id,
            "name": session.name,
            "appearance": session.appearance,
            "realm": session.realm,
            "created_at": session.created_at,
            "last_save": session.last_save,
            "knowledge": (session.tracer.to_dict() if session.tracer else {"knowledge": {}}),
            "attempts": [a.to_dict() for a in attempts],
            "realms": {
                realm: {
                    "progress": realm_session.progress.to_dict(),
                    "silver_mountain": realm_session.silver.to_dict(),
                }
                for realm, realm_session in session.realms.items()
            },
            "recent_question_ids": session.recent_question_ids[-200:],
        }

    def _deserialise(self, payload: dict) -> PlayerSession:
        player_id = payload.get("player_id", "")
        session = PlayerSession(
            player_id=player_id,
            name=payload.get("name", "Kai"),
            appearance=payload.get("appearance", "default"),
            realm=payload.get("realm", "algebra"),
            created_at=float(payload.get("created_at", time.time())),
            tracer=KnowledgeTracer.from_dict(
                {"player_id": player_id, "knowledge": (payload.get("knowledge") or {}).get("knowledge", {})},
                self.graph,
            ),
            log=AttemptLog.from_list(payload.get("attempts", [])),
            last_save=dict(payload.get("last_save") or {}),
            recent_question_ids=list(payload.get("recent_question_ids") or []),
        )
        for realm, data in (payload.get("realms") or {}).items():
            session.realms[realm] = RealmSession(
                realm=realm,
                progress=RealmProgress.from_dict(data.get("progress") or {"realm": realm}),
                silver=SilverMountainState.from_dict(data.get("silver_mountain") or {"realm": realm}),
            )
        return session

    # ------------------------------------------------------------------
    # Character creation
    # ------------------------------------------------------------------
    def create_character(
        self,
        player_id: str,
        name: str = "Kai",
        appearance: str = "default",
        realm: str = "algebra",
    ) -> dict:
        session = self.get_session(player_id)
        if not self.graph.find_realm(realm):
            raise KeyError(f"Unknown realm '{realm}'")
        session.name = (name or "Kai").strip()[:24] or "Kai"
        session.appearance = appearance or "default"
        session.realm = self.graph.find_realm(realm).id
        session.last_save = {
            "realm": session.realm,
            "milestone_index": 1,
            "place": self._campaign(session.realm).milestone(1).place,
            "saved_at": time.time(),
        }
        self.persist(session)
        return {
            "player_id": session.player_id,
            "name": session.name,
            "appearance": session.appearance,
            "realm": session.realm,
            "appearances_available": self.available_appearances(),
            "started_at_place": session.last_save["place"],
        }

    @staticmethod
    def available_appearances() -> List[dict]:
        """
        Presets rather than a slider: the player should be able to start in under
        a minute, and every preset must be readable at 16x16 pixels.
        """
        return [
            {"id": "default", "name": "Traveller", "palette": ["#3a5ba0", "#f2c14e", "#e8b48a"]},
            {"id": "scholar", "name": "Scholar", "palette": ["#4a4a6a", "#d9d9e3", "#e8b48a"]},
            {"id": "wanderer", "name": "Wanderer", "palette": ["#2f6b46", "#c96f3a", "#d9a87c"]},
            {"id": "maestro", "name": "Maestro", "palette": ["#6b3fa0", "#f0e6d2", "#c98f6a"]},
            {"id": "archivist", "name": "Archivist", "palette": ["#8c3a3a", "#e6d8b8", "#e8b48a"]},
        ]

    def _campaign(self, realm: str) -> Campaign:
        return get_campaign(realm, self.graph)

    def resolve_realm(self, player_id: str, realm: Optional[str] = None) -> str:
        """Public realm resolution: explicit value, else the character's realm."""
        return self._resolve_realm(self.get_session(player_id), realm)

    def campaign_detail(self, player_id: str, realm: Optional[str] = None) -> dict:
        """The full campaign for a player's realm, with narrative."""
        realm_id = self.resolve_realm(player_id, realm)
        campaign = self._campaign(realm_id)
        return {
            "realm": realm_id,
            "region": campaign.flavor.region,
            "milestones": [milestone.to_dict() for milestone in campaign.milestones],
        }

    # ------------------------------------------------------------------
    # World and profile
    # ------------------------------------------------------------------
    def realms(self) -> List[dict]:
        result: List[dict] = []
        for realm in self.graph.realms:
            campaign = self._campaign(realm.id)
            result.append(
                {
                    "id": realm.id,
                    "name": realm.name,
                    "section": realm.section,
                    "sigil": realm.sigil,
                    "accent": realm.accent,
                    "tagline": realm.tagline,
                    "region": campaign.flavor.region,
                    "domains": [{"id": d.id, "name": d.name, "concepts": len(d.concepts)} for d in realm.domains],
                    "concept_count": len(realm.concepts),
                    "milestones": len(campaign.milestones),
                    "questions_available": sum(len(self.bank.for_concept(c.id)) for c in realm.concepts),
                }
            )
        return result

    def profile(self, player_id: str, realm: Optional[str] = None) -> dict:
        session = self.get_session(player_id)
        realm_id = self._resolve_realm(session, realm)
        profile = KnowledgeProfile(
            player_id, realm_id, session.tracer, session.log, self.graph, self.detector
        )
        payload = profile.to_dict()
        payload["tree"] = profile.render_ascii()
        return payload

    def progress(self, player_id: str, realm: Optional[str] = None) -> dict:
        session = self.get_session(player_id)
        realm_id = self._resolve_realm(session, realm)
        realm_session = session.realm_session(realm_id)
        status = self.progression.status(self._campaign(realm_id), realm_session.progress, session.tracer)
        status["last_save"] = session.last_save or self._default_save(realm_id)
        return status

    def _resolve_realm(self, session: PlayerSession, realm: Optional[str]) -> str:
        if not realm:
            return session.realm
        found = self.graph.find_realm(realm)
        return found.id if found else session.realm

    def _default_save(self, realm_id: str) -> dict:
        campaign = self._campaign(realm_id)
        return {
            "realm": realm_id,
            "milestone_index": 1,
            "place": campaign.milestone(1).place,
            "saved_at": time.time(),
        }

    # ------------------------------------------------------------------
    # Trials
    # ------------------------------------------------------------------
    def start_trial(self, player_id: str, realm: Optional[str], index: Optional[int] = None) -> dict:
        session = self.get_session(player_id)
        realm_id = self._resolve_realm(session, realm)
        campaign = self._campaign(realm_id)
        realm_session = session.realm_session(realm_id)

        if index is None:
            index = campaign.first_unpassed(realm_session.progress.passed).index
        milestone = campaign.milestone(int(index))

        entry = self.progression.entry_check(campaign, milestone, realm_session.progress, session.tracer)
        if not entry["allowed"]:
            return {"granted": False, "milestone": milestone.to_dict(), "entry": entry, "questions": []}

        questions, slots = self._assemble_trial(session, campaign, milestone)
        if not questions:
            return {
                "granted": False,
                "milestone": milestone.to_dict(),
                "entry": entry,
                "questions": [],
                "error": "No verified questions are available for this milestone's concepts.",
            }

        session.recent_question_ids = ([q["id"] for q in questions] + session.recent_question_ids)[:200]
        return {
            "granted": True,
            "milestone": milestone.to_dict(),
            "entry": entry,
            "questions": [self._public_question(q) for q in questions],
            "selection": [slot.to_dict() for slot in slots],
            "attempt_number": realm_session.progress.attempts.get(milestone.index, 0) + 1,
        }

    def _assemble_trial(
        self,
        session: PlayerSession,
        campaign: Campaign,
        milestone,
    ) -> Tuple[List[dict], List]:
        """
        Choose the questions for one trial.

        Breadth modes (tournaments, the final gauntlets) draw on everything
        taught so far — but the concepts this milestone *introduces* always get
        asked about, and get asked about first. Otherwise a tournament with ten
        slots spread over thirty-four concepts could skip the new chapter
        entirely, and the player would be failed by the mastery gate for a
        concept they were never asked about.
        """
        own = [c for c in milestone.concepts if self.bank.for_concept(c)]
        if not own:
            # Content gap: fall back to the rest of the milestone's domain so the
            # trial can still run against something relevant rather than refusing
            # the player entry to a milestone they have reached.
            same_domain = [
                c.id
                for c in self.graph.concepts_of_domain(milestone.domain)
                if self.bank.for_concept(c.id)
            ]
            own = same_domain
            if not own:
                return [], []

        breadth = milestone.mode.id in BREADTH_MODES
        extra: List[str] = []
        if breadth:
            extra = [
                c
                for c in campaign.concepts_through(milestone.index)
                if c not in own and self.bank.for_concept(c)
            ]
            # Aim the breadth questions at whatever the player is worst at.
            extra.sort(key=lambda c: session.tracer.mastery(c))

        targets = {
            concept: self._target_difficulty(session, concept) for concept in own + extra
        }
        active_misconceptions = [
            d.misconception_id
            for d in self.detector.summarize(session.log, limit=4)
            if d.misconception_id
        ]
        rng = random.Random()
        exclude = session.recent_question_ids[-60:]

        def draw(concept_pool: List[str], count: int, exclude_ids: List[str]):
            if count <= 0 or not concept_pool:
                return [], []
            return self.bank.select(
                concepts=concept_pool,
                count=count,
                target_difficulty=targets,
                exclude_ids=exclude_ids,
                prefer_misconceptions=active_misconceptions,
                rng=rng,
            )

        # Guarantee the new concepts are examined deeply enough for the
        # milestone's own mastery gate to be reachable. Two questions per concept
        # tops out around 65% mastery, so a milestone gating at 80 must ask about
        # that concept more than twice, or its gate would be unpassable by design.
        guaranteed = min(
            milestone.mode.questions,
            max(2 * len(own), int(round(milestone.mode.questions * 0.5))),
        )
        questions, slots = draw(own, guaranteed, exclude)
        if len(questions) < guaranteed:
            # Retrying a trial must not run the bank dry: allow recent questions
            # back in rather than refusing the player entry.
            seen = [str(q.get("id")) for q in questions]
            top_up, top_up_slots = draw(own, guaranteed - len(questions), seen)
            questions.extend(top_up)
            slots.extend(top_up_slots)

        remaining = milestone.mode.questions - len(questions)
        if remaining > 0:
            used = [str(q.get("id")) for q in questions]
            pool = extra if breadth else own
            more, more_slots = draw(pool, remaining, exclude + used)
            if len(more) < remaining:
                more2, more_slots2 = draw(pool, remaining - len(more), used + [str(q.get("id")) for q in more])
                more.extend(more2)
                more_slots.extend(more_slots2)
            questions.extend(more)
            slots.extend(more_slots)
        return questions, slots

    def _target_difficulty(self, session: PlayerSession, concept: str) -> int:
        """
        The hidden adaptive difficulty.

        Derived from P(known) so a player who is solid gets stretched and a
        player who is struggling gets solid ground to stand on. The player is
        never shown a number; they simply find the questions meet them.
        """
        knowledge = session.tracer.get(concept)
        if knowledge.attempts == 0:
            base = self.graph.concept(concept).level if self.graph.has_concept(concept) else 2
            return max(1, min(5, base))
        p = knowledge.p_known_now()
        target = 1 + 4 * p
        if knowledge.attempts < 4:
            target -= 0.4  # be gentle while the estimate is still noisy
        # Test slightly above the estimate, which is where learning happens.
        return max(1, min(5, int(round(target + 0.25))))

    def submit_trial(
        self,
        player_id: str,
        realm: Optional[str],
        index: int,
        answers: Sequence[dict],
    ) -> dict:
        session = self.get_session(player_id)
        realm_id = self._resolve_realm(session, realm)
        campaign = self._campaign(realm_id)
        realm_session = session.realm_session(realm_id)
        milestone = campaign.milestone(int(index))

        graded = self._grade_answers(session, answers)
        result = TrialResult(
            milestone_index=milestone.index,
            correct=sum(1 for item in graded if item["correct"]),
            total=len(graded),
            duration_seconds=float(sum(float(a.get("response_time_ms", 0)) for a in answers) / 1000.0),
            hints_used=sum(int(a.get("hints_used", 0)) for a in answers),
            concepts_attempted=tuple(sorted({item["concept"] for item in graded})),
        )
        realm_session.progress.record_attempt(milestone.index, result.score_percent)

        # Only hold the player to concepts that were actually examined, and only
        # where the bank has enough material for the milestone's gate to be
        # reachable at all.
        examined = {item["concept"] for item in graded}
        gated = [c for c in milestone.concepts if c in examined]
        gated = self.progression.gradeable(gated)

        outcome = self.progression.evaluate(
            campaign,
            milestone,
            result,
            realm_session.progress,
            session.tracer,
            concepts_evaluated=gated,
        )

        if outcome.passed:
            session.last_save = {
                "realm": realm_id,
                "milestone_index": milestone.index,
                "place": milestone.place,
                "saved_at": time.time(),
            }

        self.persist(session)
        return {
            "outcome": outcome.to_dict(),
            "answers": graded,
            "progress": self.progress(player_id, realm_id),
            "profile": self.profile(player_id, realm_id),
        }

    def _grade_answers(self, session: PlayerSession, answers: Sequence[dict]) -> List[dict]:
        """
        Grade a set of answers and fold every one of them into the knowledge trace.

        Ordering matters: the attempt log must be updated before the next
        detection runs, because the detectors are history-based.
        """
        graded: List[dict] = []
        for answer in answers:
            question = self.bank.get(str(answer.get("question_id", "")))
            if not question:
                continue

            chosen = answer.get("chosen")
            correct = grade(question, chosen)
            concept = str(question.get("concept") or "")
            if not concept:
                continue

            expected_ms = float(
                question.get("expected_time_ms")
                or estimate_expected_time_ms(question.get("question", ""), question.get("options"))
            )
            response_ms = float(answer.get("response_time_ms", 0.0) or 0.0)
            hints = int(answer.get("hints_used", 0) or 0)
            tries = max(1, int(answer.get("tries", 1) or 1))

            misconception_id = None
            if not correct and chosen is not None:
                mapping = question.get("misconceptions") or {}
                misconception_id = mapping.get(str(chosen))

            attempt = Attempt(
                player_id=session.player_id,
                concept=concept,
                question_id=str(question.get("id")),
                correct=correct,
                difficulty=int(question.get("difficulty") or 3),
                response_time_ms=response_ms,
                expected_time_ms=expected_ms,
                hints_used=hints,
                tries=tries,
                chosen=None if chosen is None else str(chosen),
                correct_answer=question.get("correct_answer"),
                misconception_id=misconception_id,
                domain=question.get("topic"),
                realm=self.graph.concept(concept).realm if self.graph.has_concept(concept) else None,
            )
            session.log.add(attempt)
            outcome = session.tracer.observe(attempt)
            detections = self.detector.detect(attempt, session.log, question)

            named = []
            for detection in detections:
                entry = detection.to_dict()
                misconception = get_misconception_catalog().get(detection.misconception_id)
                if misconception:
                    entry["name"] = misconception.name
                    entry["remedy"] = misconception.remedy
                named.append(entry)

            graded.append(
                {
                    "question_id": question.get("id"),
                    "concept": concept,
                    "concept_name": (
                        self.graph.concept(concept).name if self.graph.has_concept(concept) else concept
                    ),
                    "correct": correct,
                    "chosen": chosen,
                    "correct_answer": question.get("correct_answer"),
                    "explanation": question.get("explanation", ""),
                    "difficulty": attempt.difficulty,
                    "mastery_before": outcome.mastery_before,
                    "mastery_after": outcome.mastery_after,
                    "confidence_after": outcome.confidence_after,
                    "is_fast_error": outcome.is_fast_error,
                    "time_ratio": round(attempt.time_ratio, 3),
                    "misconceptions": named,
                }
            )
        return graded

    def _public_question(self, question: dict) -> dict:
        """Never send the answer key to the client."""
        return {
            "id": question.get("id"),
            "question": question.get("question"),
            "options": list(question.get("options") or []),
            "concept": question.get("concept"),
            "concept_name": (
                self.graph.concept(question["concept"]).name
                if question.get("concept") and self.graph.has_concept(question["concept"])
                else question.get("concept")
            ),
            "topic": question.get("topic"),
            "difficulty": question.get("difficulty"),
            "hint": question.get("hint", ""),
        }

    # ------------------------------------------------------------------
    # Silver Mountain
    # ------------------------------------------------------------------
    def silver_status(self, player_id: str, realm: Optional[str] = None) -> dict:
        session = self.get_session(player_id)
        realm_id = self._resolve_realm(session, realm)
        realm_session = session.realm_session(realm_id)
        return self.mountain.status(
            self._campaign(realm_id), realm_session.progress, realm_session.silver
        )

    def silver_challenge(self, player_id: str, realm: Optional[str] = None) -> dict:
        session = self.get_session(player_id)
        realm_id = self._resolve_realm(session, realm)
        realm_session = session.realm_session(realm_id)
        campaign = self._campaign(realm_id)

        status = self.mountain.status(campaign, realm_session.progress, realm_session.silver)
        if not status["can_challenge"]:
            return {"granted": False, "status": status, "questions": []}

        profile = KnowledgeProfile(
            player_id, realm_id, session.tracer, session.log, self.graph, self.detector
        )
        slots = self.mountain.assemble_exam(profile, realm_id)

        questions: List[dict] = []
        used: List[str] = session.recent_question_ids[-60:]
        rng = random.Random()
        for slot in slots:
            picked, _ = self.bank.select(
                concepts=[slot.concept],
                count=1,
                target_difficulty={slot.concept: slot.difficulty},
                exclude_ids=used + [q["id"] for q in questions],
                rng=rng,
            )
            if picked:
                questions.extend(picked)

        session.recent_question_ids = ([q["id"] for q in questions] + session.recent_question_ids)[:200]
        return {
            "granted": True,
            "status": status,
            "exam": {
                "questions": EXAM_QUESTIONS,
                "pass_ratio": EXAM_PASS_RATIO,
                "required_correct": int(EXAM_QUESTIONS * EXAM_PASS_RATIO + 0.999),
            },
            "slots": [slot.to_dict() for slot in slots],
            "questions": [self._public_question(q) for q in questions],
            "archivist": [
                "You have collected knowledge. But knowledge collected is not knowledge mastered.",
                "I will ask you about the things you are worst at, and about the things you think you are best at.",
                "Begin.",
            ],
        }

    def silver_submit(self, player_id: str, realm: Optional[str], answers: Sequence[dict]) -> dict:
        session = self.get_session(player_id)
        realm_id = self._resolve_realm(session, realm)
        realm_session = session.realm_session(realm_id)
        campaign = self._campaign(realm_id)

        status = self.mountain.status(campaign, realm_session.progress, realm_session.silver)
        if not status["can_challenge"] and not status["cleared"]:
            return {"graded": False, "status": status, "reason": status["reason"]}

        graded = self._grade_answers(session, answers)
        total = len(graded) or 1
        correct = sum(1 for item in graded if item["correct"])
        ratio = correct / total
        passed = ratio >= EXAM_PASS_RATIO

        profile = KnowledgeProfile(
            player_id, realm_id, session.tracer, session.log, self.graph, self.detector
        )
        result = self.mountain.record_attempt(
            realm_session.silver, passed, ratio, profile
        )

        if result["passed"]:
            realm_session.progress.completed = True
            session.last_save = {
                "realm": realm_id,
                "milestone_index": len(campaign.milestones),
                "place": "Silver Mountain",
                "saved_at": time.time(),
            }
        elif result.get("return_to_save"):
            # Sent back to the last save point, exactly as the vision describes.
            session.last_save = session.last_save or self._default_save(realm_id)

        self.persist(session)
        return {
            "graded": True,
            "result": result,
            "correct": correct,
            "total": total,
            "answers": graded,
            "status": self.mountain.status(campaign, realm_session.progress, realm_session.silver),
            "profile": self.profile(player_id, realm_id),
            "return_to_save": bool(result.get("return_to_save")),
            "save_point": session.last_save,
        }

    def concept_coverage(self) -> dict:
        """Questions available per concept, with the concepts that fall short."""
        coverage = {concept.id: len(self.bank.for_concept(concept.id)) for concept in self.graph}
        gaps = sorted((c for c, n in coverage.items() if n < 6), key=lambda c: coverage[c])
        return {
            "questions": self.bank.size,
            "loaded_from": self.bank.loaded_from,
            "concepts": len(self.graph),
            "coverage": coverage,
            "concepts_below_target": [{"concept": c, "questions": coverage[c]} for c in gaps],
        }

    def recap(self, player_id: str, realm: Optional[str] = None) -> dict:
        """The personalised Mastery Recap shown at the save point after failing."""
        session = self.get_session(player_id)
        realm_id = self._resolve_realm(session, realm)
        profile = KnowledgeProfile(
            player_id, realm_id, session.tracer, session.log, self.graph, self.detector
        )
        realm_session = session.realm_session(realm_id)
        stored = realm_session.silver.last_recap
        steps = stored if stored else self.mountain.build_recap(profile)
        return {
            "realm": realm_id,
            "steps": [step.to_dict() for step in steps],
            "summary": self._recap_summary(profile),
            "cooldown_until": realm_session.silver.cooldown_until,
            "cooldown_hours": COOLDOWN_HOURS,
            "attempts_remaining": realm_session.silver.attempts_remaining,
            "attempts_total": ATTEMPTS_PER_WINDOW,
        }

    def _recap_summary(self, profile: KnowledgeProfile) -> str:
        weak = profile.weak_concepts(threshold=65.0, limit=3)
        plan = profile.misconception_plan(limit=1)
        parts: List[str] = []
        if weak:
            parts.append(
                "You struggled with " + ", ".join(view.name.lower() for view in weak) + "."
            )
        if plan:
            parts.append(f"And you kept {plan[0]['name'].lower()}.")
        if not parts:
            parts.append("Your knowledge is broadly sound; the summit tested your stamina.")
        return " ".join(parts)

    # ------------------------------------------------------------------
    def save_point(self, player_id: str, realm: Optional[str], index: int, place: str = "") -> dict:
        session = self.get_session(player_id)
        realm_id = self._resolve_realm(session, realm)
        campaign = self._campaign(realm_id)
        milestone = campaign.milestone(max(1, min(len(campaign.milestones), int(index))))
        session.last_save = {
            "realm": realm_id,
            "milestone_index": milestone.index,
            "place": place or milestone.place,
            "saved_at": time.time(),
        }
        self.persist(session)
        return dict(session.last_save)

    def saves(self) -> List[dict]:
        return [summary.to_dict() for summary in self.store.list_saves()]


_SERVICE: Optional[StoryService] = None


def get_story_service() -> StoryService:
    global _SERVICE
    if _SERVICE is None:
        _SERVICE = StoryService()
    return _SERVICE
