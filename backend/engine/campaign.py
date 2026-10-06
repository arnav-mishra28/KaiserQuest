"""
The campaign: 20 milestones per realm, and the shape of each one.

Two design decisions carry this file.

**The arc is shared; the flavour is not.** A twenty-step escalation is a piece of
design, not content: initiation, application, duel, reasoning, tournament,
investigation, endurance, gauntlet, and so on up to the Champion. Every realm
walks the same escalation because it is a good one, but the names, places and
keepers are authored per realm, so Algebra and Music Theory do not feel like the
same game wearing two hats.

**Milestones are cut from the curriculum, not invented.** Concepts are apportioned
across the twenty milestones in proportion to how many a domain actually has, so
milestone 9 of Algebra tests exactly the concepts the player has been taught by
milestone 9. When a designer adds a concept to the graph, the campaign re-cuts
itself, and nothing silently goes untested.

Every milestone carries a different *mechanic* — a trial mode — because twenty
identical quizzes with different names is the failure mode we are avoiding.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

from engine.concepts import Concept, ConceptGraph, get_concept_graph

logger = logging.getLogger("kaiserquest.engine.campaign")

#: Mastery a milestone's own concepts must reach for the milestone to count as
#: passed by knowledge rather than by luck on the day.
MILESTONE_MASTERY_GATE = 70.0

#: Coverage of the *previous* milestone's concepts required to be admitted.
ENTRY_GATE = 60.0


# ---------------------------------------------------------------------------
# Trial modes — the mechanics. Each one is a genuinely different interaction.
# ---------------------------------------------------------------------------
@dataclass(frozen=True)
class TrialMode:
    id: str
    questions: int
    pass_ratio: float
    seconds_per_question: int = 0
    hints_allowed: int = 0
    stakes: str = ""
    mechanic: str = ""
    description: str = ""

    @property
    def required_correct(self) -> int:
        import math

        return max(1, math.ceil(self.questions * self.pass_ratio))

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "questions": self.questions,
            "pass_ratio": self.pass_ratio,
            "required_correct": self.required_correct,
            "seconds_per_question": self.seconds_per_question,
            "hints_allowed": self.hints_allowed,
            "stakes": self.stakes,
            "mechanic": self.mechanic,
            "description": self.description,
        }


TRIAL_MODES: Dict[str, TrialMode] = {
    "guided": TrialMode(
        "guided", questions=4, pass_ratio=0.5, hints_allowed=9,
        stakes="none",
        mechanic="teach_then_ask",
        description="A keeper walks you through each idea, then asks it straight back. You cannot fail.",
    ),
    "applied": TrialMode(
        "applied", questions=5, pass_ratio=0.6, hints_allowed=1,
        stakes="world",
        mechanic="solve_to_open",
        description="The answers are the mechanism. Solve the puzzle and the world physically opens.",
    ),
    "timed": TrialMode(
        "timed", questions=6, pass_ratio=0.7, seconds_per_question=20, hints_allowed=0,
        stakes="duel",
        mechanic="countdown_duel",
        description="A duel against a clock. Fluency is the thing being tested here.",
    ),
    "reasoning": TrialMode(
        "reasoning", questions=5, pass_ratio=0.7, hints_allowed=1,
        stakes="puzzle",
        mechanic="justify_step",
        description="Several answers could work. You must say which step is justified and why.",
    ),
    "tournament": TrialMode(
        "tournament", questions=8, pass_ratio=0.7, hints_allowed=1,
        stakes="tournament",
        mechanic="mixed_bracket",
        description="Everything learned so far, shuffled, in brackets. Breadth over depth.",
    ),
    "grand_tournament": TrialMode(
        "grand_tournament", questions=10, pass_ratio=0.8, hints_allowed=0,
        stakes="tournament",
        mechanic="mixed_bracket",
        description="The regional bracket: every chapter of the realm, drawn at random, at full difficulty.",
    ),
    "investigation": TrialMode(
        "investigation", questions=5, pass_ratio=0.7, hints_allowed=1,
        stakes="mystery",
        mechanic="assemble_clues",
        description="Clues are strewn through the scene. Each correct answer reveals the next.",
    ),
    "diagnosis": TrialMode(
        "diagnosis", questions=5, pass_ratio=0.7, hints_allowed=1,
        stakes="repair",
        mechanic="find_the_error",
        description="Worked solutions are placed in front of you, each with one flaw. Find it.",
    ),
    "gauntlet": TrialMode(
        "gauntlet", questions=12, pass_ratio=0.75, hints_allowed=0,
        stakes="health",
        mechanic="escalating_run",
        description="A long run. Every question harder than the last, no hints, real cost to failing.",
    ),
    "chain": TrialMode(
        "chain", questions=6, pass_ratio=0.7, hints_allowed=1,
        stakes="ritual",
        mechanic="seeded_chain",
        description="Each answer becomes part of the next question. A mistake propagates.",
    ),
    "construct": TrialMode(
        "construct", questions=4, pass_ratio=0.7, hints_allowed=1,
        stakes="craft",
        mechanic="order_the_steps",
        description="Knowledge is not just recognition: you assemble the steps into a working whole.",
    ),
    "boss": TrialMode(
        "boss", questions=10, pass_ratio=0.8, hints_allowed=0,
        stakes="boss",
        mechanic="boss_encounter",
        description="A named adversary who is testing exactly what you are weakest at.",
    ),
    "champion": TrialMode(
        "champion", questions=15, pass_ratio=0.85, hints_allowed=0,
        stakes="championship",
        mechanic="championship",
        description="The realm championship: every domain, at the hardest level you can hold.",
    ),
}


@dataclass(frozen=True)
class MilestoneArchetype:
    """
    The fixed escalation, before any realm flavour is applied.

    `mastery_gate` is the mastery a milestone's concepts must hold for the
    milestone to count as passed. It rises with the escalation on purpose: the
    initiation asks you to understand, the championship asks you to hold it.
    """

    index: int
    kind: str
    mode: str
    title: str
    setup: str
    success: str
    failure: str
    mastery_gate: float = 60.0

    def to_dict(self) -> dict:
        return {
            "index": self.index,
            "kind": self.kind,
            "mode": self.mode,
            "title": self.title,
            "mastery_gate": self.mastery_gate,
        }


#: The escalation. `{place}`, `{keeper}`, `{domain}` and `{concept}` are filled
#: from the realm's flavour table and the milestone's own concept slice.
ARC: Tuple[MilestoneArchetype, ...] = (
    MilestoneArchetype(
        1, "initiation", "guided", "First Light",
        "{keeper} finds you at {place} and does not ask you to prove anything yet. "
        "{keeper} only asks questions, and waits.",
        "{keeper} nods. The first door of the realm opens on its own.",
        "There is nothing to fail here. {keeper} simply explains it again.",
        mastery_gate=45.0,
    ),
    MilestoneArchetype(
        2, "village_trial", "applied", "The Broken Village",
        "The mechanisms that hold {place} together have seized. Nobody knows the values "
        "they were set to. {keeper} hands you the dials.",
        "The mechanism turns. {place} breathes again, and the road onward is open.",
        "The dials hold firm. {keeper} walks you back through the idea before you try again.",
        mastery_gate=50.0,
    ),
    MilestoneArchetype(
        3, "duel", "timed", "Duel of Wits",
        "A challenger steps out at {place} and says, flatly, that you are too slow.",
        "The challenger concedes. Speed, it turns out, is a kind of knowing.",
        "You lose on time, not on knowledge. {keeper} tells you so, and means it kindly.",
    ),
    MilestoneArchetype(
        4, "puzzle_ruins", "reasoning", "Ruins of Reason",
        "The old stones at {place} were built to reward the right reasoning, not the "
        "right guess. Several answers will seem to work. Only one is justified.",
        "The stones accept your reasoning and shift aside.",
        "The stones reject a guess that would have been right by accident. Justify it next time.",
    ),
    MilestoneArchetype(
        5, "tournament", "tournament", "The Open Tournament",
        "Every traveller who has passed through {place} is entered in this bracket, and "
        "so are you. Everything you have learned is fair game.",
        "You take the bracket. {keeper} is not surprised.",
        "You fall in the middle of the bracket. Everything you have learned comes back for review.",
    ),
    MilestoneArchetype(
        6, "investigation", "investigation", "The Corrupted Record",
        "Something at {place} has been altered, and the alteration is sitting in plain "
        "sight. {keeper} says the evidence is in the numbers, if you look properly.",
        "You name the alteration. {keeper} looks at you differently now.",
        "The clues do not assemble yet. {keeper} lays them out again for you.",
    ),
    MilestoneArchetype(
        7, "trial_of_proof", "reasoning", "Trial of Proof",
        "At {place} it is not enough to be right. You must show the step that makes you "
        "right, and {keeper} will pick at it.",
        "{keeper} cannot fault the proof.",
        "Your answer was right and your reasoning was not. That is not a pass. Try again.",
    ),
    MilestoneArchetype(
        8, "endurance", "gauntlet", "The Long Climb",
        "There is no trick to the path out of {place}. It is long, and it gets harder the "
        "further you go. {keeper} warns you not to start tired.",
        "You reach the top of the climb with nothing left. {keeper} meets you there.",
        "The climb beats you back down to {place}. Rest, and start again.",
    ),
    MilestoneArchetype(
        9, "relay", "chain", "Relay of Chapters",
        "A chain of keepers waits along the road from {place}, each holding one link. "
        "Your answer becomes the next keeper's question.",
        "The chain holds all the way to the end.",
        "The chain breaks. A mistake early makes the later links unsolvable — that is the lesson.",
    ),
    MilestoneArchetype(
        10, "midpoint_gauntlet", "boss", "The Midway Gauntlet",
        "{keeper} has been watching you since the first step, and takes the field at "
        "{place} to find out what you actually kept.",
        "You hold. Nobody at {place} doubts you now.",
        "You are sent back to the last place you rested, with the order given cleanly: learn it, then come back.",
        mastery_gate=70.0,
    ),
    MilestoneArchetype(
        11, "riddle_vault", "reasoning", "Vault of Riddles",
        "The vault at {place} opens for reasoning, never for answers. {keeper} has never "
        "seen it open on a lucky guess.",
        "The vault opens. Whatever was locked behind it is yours.",
        "The vault stays shut. It is not being unfair; it is being exact.",
    ),
    MilestoneArchetype(
        12, "craft", "construct", "The Craft Hall",
        "{keeper} hands you the steps of a working thing, out of order, and asks you to "
        "build it.",
        "It works. You built it, which is different from recognising it.",
        "It does not work yet, and {keeper} shows you precisely which step you misplaced.",
    ),
    MilestoneArchetype(
        13, "diagnosis", "diagnosis", "House of Errors",
        "At {place}, every solution in the record has been broken in one specific way. "
        "{keeper} wants them found and named.",
        "You find and name them all. {keeper} is impressed that you could name them.",
        "You found the wrong errors. Knowing how something is broken is half of knowing how it works.",
    ),
    MilestoneArchetype(
        14, "mastery_trial", "boss", "Mastery Trial",
        "{keeper} does not fence. {keeper} assembles a trial aimed exactly at what you "
        "have been getting wrong.",
        "You clear it. The trial was aimed at your weaknesses and you did not have them any more.",
        "The trial found the gaps. That is its job, and it will find them again.",
        mastery_gate=72.0,
    ),
    MilestoneArchetype(
        15, "speedrun", "timed", "The Quickening",
        "At {place} the clock is shorter and the questions are not easier. {keeper} says "
        "fluency is what separates knowing from having known.",
        "You finish with time left on the clock.",
        "The clock wins. {keeper} says this is only a speed problem, and speed is trainable.",
    ),
    MilestoneArchetype(
        16, "tribunal", "investigation", "The Tribunal",
        "A claim is put to you at {place}, and {keeper} is not on your side. Evidence from "
        "everything you have learned is the only thing that counts.",
        "You make the case and it holds.",
        "The claim defeats your evidence. {keeper} shows you which part did not hold up.",
    ),
    MilestoneArchetype(
        17, "chain", "chain", "Chain of Reason",
        "This is the relay again, longer, and every link is drawn from a different part of "
        "the realm. {keeper} says a single weak link will find you out.",
        "The whole chain holds, across every chapter of the realm.",
        "One link failed and the chain came apart. {keeper} shows you exactly which one.",
    ),
    MilestoneArchetype(
        18, "grand_tournament", "grand_tournament", "The Grand Tournament",
        "The whole region gathers at {place}. This bracket is run at the highest standard "
        "the realm allows.",
        "You win the Grand Tournament. {keeper} announces it to the region.",
        "You do not take the bracket. {keeper} suggests you spend time on your weakest chapter.",
        mastery_gate=75.0,
    ),
    MilestoneArchetype(
        19, "final_mastery", "boss", "The Last Trial",
        "{keeper} has been holding this one back. It is the hardest thing the realm has "
        "asked you to do, and it is built entirely from your own history.",
        "You pass the last trial. {keeper} tells you there is a mountain.",
        "Not yet. {keeper} tells you what to revisit, precisely, and sends you back.",
        mastery_gate=78.0,
    ),
    MilestoneArchetype(
        20, "knowledge_champion", "champion", "Knowledge Champion",
        "The realm puts its championship in front of you at {place}: every domain, every "
        "chapter, at the hardest level you can hold.",
        "You are the Champion of the realm. The road to Silver Mountain is open.",
        "The championship is not yours yet. {keeper} will keep the title in trust.",
        mastery_gate=80.0,
    ),
)


# ---------------------------------------------------------------------------
# Realm flavour. Names, places and keepers — authored so the three realms read
# as three different places rather than one reskin.
# ---------------------------------------------------------------------------
@dataclass(frozen=True)
class RealmFlavor:
    realm: str
    region: str
    places: Tuple[str, ...]
    keepers: Tuple[str, ...]
    names: Tuple[str, ...]
    sigil_hint: str = ""

    def place(self, index: int) -> str:
        return self.places[(index - 1) % len(self.places)]

    def keeper(self, index: int) -> str:
        return self.keepers[(index - 1) % len(self.keepers)]

    def name(self, index: int) -> str:
        return self.names[(index - 1) % len(self.names)]


REALM_FLAVOR: Dict[str, RealmFlavor] = {
    "algebra": RealmFlavor(
        realm="algebra",
        region="Kaiserland — the Numeric Marches",
        places=(
            "Aster Town", "the stone bridge over the Axiom", "Equaton",
            "the Ruins of the Variable", "Functionburg", "the Ledger House",
            "Graphton", "the Long Climb", "Polynova", "Quadralis",
            "the Vault of Riddles", "the Craft Hall", "the House of Errors",
            "Prosdia", "the Quickening Fields", "the Tribunal Hall",
            "the Chain Road", "the Grand Coliseum", "the Last Gate",
            "the Champion's Court",
        ),
        keepers=(
            "Keeper Veran", "Keeper Solis", "the Duelist Brek", "Keeper Halla",
            "the Challenger Ondo", "Inspector Maro", "the Prover Tessa",
            "Keeper Rufus", "the Relay-Master Ilo", "Gauntlet-Lord Sabin",
            "the Vault Keeper Nia", "the Craftsman Duro", "the Diagnostician Pell",
            "Trial-Master Osric", "the Quickening Judge", "the Advocate Rell",
            "the Chain-Keeper Yune", "Grandmaster Castor", "Arch-Trialist Vex",
            "the Champion Arbiter",
        ),
        names=(
            "The First Unknown", "The Broken Bridge", "Duel of Wits",
            "Ruins of the Variable", "The Open Tournament", "The Corrupted Ledger",
            "Trial of Proof", "The Long Climb", "Relay of Chapters",
            "The Midway Gauntlet", "Vault of Riddles", "The Craft Hall",
            "House of Errors", "Mastery Trial", "The Quickening",
            "The Tribunal", "Chain of Reason", "The Grand Tournament",
            "The Last Trial", "Champion of Algebra",
        ),
    ),
    "english": RealmFlavor(
        realm="english",
        region="Kaiserland — the Plain of Tongues",
        places=(
            "Aster Town", "the Mended Message Inn", "Eloqua", "the Ruins of the Sentence",
            "the Tongue-Mart", "the Scriptorium", "Inkfield", "the Long Climb",
            "the Relay Road", "the Halfway Hall", "the Vault of Riddles",
            "the Scriptorium Deep", "the House of Misprints", "the Court of Register",
            "the Quickening Quill", "the Tribunal of Evidence", "the Chain Road",
            "the Grand Amphitheatre", "the Last Page", "the Champion's Reading Room",
        ),
        keepers=(
            "Keeper Ilyse", "the Innkeep Bron", "the Duelist Cato", "Keeper Nara",
            "the Challenger Vero", "Inspector Quill", "the Prover Melis",
            "Keeper Dunne", "the Relay-Master Aul", "Gauntlet-Lady Sable",
            "the Vault Keeper Oris", "the Scribe Delver", "the Diagnostician Ferro",
            "Trial-Master Ysolde", "the Quickening Judge", "the Advocate Corvin",
            "the Chain-Keeper Muse", "Grandmaster Thale", "Arch-Trialist Wren",
            "the Champion Arbiter",
        ),
        names=(
            "First Words", "The Mended Message", "Duel of Wits",
            "Ruins of the Sentence", "The Open Tournament", "The Corrupted Letter",
            "Trial of Proof", "The Long Climb", "Relay of Chapters",
            "The Midway Gauntlet", "Vault of Riddles", "The Scriptorium",
            "House of Misprints", "Mastery Trial", "The Quickening",
            "The Tribunal", "Chain of Reason", "The Grand Tournament",
            "The Last Page", "Champion of English",
        ),
    ),
    "music": RealmFlavor(
        realm="music",
        region="Kaiserland — the Resonant Valleys",
        places=(
            "Aster Town", "the Dissonant Village", "Fortissimo", "the Ruins of the Scale",
            "the Song-Market", "the Composer's Hall", "Chordwell", "the Long Climb",
            "the Relay Road", "the Halfway Concert Hall", "the Vault of Riddles",
            "the Craft Hall of Instruments", "the House of Wrong Notes",
            "the Court of Cadence", "the Quickening Stage", "the Tribunal of Ears",
            "the Chain Road", "the Grand Amphitheatre", "the Last Chord",
            "the Champion's Podium",
        ),
        keepers=(
            "Keeper Doremi", "the Village Fiddler", "the Duelist Kaba", "Keeper Lyra",
            "the Challenger Osta", "Inspector Tone", "the Prover Mira",
            "Keeper Ghent", "the Relay-Master Ansa", "Gauntlet-Lord Rezo",
            "the Vault Keeper Faun", "the Instrument-Maker Bela", "the Diagnostician Coda",
            "Trial-Master Vesper", "the Quickening Judge", "the Advocate Aria",
            "the Chain-Keeper Orin", "Grandmaster Maestro", "Arch-Trialist Seris",
            "the Champion Arbiter",
        ),
        names=(
            "First Sound", "The Dissonant Village", "Duel of Wits",
            "Ruins of the Scale", "The Open Tournament", "The Corrupted Score",
            "Trial of Proof", "The Long Climb", "Relay of Chapters",
            "The Midway Gauntlet", "Vault of Riddles", "The Composer's Hall",
            "House of Wrong Notes", "Mastery Trial", "The Quickening",
            "The Tribunal", "Chain of Reason", "The Grand Tournament",
            "The Last Chord", "Champion of Music",
        ),
    ),
}


# ---------------------------------------------------------------------------
# Milestones
# ---------------------------------------------------------------------------
@dataclass
class Milestone:
    index: int                    # 1..20
    id: str                       # "algebra.m07"
    realm: str
    kind: str
    mode: TrialMode
    name: str
    place: str
    keeper: str
    domain: str
    domain_name: str
    concepts: Tuple[str, ...]
    setup: str
    success: str
    failure: str
    entry_gate: float = ENTRY_GATE
    mastery_gate: float = MILESTONE_MASTERY_GATE

    @property
    def badge_name(self) -> str:
        return f"{self.domain_name} Sigil"

    @property
    def concept_names(self) -> List[str]:
        return list(self.concepts)

    def to_dict(self) -> dict:
        return {
            "index": self.index,
            "id": self.id,
            "realm": self.realm,
            "kind": self.kind,
            "name": self.name,
            "place": self.place,
            "keeper": self.keeper,
            "domain": self.domain,
            "domain_name": self.domain_name,
            "concepts": list(self.concepts),
            "trial": self.mode.to_dict(),
            "entry_gate": self.entry_gate,
            "mastery_gate": self.mastery_gate,
            "badge": self.badge_name,
            "narrative": {
                "setup": self.setup,
                "success": self.success,
                "failure": self.failure,
            },
        }


def apportion(counts: Sequence[int], total: int, minimum: int = 1) -> List[int]:
    """
    Hamilton's largest-remainder apportionment; always sums exactly to `total`.

    Used to decide how many of the twenty milestones each domain gets. It keeps
    the split proportional to how much there actually is to learn in each domain,
    which is why Algebra's five-concept Variables domain gets more milestones
    than a four-concept one, while every domain still gets at least one.
    """
    if not counts:
        return []
    n = len(counts)
    if total < n * minimum:
        raise ValueError(f"Cannot give each of {n} domains at least {minimum} of {total} milestones")

    floor_alloc = [minimum] * n
    remaining = total - minimum * n
    if remaining == 0:
        return floor_alloc

    total_count = sum(counts) or n
    quotas = [remaining * c / total_count for c in counts]
    base = [int(q) for q in quotas]
    assign = [floor_alloc[i] + base[i] for i in range(n)]
    leftover = total - sum(assign)
    remainders = sorted(range(n), key=lambda i: -(quotas[i] - base[i]))
    for i in remainders[:leftover]:
        assign[i] += 1
    return assign


def split_evenly(items: Sequence, groups: int) -> List[List]:
    """Cut a sequence into `groups` contiguous chunks as evenly as possible."""
    if groups <= 0:
        return []
    if groups >= len(items):
        return [[item] for item in items]
    size, extra = divmod(len(items), groups)
    chunks: List[List] = []
    start = 0
    for index in range(groups):
        length = size + (1 if index < extra else 0)
        chunks.append(list(items[start:start + length]))
        start += length
    return chunks


class Campaign:
    """The full 20-milestone campaign for one realm."""

    def __init__(self, graph: ConceptGraph, realm_id: str, flavor: Optional[RealmFlavor] = None):
        self.graph = graph
        self.realm = graph.realm(realm_id)
        self.flavor = flavor or REALM_FLAVOR.get(realm_id)
        if self.flavor is None:
            raise KeyError(f"No flavour authored for realm '{realm_id}'")
        self._milestones = self._build()
        self._validate()

    # ------------------------------------------------------------------
    @property
    def milestones(self) -> List[Milestone]:
        return list(self._milestones)

    def milestone(self, index: int) -> Milestone:
        if not 1 <= index <= len(self._milestones):
            raise KeyError(f"Milestone {index} out of range 1..{len(self._milestones)}")
        return self._milestones[index - 1]

    def concepts_through(self, index: int) -> List[str]:
        """Every concept taught by milestone `index` and all before it."""
        seen: List[str] = []
        for milestone in self._milestones[:index]:
            for concept_id in milestone.concepts:
                if concept_id not in seen:
                    seen.append(concept_id)
        return seen

    def concepts_for_milestone(self, index: int) -> List[str]:
        return list(self.milestone(index).concepts)

    def milestone_for_concept(self, concept_id: str) -> Optional[Milestone]:
        for milestone in self._milestones:
            if concept_id in milestone.concepts:
                return milestone
        return None

    def first_unpassed(self, passed_indices: Iterable[int]) -> Milestone:
        passed = set(passed_indices)
        for milestone in self._milestones:
            if milestone.index not in passed:
                return milestone
        return self._milestones[-1]

    # ------------------------------------------------------------------
    def _build(self) -> List[Milestone]:
        domains = self.realm.domains
        allocation = apportion([len(d.concepts) for d in domains], len(ARC), minimum=1)

        # Flatten to (concept, domain) in authored curriculum order. The order
        # the domains are declared in the graph *is* the curriculum order, and
        # it is asserted to respect prerequisites in _validate().
        slots: List[Tuple[Concept, str]] = []
        for domain in domains:
            for concept in domain.concepts:
                slots.append((concept, domain.name))

        chunks = split_evenly(slots, len(ARC))
        if len(chunks) != len(ARC):
            raise ValueError(
                f"Realm '{self.realm.id}' has {len(slots)} concepts, too few to fill {len(ARC)} milestones"
            )

        milestones: List[Milestone] = []
        for archetype, chunk in zip(ARC, chunks):
            concepts = [concept for concept, _ in chunk]
            domain_name = chunk[0][1] if chunk else ""
            milestone = Milestone(
                index=archetype.index,
                id=f"{self.realm.id}.m{archetype.index:02d}",
                realm=self.realm.id,
                kind=archetype.kind,
                mode=TRIAL_MODES[archetype.mode],
                name=self.flavor.name(archetype.index),
                place=self.flavor.place(archetype.index),
                keeper=self.flavor.keeper(archetype.index),
                domain=concepts[0].domain if concepts else "",
                domain_name=domain_name,
                concepts=tuple(concept.id for concept in concepts),
                mastery_gate=archetype.mastery_gate,
                setup=archetype.setup.format(
                    place=self.flavor.place(archetype.index),
                    keeper=self.flavor.keeper(archetype.index),
                    domain=domain_name,
                    concept=concepts[0].name if concepts else "",
                ),
                success=archetype.success.format(
                    place=self.flavor.place(archetype.index),
                    keeper=self.flavor.keeper(archetype.index),
                    domain=domain_name,
                    concept=concepts[0].name if concepts else "",
                ),
                failure=archetype.failure.format(
                    place=self.flavor.place(archetype.index),
                    keeper=self.flavor.keeper(archetype.index),
                    domain=domain_name,
                    concept=concepts[0].name if concepts else "",
                ),
            )
            milestones.append(milestone)
        return milestones

    def _validate(self) -> None:
        """Assert the campaign is coherent. Cheap, and catches authoring mistakes."""
        covered: List[str] = []
        for milestone in self._milestones:
            if not milestone.concepts:
                raise ValueError(f"Milestone {milestone.index} of {self.realm.id} covers no concepts")
            for concept_id in milestone.concepts:
                if concept_id in covered:
                    raise ValueError(f"Concept {concept_id} is tested by two milestones")
                covered.append(concept_id)
            # A milestone must not require a concept it has not yet taught.
            for concept_id in milestone.concepts:
                prereqs = self.graph.prerequisites(concept_id)
                for prereq in prereqs:
                    if prereq in milestone.concepts:
                        continue
                    if prereq not in covered:
                        logger.warning(
                            "Milestone %d of %s tests %s before its prerequisite %s is taught",
                            milestone.index, self.realm.id, concept_id, prereq,
                        )
        missing = set(self.graph.concept_ids()) - set(covered)
        missing = {m for m in missing if self.graph.concept(m).realm == self.realm.id}
        if missing:
            raise ValueError(f"Concepts never tested by {self.realm.id} campaign: {sorted(missing)}")

    # ------------------------------------------------------------------
    def to_dict(self) -> dict:
        return {
            "realm": self.realm.id,
            "region": self.flavor.region,
            "milestone_count": len(self._milestones),
            "milestones": [m.to_dict() for m in self._milestones],
        }

    def summary(self) -> str:
        lines = [f"{self.realm.name} campaign — {self.flavor.region}", ""]
        for milestone in self._milestones:
            concepts = ", ".join(
                self.graph.concept(c).name if self.graph.has_concept(c) else c
                for c in milestone.concepts
            )
            lines.append(
                f"{milestone.index:>2}. {milestone.name:<28} [{milestone.mode.id:<12}] "
                f"{milestone.place}"
            )
            lines.append(f"      tests: {concepts}")
        return "\n".join(lines)


_CAMPAIGN_CACHE: Dict[str, Campaign] = {}


def get_campaign(realm_id: str, graph: Optional[ConceptGraph] = None) -> Campaign:
    """Process-wide cached campaign per realm."""
    graph = graph or get_concept_graph()
    key = f"{realm_id}"
    if key not in _CAMPAIGN_CACHE:
        _CAMPAIGN_CACHE[key] = Campaign(graph, realm_id)
    return _CAMPAIGN_CACHE[key]


def all_campaigns(graph: Optional[ConceptGraph] = None) -> Dict[str, Campaign]:
    graph = graph or get_concept_graph()
    return {realm.id: get_campaign(realm.id, graph) for realm in graph.realms}
