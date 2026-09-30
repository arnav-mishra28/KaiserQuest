"""
Authored content for concepts that cannot be procedurally generated.

Algebra can be generated because a machine can solve it. "Which word is the noun
form of 'decide'?" cannot be generated, because correctness is a fact about
English rather than the output of a solver, and a model that confidently
invents plausible-but-wrong linguistic or musical facts is worse than no content
at all.

So these concepts are served from **authored item banks**: a small, hand-written
set of items whose answer key is stated rather than derived. The validator still
applies the full structural pass (unique options, answer present, concept
assigned), and the misconceptions attached elsewhere in the pipeline still
fire — but the correctness of the key rests on authorship, which for this kind of
content is the honest place for it to rest.

This module exists because the concept graph is a claim about what the game will
teach, and every concept in it must have questions behind it. A concept with no
questions makes a milestone unpassable.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, List, Sequence, Tuple


@dataclass(frozen=True)
class TemplateItem:
    question: str
    correct: str
    distractors: Tuple[str, ...]
    explanation: str


def item(question: str, correct: str, distractors: Sequence[str], explanation: str) -> TemplateItem:
    return TemplateItem(question, correct, tuple(distractors), explanation)


TEMPLATE_ITEMS: Dict[str, Tuple[TemplateItem, ...]] = {
    # ------------------------------------------------------------------
    # English: word forms
    # ------------------------------------------------------------------
    "forms.change": (
        item(
            "Choose the correct form: 'Her ___ of the plan was obvious.' (approve)",
            "approval", ("approve", "approving", "approved"),
            "The slot after 'her' needs a noun, so the verb 'approve' becomes the noun 'approval'.",
        ),
        item(
            "Choose the correct form: 'The scientist made an important ___.' (discover)",
            "discovery", ("discover", "discovering", "discoverable"),
            "'An important ___' needs a noun, and the noun from 'discover' is 'discovery'.",
        ),
        item(
            "Which word is the noun form of 'decide'?",
            "decision", ("decisive", "decided", "deciding"),
            "'Decision' is the noun; 'decisive' is the adjective and 'deciding' is a verb form.",
        ),
        item(
            "Which word is the adjective form of 'danger'?",
            "dangerous", ("dangerously", "dangerousness", "endanger"),
            "'Dangerous' describes a noun; 'dangerously' is the adverb.",
        ),
        item(
            "Which word is the adverb form of 'happy'?",
            "happily", ("happiness", "happier", "happiest"),
            "The adverb ends in -ly: 'happily'. 'Happiness' is the noun and 'happier' the comparative.",
        ),
        item(
            "Choose the correct form: 'The children played ___.' (noisy)",
            "noisily", ("noisy", "noise", "noisiness"),
            "The verb 'played' is modified by an adverb: 'noisily'.",
        ),
        item(
            "Which word is the noun form of 'arrive'?",
            "arrival", ("arrive", "arriving", "arrived"),
            "'Arrival' is the noun formed from the verb 'arrive'.",
        ),
        item(
            "Which word is the adjective form of 'success'?",
            "successful", ("successfully", "succeed", "succession"),
            "'Successful' is the adjective; 'successfully' is the adverb.",
        ),
    ),
    "forms.comparatives": (
        item(
            "Complete: 'This box is ___ than that one.' (heavy)",
            "heavier", ("heaviest", "more heavy", "heavy"),
            "Short adjectives ending in -y take -ier: heavy \u2192 heavier.",
        ),
        item("Which is the correct comparative of 'good'?",
             "better", ("gooder", "best", "more good"),
             "'Good' is irregular: good \u2192 better \u2192 best."),
        item("Which is the correct superlative of 'bad'?",
             "worst", ("baddest", "worse", "most bad"),
             "'Bad' is irregular: bad \u2192 worse \u2192 worst."),
        item(
            "Complete: 'She is the ___ student in the class.' (tall)",
            "tallest", ("taller", "most tall", "tall"),
            "'The ___ student in the class' is a superlative: tallest.",
        ),
        item("Which is the correct comparative of 'careful'?",
             "more careful", ("carefuller", "most careful", "carefulest"),
             "Longer adjectives take 'more' rather than -er."),
        item("Which is the correct superlative of 'far' when talking about distance?",
             "furthest", ("farther", "further", "most far"),
             "The superlative of 'far' is 'furthest' (or 'farthest'). 'Further' is the comparative."),
        item("Complete: 'My phone is ___ than yours.' (new)",
             "newer", ("newest", "more new", "new"),
             "Short adjectives take -er: new \u2192 newer."),
        item("Which is correct?",
             "the easiest", ("the most easy", "the easyest", "most easiest"),
             "'Easy' is short and ends in -y, so it takes -iest: the easiest."),
    ),
    "forms.irregular": (
        item("What is the plural of 'child'?",
             "children", ("childs", "childrens", "childes"),
             "'Child' has the irregular plural 'children'."),
        item("What is the plural of 'tooth'?",
             "teeth", ("tooths", "toothes", "teeths"),
             "'Tooth' becomes 'teeth', changing the vowel."),
        item("What is the past tense of 'go'?",
             "went", ("goed", "gone", "going"),
             "'Go' is irregular: go \u2192 went \u2192 gone."),
        item("What is the past participle of 'write'?",
             "written", ("wrote", "writed", "writing"),
             "'Write' is irregular: write \u2192 wrote \u2192 written."),
        item("What is the plural of 'mouse'?",
             "mice", ("mouses", "mices", "mouse"),
             "'Mouse' becomes 'mice'."),
        item("What is the past tense of 'take'?",
             "took", ("taked", "taken", "taking"),
             "'Take' is irregular: take \u2192 took \u2192 taken."),
        item("What is the comparative of 'far' when it means 'additional'?",
             "further", ("farther", "furthest", "more far"),
             "'Further' is used for additional amounts, 'farther' for physical distance."),
        item("What is the plural of 'woman'?",
             "women", ("womans", "womens", "womenses"),
             "'Woman' becomes 'women'."),
    ),
    "forms.derivation": (
        item("Which word belongs to the same family as 'nation'?",
             "national", ("native", "natural", "notion"),
             "'National' shares the root 'nation'. 'Native' and 'notion' look similar but are different words."),
        item("Which word belongs to the same family as 'music'?",
             "musician", ("muscle", "museum", "mystic"),
             "'Musician' is built from 'music' with the suffix -ian."),
        item("Which word is the person noun formed from 'create'?",
             "creator", ("creation", "creative", "creativity"),
             "The suffix -or forms the person noun: creator."),
        item("Which word is the person noun formed from 'science'?",
             "scientist", ("scientific", "scientifically", "science"),
             "The suffix -ist forms the person noun: scientist."),
        item("Which word is the adjective formed from 'nature'?",
             "natural", ("naturally", "naturism", "natured"),
             "'Natural' is the adjective; 'naturally' is the adverb."),
        item("Which word is the noun formed from 'produce'?",
             "production", ("productive", "productively", "producer"),
             "'Production' is the process noun; 'producer' is the person noun."),
        item("Which word is the adverb formed from 'gentle'?",
             "gently", ("gentleness", "gentler", "gentlest"),
             "Adjectives ending in -le form adverbs by replacing -e with -y: gentle \u2192 gently."),
        item("Which word means 'able to be read'?",
             "readable", ("reading", "reader", "readably"),
             "The suffix -able means 'able to be': readable."),
    ),
    # ------------------------------------------------------------------
    # English: reading and inference
    # ------------------------------------------------------------------
    "infer.main_idea": (
        item(
            "Ravi checked the sky, then packed an umbrella, a coat and a torch before setting out. "
            "The road ahead climbed into the mountains. What is this mainly about?",
            "Ravi preparing for a difficult journey",
            ("Ravi enjoying a walk", "Ravi buying equipment", "the weather in the mountains"),
            "Every detail is preparation for the climb ahead, not the trip itself.",
        ),
        item(
            "The library closes at six, but the lights often stay on until eight. Every evening the "
            "same three volunteers can be seen at the back tables. What is this mainly about?",
            "Volunteers keep the library open beyond its hours",
            ("The library is too small", "The volunteers dislike the library", "The library closes at eight"),
            "The closure time is six, so the detail that matters is who stays late and why.",
        ),
        item(
            "Bees do not only make honey. As they move from flower to flower they carry pollen that "
            "lets many plants produce fruit. What is this mainly about?",
            "The wider work bees do for plants",
            ("How honey is made", "Why bees sting", "Where flowers grow"),
            "The passage moves past honey to the pollen work, which is the point of 'not only'.",
        ),
        item(
            "The old bridge was closed for repairs, so the market traders took the longer road. "
            "Fewer customers came that week. What is this mainly about?",
            "How a closed bridge reduced trade at the market",
            ("Why bridges need repairs", "How markets are organised", "The best road to the market"),
            "The passage links a cause (the closed bridge) to an effect (fewer customers).",
        ),
        item(
            "Learning a language takes many short sessions, not one long one. Ten minutes a day beats "
            "three hours on a Sunday. What is this mainly about?",
            "Short regular practice works better than rare long practice",
            ("Languages are difficult", "Sunday is a good day to study", "Ten minutes is enough to learn a language"),
            "Both sentences compare frequent short practice with infrequent long practice.",
        ),
        item(
            "The river runs low in summer. Farmers along its banks take turns drawing water so that "
            "every field gets some. What is this mainly about?",
            "Farmers sharing scarce water",
            ("Why rivers run low", "Which crops need most water", "The size of the fields"),
            "The taking of turns is the central idea, and it exists because the water is scarce.",
        ),
    ),
    "infer.evidence": (
        item(
            "Claim: the house had been empty for a long time. Which detail best supports it?",
            "Dust lay thick on every windowsill and the gate hinges had rusted through.",
            ("The house is on a quiet road.", "The house has a red front door.", "The house was built of stone."),
            "Thick dust and rusted hinges take a long time to appear, which is exactly what the claim needs.",
        ),
        item(
            "Claim: the team practised hard. Which detail best supports it?",
            "They were on the pitch before sunrise every morning for six weeks.",
            ("They won most of their matches.", "They had a new coach.", "They played in blue shirts."),
            "Winning shows results, not practice. Sunrise sessions over six weeks shows the practice itself.",
        ),
        item(
            "Claim: the storm was severe. Which detail best supports it?",
            "Three trees in the avenue were uprooted and a roof tile lay in the street.",
            ("It rained for two hours.", "The forecast warned of wind.", "People stayed indoors."),
            "Uprooted trees are direct evidence of severity; a forecast is only a prediction.",
        ),
        item(
            "Claim: the shop is popular. Which detail best supports it?",
            "By noon on a Tuesday the queue stretched past two neighbouring doorways.",
            ("The shop is painted green.", "The shop opens at eight.", "The shop sells bread."),
            "A long queue on an ordinary weekday is evidence of demand.",
        ),
        item(
            "Claim: the puppy was tired. Which detail best supports it?",
            "It fell asleep in the middle of its own dinner bowl.",
            ("It is three months old.", "It has soft ears.", "It likes the garden."),
            "Falling asleep mid-meal is a direct sign of exhaustion.",
        ),
        item(
            "Claim: the road was steep. Which detail best supports it?",
            "Cyclists dismounted and pushed their bikes for the last kilometre.",
            ("The road was narrow.", "The road had no markings.", "The road ran beside a field."),
            "Pushing a bike uphill is a direct consequence of steepness.",
        ),
    ),
    "infer.implied": (
        item(
            "The lights were off and the door was locked. What is implied?",
            "No one was inside.",
            ("The building was for sale.", "Someone had forgotten the key.", "The building was empty of furniture."),
            "Dark and locked together point to nobody being there; the other answers add details the text does not give.",
        ),
        item(
            "She read the letter twice, then folded it without a word. What is implied?",
            "The letter troubled her.",
            ("She could not read it.", "She had written the letter.", "She wanted to keep it."),
            "Reading twice and staying silent suggests the news was upsetting.",
        ),
        item(
            "He put on his coat and picked up the umbrella from the stand. What is implied?",
            "He was about to go outside.",
            ("It was already raining.", "He had lost his keys.", "He was going to bed."),
            "The text shows preparation to leave. It does not state the weather outside.",
        ),
        item(
            "The kitchen smelled of bread and there were floury handprints on the table. What is implied?",
            "Someone had been baking.",
            ("Someone had been cleaning.", "The bread was bought.", "The kitchen was new."),
            "Bread smell plus flour is the trace of baking.",
        ),
        item(
            "The dog's bowl was full and the leash still hung on its hook. What is implied?",
            "The dog had not been walked.",
            ("The dog was hungry.", "The dog was asleep.", "The leash was broken."),
            "A full bowl and an unused leash imply the dog has not been taken out.",
        ),
        item(
            "Maya's phone showed nine missed calls from the same number. What is implied?",
            "Someone had been trying urgently to reach her.",
            ("She had lost her phone.", "The number was a stranger's.", "She had called nine people."),
            "Repeated calls from one number indicate urgency.",
        ),
    ),
    "infer.purpose": (
        item(
            "Why does an advertisement repeat the price three times?",
            "To make the low price the main point.",
            ("To fill the space.", "To hide the other details.", "To show the price may change."),
            "Repetition signals importance, and in an advertisement the repeated thing is the selling point.",
        ),
        item(
            "An author lists the dangers of a hiking trail in careful detail. Why?",
            "To warn readers to prepare properly.",
            ("To discourage anyone from going.", "To show off their knowledge.", "To describe the view."),
            "A detailed list of hazards serves preparation rather than prohibition.",
        ),
        item(
            "A writer describes a house as 'tidy, quiet and cold'. What is the attitude?",
            "Disapproving",
            ("Admiring", "Frightened", "Amused"),
            "'Cold' turns the tidiness negative, which shows disapproval rather than admiration.",
        ),
        item(
            "Why might an author begin an article with a question?",
            "To make the reader think about the problem.",
            ("To admit they do not know the answer.", "To summarise the article.", "To introduce a quotation."),
            "An opening question draws the reader into the problem the article will address.",
        ),
        item(
            "An article describes a factory worker's day in careful detail. What is the likely purpose?",
            "To help readers understand the working conditions.",
            ("To advertise the factory.", "To explain how to get a factory job.", "To describe the machinery only."),
            "Careful detail about a person's day is used to convey what the conditions are like.",
        ),
        item(
            "Why does an author mention their own childhood in an argument about schooling?",
            "To give a personal reason for their position.",
            ("To prove the argument is correct.", "To change the subject.", "To show they were a good student."),
            "A personal anecdote supplies motive. An anecdote alone cannot prove a claim.",
        ),
    ),
    # ------------------------------------------------------------------
    # Music: time signatures
    # ------------------------------------------------------------------
    "time.anacrusis": (
        item(
            "A piece begins with an incomplete measure before the first full bar. What is this called?",
            "An anacrusis (a pickup)",
            ("A coda", "A fermata", "A double bar"),
            "An incomplete opening measure is an anacrusis, also called a pickup bar.",
        ),
        item(
            "Another name for an anacrusis is ___.",
            "a pickup",
            ("a rest", "a repeat", "a tie"),
            "'Pickup' and 'anacrusis' mean the same thing.",
        ),
        item(
            "In 4/4 time a melody begins with one quarter note before the first full bar. "
            "How many beats does that opening bar contain?",
            "One beat",
            ("Four beats", "Two beats", "No beats"),
            "The first bar holds only what is played before the first full measure: one beat.",
        ),
        item(
            "In 3/4 time a melody starts on beat three. How many beats are missing from that first bar?",
            "Two",
            ("One", "Three", "None"),
            "The bar has three beats and only the third is played, so two are missing.",
        ),
        item(
            "Where is the missing count of a pickup bar usually found?",
            "In the last bar of the piece",
            ("In the second bar", "It is never played", "In the key signature"),
            "The opening and closing bars together make one complete measure.",
        ),
        item(
            "Why do pickups matter when counting a piece?",
            "Because the first bar is shorter, so the strong beats fall differently than you would expect.",
            (
                "Because they change the key signature.",
                "Because they add an extra beat to every bar.",
                "Because they are always played slowly.",
            ),
            "Counting that ignores a pickup puts every accent in the wrong place.",
        ),
    ),
    # ------------------------------------------------------------------
    # Music: composition
    # ------------------------------------------------------------------
    "comp.melody": (
        item("A melody that moves mostly by steps is described as ___.",
             "conjunct", ("disjunct", "chromatic", "syncopated"),
             "Stepwise movement is conjunct; movement by leaps is disjunct."),
        item("The notes C, D, E, F move in which direction?",
             "Ascending", ("Descending", "Static", "Unrelated"),
             "Each note is higher than the one before, so the movement ascends."),
        item("The shape of a melody over time is called its ___.",
             "contour", ("texture", "form", "cadence"),
             "Contour is the rising and falling shape; texture and form describe other things."),
        item("A melody that leaps between notes far apart is described as ___.",
             "disjunct", ("conjunct", "diatonic", "homophonic"),
             "Leaping movement is disjunct; stepwise movement is conjunct."),
        item("Which interval is a step?",
             "A major second", ("A major third", "A perfect fifth", "An octave"),
             "A second moves to the very next letter name, which is one step."),
        item("A melody built mostly on a single repeated note is said to be ___.",
             "static", ("melismatic", "sequential", "modulating"),
             "Very little pitch movement leaves the melody static."),
    ),
    "comp.harmony": (
        item("In C major, which chord most strongly leads back to the tonic?",
             "G major (V)", ("A minor (vi)", "F major (IV)", "E minor (iii)"),
             "The dominant, the chord on the fifth degree, is what creates the pull back to the tonic."),
        item("In C major, which chord is the dominant?",
             "G major", ("F major", "A minor", "D minor"),
             "The dominant is built on the fifth degree of the scale, which in C major is G."),
        item("In C major, which chord is built on the sixth degree?",
             "A minor", ("G major", "B diminished", "F major"),
             "Counting a sixth above C gives A, and the triad on A in C major is minor."),
        item("Which cadence ends on the dominant instead of the tonic?",
             "The half cadence", ("The perfect cadence", "The plagal cadence", "The interrupted cadence"),
             "A half cadence pauses on V, leaving the music open rather than closed."),
        item("A progression in C major moves I - IV - V - I. Which chord does it end on?",
             "C major", ("G major", "F major", "A minor"),
             "I is the tonic, which in C major is the C major chord."),
        item("In C major, which chord contains the notes C, E and G?",
             "C major", ("D minor", "E minor", "G major"),
             "Those three notes are the root, third and fifth of the C major triad."),
    ),
    "comp.form": (
        item("A piece whose structure is A B A is in ___ form.",
             "ternary", ("binary", "rondo", "strophic"),
             "Two different sections with a return is ternary form."),
        item("A piece with the structure A A B B is in ___ form.",
             "binary", ("ternary", "rondo", "sonata"),
             "Two sections, each repeated, is binary form."),
        item("A form built on a recurring refrain that alternates with episodes is a ___.",
             "rondo", ("fugue", "binary form", "theme and variations"),
             "The returning refrain and contrasting episodes make a rondo."),
        item("A melody is stated and then altered repeatedly. This form is called ___.",
             "theme and variations", ("binary form", "rondo", "ternary form"),
             "Restatement with changes is what 'theme and variations' means."),
        item("Which form is built from two contrasting sections?",
             "Binary", ("Ternary", "Rondo", "Sonata"),
             "'Binary' means two parts; ternary has three."),
        item("In ternary form, what happens after the B section?",
             "The A section returns", ("A new C section begins", "The piece ends", "The B section repeats"),
             "Ternary is A B A, so the opening section comes back."),
    ),
    "comp.texture": (
        item("A single unaccompanied melodic line is ___ in texture.",
             "monophonic", ("homophonic", "polyphonic", "heterophonic"),
             "One line alone is monophonic."),
        item("A melody supported by chords is ___ in texture.",
             "homophonic", ("monophonic", "polyphonic", "imitative"),
             "One melody with chordal accompaniment is homophonic."),
        item("Two or more independent melodies sounding at once is ___ texture.",
             "polyphonic", ("homophonic", "monophonic", "strophic"),
             "Several independent lines together make a polyphonic texture."),
        item("A round such as 'Fr\u00e8re Jacques' is an example of ___ texture.",
             "polyphonic", ("monophonic", "homophonic", "unison"),
             "The same melody sung in overlapping entries is polyphonic."),
        item("A solo flute playing alone creates which texture?",
             "Monophonic", ("Homophonic", "Polyphonic", "Chordal"),
             "A single unaccompanied instrument is monophonic."),
        item("A singer with a guitar playing chords underneath is which texture?",
             "Homophonic", ("Monophonic", "Polyphonic", "Contrapuntal"),
             "Melody plus chordal accompaniment is homophonic."),
    ),
}


def build_template_generators() -> Dict[str, object]:
    """
    Wrap each authored bank as a generator function compatible with the content
    generator's registry. Deliberately returns items unshuffled beyond the
    option order, so the option shuffle and misconception filtering in
    ContentGenerator._wrap still apply.
    """
    from engine.content.generator import GeneratorFn, GenContext  # local import: avoids a cycle

    generators: Dict[str, GeneratorFn] = {}

    def make(items: Tuple[TemplateItem, ...]) -> GeneratorFn:
        def generate(ctx: GenContext) -> dict:
            chosen = ctx.choice(items)
            return {
                "question": chosen.question,
                "correct_answer": chosen.correct,
                "distractors": list(chosen.distractors),
                "explanation": chosen.explanation,
            }

        return generate

    for concept_id, items in TEMPLATE_ITEMS.items():
        generators[concept_id] = make(items)
    return generators


def template_coverage() -> Dict[str, int]:
    return {concept: len(items) for concept, items in sorted(TEMPLATE_ITEMS.items())}
