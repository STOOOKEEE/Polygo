"""Shared rules for the exercise kinds beyond choice, word order and fill-in.

`matching`, `dictation`, `toneDiscrimination`, `translation`,
`conversationChoice` and `dialogueOrder` are built by `exercise_expansion` and
checked by `content_tool`. The tone helpers live here because both the builder
and the linter must agree on what a tone pattern is and how it is spelled.
"""
from __future__ import annotations

import random
from typing import Any

NEW_KINDS = ("matching", "dictation", "toneDiscrimination", "translation", "conversationChoice", "dialogueOrder")
# A daily lesson uses at least this many of the kinds above.
MIN_NEW_KINDS = 4
MATCHING_PAIRS = (4, 5)
DIALOGUE_ORDER_LINES = (2, 4)
CONVERSATION_REPLIES = 3
DICTATION_SCRIPTS = ("pinyin", "hanzi")

_TONE_OF_VOWEL = {
    **{char: 1 for char in "āēīōūǖ"},
    **{char: 2 for char in "áéíóúǘ"},
    **{char: 3 for char in "ǎěǐǒǔǚ"},
    **{char: 4 for char in "àèìòùǜ"},
}
_TONE_NAMES = {
    1: "ton 1 ¯ (haut et plat)",
    2: "ton 2 ˊ (montant)",
    3: "ton 3 ˇ (descend puis remonte)",
    4: "ton 4 ˋ (descendant)",
    0: "ton neutre (léger et court)",
}
_TONE_SHORT = {1: "ton 1 ¯", 2: "ton 2 ˊ", 3: "ton 3 ˇ", 4: "ton 4 ˋ", 0: "ton neutre"}
# Characters with several common readings: a text-to-speech voice may pick a
# reading other than the catalogue's, so their tones cannot be asked.
_POLYPHONES = set("了长行得地重为还觉乐没少数相应教种空便更差朝调着只干发分间量处传假背的和几")


def pinyin_tones(syllables: list[str]) -> list[int]:
    """The tone of each pinyin syllable written with diacritics (0 when unmarked)."""
    return [next((_TONE_OF_VOWEL[char] for char in syllable.lower() if char in _TONE_OF_VOWEL), 0) for syllable in syllables]


def entry_tones(entry: dict[str, Any]) -> list[int] | None:
    """Tones of a vocabulary row that a listener can tell apart, else None.

    A row qualifies when its authored `toneNumbers` agree with the diacritics
    of its pinyin, it has one or two syllables, and its citation tones are what
    a speaker actually says: the third-tone sandhi (3-3 is spoken 2-3), and the
    changing tones of 不 and 一, and the polyphonic characters, are left out, as
    is a lone neutral syllable.
    """
    hanzi, tones = entry.get("hanzi"), entry.get("toneNumbers")
    pinyin = entry.get("pinyin")
    if not isinstance(hanzi, str) or not isinstance(pinyin, str) or not isinstance(tones, list):
        return None
    if not tones or len(tones) > 2 or any(not isinstance(tone, int) or not 0 <= tone <= 4 for tone in tones):
        return None
    syllables = pinyin.split()
    if len(hanzi) != len(tones) or len(syllables) != len(tones) or pinyin_tones(syllables) != tones:
        return None
    if tones[0] == 0 or "不" in hanzi or "一" in hanzi or _POLYPHONES.intersection(hanzi):
        return None
    if any(left == right == 3 for left, right in zip(tones, tones[1:])):
        return None
    return list(tones)


def tone_choice_id(tones: list[int]) -> str:
    """`t4` for a falling syllable, `t42` for a falling then rising word."""
    return "t" + "".join(str(tone) for tone in tones)


def tone_label(tones: list[int]) -> str:
    if len(tones) == 1:
        return _TONE_NAMES[tones[0]].capitalize()
    return " puis ".join(_TONE_SHORT[tone] for tone in tones).capitalize()


def tone_options(tones: list[int], rng: random.Random) -> list[list[int]]:
    """The correct pattern and three others, ordered by tone digits.

    One syllable offers the four tones. Two syllables offer the patterns that
    differ from the answer by one syllable first, then by two; patterns that
    end in 3-3 are never offered because they sound like 2-3.
    """
    if len(tones) == 1:
        return [[tone] for tone in range(1, 5)]
    patterns = [[first, second] for first in range(1, 5) for second in range(5) if [first, second] != tones and not first == second == 3]
    rng.shuffle(patterns)
    patterns.sort(key=lambda pattern: sum(left != right for left, right in zip(pattern, tones)))
    return sorted([tones] + patterns[:3])
