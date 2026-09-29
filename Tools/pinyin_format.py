"""Pinyin as the learner reads it: syllables joined into words, ASCII punctuation, capitals.

Authoring files spell the reading of a text one syllable per hanzi (a grouped spelling is read
the same way), so that every reading stays checkable character by character. `spell` turns such
a reading into the written form of GB/T 16159 that every learner-facing pinyin of the bundle uses:

- the syllables of a word are joined (`chēzhàn`) and the words stand apart
  (`chēzhàn zài xuéxiào pángbiān`). A word is the longest reading the `Lexicon` knows (the
  catalogue, the lessons' vocabulary and `EXTRA_WORDS`; a few set phrases are cut into their
  words by `PHRASES`), a number (`shíwǔ`, `yìbǎi`), `第` with its number (`dì-yī`), or a single
  hanzi: the particles 的 了 吗 呢 吧 着 过 therefore stand apart, 们 joins its noun and a
  doubled hanzi joins its double (`kànkan`);
- inside a word, a syllable that starts with a, o or e takes an apostrophe (`Xī'ān`, `nǚ'ér`);
- ，、。？！：； and quotes become , , . ? ! : ; " with no space before a mark and one after it;
- a sentence starts with a capital, and so do proper nouns (`PROPER_NOUNS`) and the characters'
  names, which the hanzi text already writes in Latin letters (`Mina`).

The formatter reads only the hanzi and the syllables, never the spacing, case or marks of the
pinyin it is given: formatting a formatted text changes nothing, which is what lint checks.
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass
from functools import lru_cache
from typing import Any, Iterable, Mapping

INITIALS = ("zh", "ch", "sh", "b", "p", "m", "f", "d", "t", "n", "l", "g", "k", "h", "j", "q", "x", "z", "c", "s", "r", "y", "w")
FINALS = frozenset(
    "a o e ai ei ao ou an en ang eng ong er i ia ie iao iu ian in iang ing iong u ua uo uai ui uan un uang ue ü üe üan ün".split()
)
TONE_MARKS = {"\u0304", "\u0301", "\u030c", "\u0300"}
# Hanzi punctuation and the ASCII mark the pinyin writes for it.
PUNCTUATION = {
    "，": ",", "、": ",", "。": ".", "？": "?", "！": "!", "：": ":", "；": ";",
    ",": ",", ".": ".", "?": "?", "!": "!", ":": ":", ";": ";",
}
_OPENING_QUOTES = "“‘"
_CLOSING_QUOTES = "”’"
_SENTENCE_END = ".?!"

# Words the catalogue and the vocabulary lack, written as one word by GB/T 16159.
EXTRA_WORDS = frozenset(
    """
    你们 他们 她们 它们 咱们 这个 那个 哪个 这些 那些 哪些 这里 那里 哪里 这儿 那儿 哪儿 这样 那样 这么 那么
    没有 一下 一点 一点儿 有点儿 一些 回来 回去 出来 出去 进来 进去 起来 过来 下来 上来
    星期一 星期二 星期三 星期四 星期五 星期六 星期天 星期日 可是 火车 汽车 红茶 绿茶 好看 春天 夏天 秋天 冬天
    吃饭 答案 读书 走路 上课 下课 有点 坐下 做完 吃完 看完 读完 买完 写完 好玩 大学
    一月 二月 三月 四月 五月 六月 七月 八月 九月 十月 十一月 十二月
    """.split()
)
# Set phrases that a lexicon lists as one entry but that are written as several words.
PHRASES = {
    "你好": ("你", "好"),
    "不客气": ("不", "客气"),
    "没关系": ("没", "关系"),
    "打电话": ("打", "电话"),
    "打篮球": ("打", "篮球"),
    "踢足球": ("踢", "足球"),
    "公共汽车": ("公共", "汽车"),
    "电子邮件": ("电子", "邮件"),
}
# Words written with a capital wherever they stand: places, countries, languages, people.
PROPER_NOUNS = frozenset("中国 中国人 北京 法国 法国人 美国 汉语 中文 法语 英语 普通话 西安 安 林 白白".split())

_DIGITS = "一二三四五六七八九"
_NUMBER = re.compile(rf"[{_DIGITS}两][百千万]|[{_DIGITS}]?十[{_DIGITS}]?")
_HANZI = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff]")
_LETTERS = r"[^\W\d_]+(?:['’\-][^\W\d_]+)*"
_HANZI_TOKEN = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff]|[A-Za-z]+|\s+|.")
_PINYIN_TOKEN = re.compile(rf"{_LETTERS}|\s+|.")


class PinyinError(ValueError):
    """Pinyin that is no pinyin or does not read its hanzi; module 0 data that breaks its contract."""


# -- syllables ---------------------------------------------------------------------


def untoned(char: str) -> str:
    """The letter under a tone mark (`ǚ` gives `ü`)."""
    decomposed = "".join(part for part in unicodedata.normalize("NFD", char) if part not in TONE_MARKS)
    return unicodedata.normalize("NFC", decomposed)


@lru_cache(maxsize=None)
def _parse(plain: str, start: int) -> tuple[int, ...] | None:
    """Lengths of the syllables that spell the word `plain[start:]`, or None when it is no pinyin.

    Only the first syllable of a word may start with a vowel: inside a word, i, u and ü are
    written y and w, and a, o, e follow an apostrophe, which splits the word before parsing.
    """
    if start == len(plain):
        return ()
    initials = [initial for initial in INITIALS if plain.startswith(initial, start)] + ([""] if start == 0 else [])
    for initial in initials:
        after = start + len(initial)
        for size in range(min(5, len(plain) - after), 0, -1):
            if plain[after:after + size] in FINALS:
                rest = _parse(plain, after + size)
                if rest is not None:
                    return (len(initial) + size,) + rest
    return None


def syllables(pinyin: str) -> list[str]:
    """The syllables of a pinyin text: apart or grouped into words (`Hànyǔ`, `Xī'ān`, `dì-yī`)."""
    result: list[str] = []
    for chunk in re.split(r"[\s'’\-]+", pinyin.strip()):
        if not chunk:
            continue
        lengths = _parse("".join(untoned(char) for char in chunk.lower()), 0)
        if lengths is None:
            raise PinyinError(f"'{chunk}' is not valid pinyin")
        position = 0
        for length in lengths:
            result.append(chunk[position:position + length])
            position += length
    if not result:
        raise PinyinError("empty pinyin")
    return result


def _word_syllables(word: str) -> list[tuple[str, bool]]:
    """(syllable, erhua) for each syllable of a pinyin word; an erhua syllable ends in r (`diǎnr`)."""
    try:
        return [(syllable, False) for syllable in syllables(word)]
    except PinyinError:
        if len(word) > 1 and word.endswith("r"):
            parts = syllables(word[:-1])
            return [(syllable, False) for syllable in parts[:-1]] + [(parts[-1] + "r", True)]
        raise


def lenient_syllables(pinyin: str) -> list[str]:
    """The syllables of a pinyin text without its punctuation; a word that is no pinyin (a name,
    an erhua) stays whole."""
    result: list[str] = []
    for word in re.findall(_LETTERS, pinyin):
        try:
            result.extend(syllables(word))
        except PinyinError:
            result.append(word)
    return result


def reading_key(pinyin: str) -> str:
    """What a pinyin text says, whatever its spelling: lowercase syllables and ASCII marks."""
    parts: list[str] = []
    for token in _PINYIN_TOKEN.findall(pinyin):
        if token.isspace():
            continue
        if re.fullmatch(_LETTERS, token):
            try:
                parts.extend(syllable.lower() for syllable, _ in _word_syllables(token))
            except PinyinError:
                parts.append(token.lower())
        else:
            parts.append(PUNCTUATION.get(token, '"' if token in _OPENING_QUOTES + _CLOSING_QUOTES + "\"'" else token))
    return " ".join(parts)


# -- words -------------------------------------------------------------------------


class Lexicon:
    """The words the formatter knows: hanzi of two characters or more, each with the words it is
    written as (itself, or the parts of a set phrase)."""

    def __init__(self, words: Iterable[str]) -> None:
        self.entries: dict[str, tuple[str, ...]] = {word: (word,) for word in words if len(word) > 1}
        self.entries.update({word: (word,) for word in EXTRA_WORDS | PROPER_NOUNS if len(word) > 1})
        self.entries.update(PHRASES)


@dataclass(frozen=True)
class _Unit:
    """Hanzi that no word boundary may split, with their spelling: one hanzi, a hanzi and its
    erhua 儿, a number, or 第 and its number."""

    hanzi: str
    spelling: str


def _join(spellings: list[str]) -> str:
    """Spellings joined into one word, with an apostrophe before a, o or e."""
    word = spellings[0]
    for spelling in spellings[1:]:
        word += ("'" if untoned(spelling[0]).lower() in "aoe" else "") + spelling
    return word


def _numbers(units: list[_Unit]) -> list[_Unit]:
    """Units with each number of two hanzi or more merged into one, and 第 into its number."""
    merged: list[_Unit] = []
    index = 0
    while index < len(units):
        text = "".join(unit.hanzi for unit in units[index:])
        found = _NUMBER.match(text)
        if found and len(found.group()) > 1 and all(len(unit.hanzi) == 1 for unit in units[index:index + len(found.group())]):
            size = len(found.group())
            merged.append(_Unit(found.group(), _join([unit.spelling for unit in units[index:index + size]])))
            index += size
        else:
            merged.append(units[index])
            index += 1
    result: list[_Unit] = []
    for unit in merged:
        if result and result[-1].hanzi == "第" and unit.hanzi[0] in _DIGITS + "十两":
            result[-1] = _Unit("第" + unit.hanzi, f"{result[-1].spelling}-{unit.spelling}")
        else:
            result.append(unit)
    return result


def _split(piece: list[_Unit], parts: tuple[str, ...]) -> list[tuple[str, str]] | None:
    """(hanzi, spelling) of each part of a lexicon entry, or None when a part would cut a unit."""
    words: list[tuple[str, str]] = []
    position = 0
    for part in parts:
        taken: list[_Unit] = []
        while position < len(piece) and len("".join(unit.hanzi for unit in taken)) < len(part):
            taken.append(piece[position])
            position += 1
        if "".join(unit.hanzi for unit in taken) != part:
            return None
        words.append((part, _join([unit.spelling for unit in taken])))
    return words


def _words(units: list[_Unit], lexicon: Lexicon) -> list[tuple[str, str]]:
    """(hanzi, spelling) of each word of a run of units.

    The segmentation with the fewest words wins; between equals, the one whose last word is the
    longest (backward maximum matching: 有 意见, not 有意 见).
    """
    size = len(units)
    best: list[tuple[int, int] | None] = [(0, 0)] + [None] * size
    for end in range(1, size + 1):
        for start in range(end):
            text = "".join(unit.hanzi for unit in units[start:end])
            if end - start > 1 and text not in lexicon.entries:
                continue
            previous, current = best[start], best[end]
            if previous is not None and (current is None or previous[0] + 1 < current[0]):
                best[end] = (previous[0] + 1, start)
    cuts: list[tuple[int, int]] = []
    end = size
    while end:
        found = best[end]
        assert found is not None  # a single unit is always a word
        cuts.append((found[1], end))
        end = found[1]
    words: list[tuple[str, str]] = []
    for start, end in reversed(cuts):
        piece = units[start:end]
        text = "".join(unit.hanzi for unit in piece)
        # A phrase whose parts would cut an erhua or a number stays one word.
        words.extend(_split(piece, lexicon.entries.get(text, (text,))) or [(text, _join([unit.spelling for unit in piece]))])
    joined: list[tuple[str, str]] = []
    for hanzi, spelling in words:
        if joined and (hanzi == "们" or hanzi == joined[-1][0] and len(hanzi) == 1 and hanzi not in _DIGITS):
            joined[-1] = (joined[-1][0] + hanzi, joined[-1][1] + spelling)
        else:
            joined.append((hanzi, spelling))
    return [(hanzi, _capital(spelling) if hanzi in PROPER_NOUNS else spelling) for hanzi, spelling in joined]


def _capital(text: str) -> str:
    return text[:1].upper() + text[1:]


# -- texts -------------------------------------------------------------------------


def spell(hanzi: str, pinyin: str, lexicon: Lexicon, *, sentence: bool) -> str:
    """The written pinyin of `hanzi`, read by the syllables of `pinyin`.

    A `sentence` starts each of its sentences with a capital, the first one only when the text
    ends like a sentence (`。？！`): a word or a tile, or a drill of words, does not.
    """
    items: list[tuple[str, str]] = []
    for token in _HANZI_TOKEN.findall(hanzi):
        if token.isspace():
            continue
        if _HANZI.fullmatch(token):
            items.append(("h", token))
        elif token.isalpha():
            items.append(("n", token))
        elif token in PUNCTUATION or token in _OPENING_QUOTES + _CLOSING_QUOTES:
            items.append(("p", token))
        else:
            raise PinyinError(f"'{hanzi}': the hanzi text holds '{token}', which has no pinyin mark")
    names = {text for kind, text in items if kind == "n"}
    readings: list[tuple[str, str, bool]] = []
    for token in _PINYIN_TOKEN.findall(pinyin):
        if token.isspace() or token in PUNCTUATION or token in _OPENING_QUOTES + _CLOSING_QUOTES + "\"'":
            continue
        if not re.fullmatch(_LETTERS, token):
            raise PinyinError(f"'{pinyin}': '{token}' is not pinyin")
        if token in names:
            readings.append(("n", token, False))
        else:
            readings.extend(("s", syllable, erhua) for syllable, erhua in _word_syllables(token))

    tokens: list[tuple[str, str]] = []
    run: list[_Unit] = []

    def close_run() -> None:
        if run:
            tokens.extend(("w", spelling) for _, spelling in _words(_numbers(run), lexicon))
            run.clear()

    position = 0
    index = 0
    while index < len(items):
        kind, text = items[index]
        if kind == "p":
            close_run()
            tokens.append(("p", text))
            index += 1
            continue
        if position >= len(readings):
            raise PinyinError(f"'{hanzi}' / '{pinyin}': the pinyin has fewer syllables than the text")
        reading_kind, reading, erhua = readings[position]
        position += 1
        if kind == "n":
            if reading_kind != "n" or reading != text:
                raise PinyinError(f"'{hanzi}' / '{pinyin}': the name {text} is not where the pinyin has it")
            close_run()
            tokens.append(("n", text))
            index += 1
            continue
        if reading_kind != "s":
            raise PinyinError(f"'{hanzi}' / '{pinyin}': the name {reading} stands for a hanzi")
        if erhua:
            if index + 1 >= len(items) or items[index + 1] != ("h", "儿"):
                raise PinyinError(f"'{hanzi}' / '{pinyin}': the erhua '{reading}' is not followed by 儿")
            run.append(_Unit(text + "儿", reading.lower()))
            index += 2
        else:
            run.append(_Unit(text, reading.lower()))
            index += 1
    if position != len(readings):
        raise PinyinError(f"'{hanzi}' / '{pinyin}': the pinyin has more syllables than the text")
    close_run()
    return _assemble(tokens, sentence, bool(tokens) and tokens[-1][0] == "p" and PUNCTUATION.get(tokens[-1][1], ",") in _SENTENCE_END)


def _assemble(tokens: list[tuple[str, str]], sentence: bool, complete: bool) -> str:
    text = ""
    starts = sentence and complete
    after_opening = True
    for kind, value in tokens:
        if kind == "p":
            if value in _OPENING_QUOTES:
                text += ("" if after_opening else " ") + '"'
                after_opening = True
                continue
            text += '"' if value in _CLOSING_QUOTES else PUNCTUATION[value]
            starts = starts or (sentence and PUNCTUATION.get(value, ",") in _SENTENCE_END)
            after_opening = False
            continue
        text += ("" if after_opening else " ") + (_capital(value) if starts else value)
        starts = False
        after_opening = False
    return text


def spell_card(hanzi: str, pinyin: str, lexicon: Lexicon) -> str:
    """A card's pinyin, with its tone digits kept apart (`nǐ hǎo · 3-3`)."""
    reading, separator, tones = pinyin.partition(" · ")
    return spell(hanzi, reading, lexicon, sentence=False) + separator + tones


# -- prose -------------------------------------------------------------------------

_HANZI_THEN_READING = re.compile(r"([\u3400-\u4dbf\u4e00-\u9fff][\u3400-\u4dbf\u4e00-\u9fff，、。？！：；]*) \(([^()]+)\)")
_READING_THEN_HANZI = re.compile(rf"((?:{_LETTERS} )+)\(([\u3400-\u4dbf\u4e00-\u9fff]+)(?=[,)])")
_EXAMPLE_LINE = re.compile(r"Exemple \d+ : (.+)")
_TONED = re.compile("[āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜĀÁǍÀĒÉĚÈĪÍǏÌŌÓǑÒŪÚǓÙ]")


def _respell(hanzi: str, pinyin: str, lexicon: Lexicon, sentence: bool) -> str | None:
    """`pinyin` written as the reading of `hanzi`, or None when it is not that reading."""
    try:
        return spell(hanzi, pinyin, lexicon, sentence=sentence)
    except PinyinError:
        return None


def spell_prose(text: str, lexicon: Lexicon) -> str:
    """French prose with each reading it gives of a hanzi text written as a word: `学校 (xuéxiào)`,
    `xuéxiào (学校, école)`, and the pinyin line under each `Exemple N : …` of a grammar note."""
    lines = text.split("\n")
    for index, line in enumerate(lines[:-1]):
        example = _EXAMPLE_LINE.fullmatch(line)
        if example and _HANZI.search(example.group(1)):
            lines[index + 1] = _respell(example.group(1), lines[index + 1], lexicon, True) or lines[index + 1]
    text = "\n".join(lines)
    text = _HANZI_THEN_READING.sub(
        lambda match: f"{match.group(1)} ({_respell(match.group(1), match.group(2), lexicon, False) or match.group(2)})", text,
    )

    def before_hanzi(match: re.Match[str]) -> str:
        hanzi, words = match.group(2), match.group(1).split()
        wanted = len(hanzi)
        taken: list[str] = []
        count = 0
        while words and count < wanted:
            try:
                count += len(syllables(words[-1]))
            except PinyinError:
                break
            taken.insert(0, words.pop())
        spelled = _respell(hanzi, " ".join(taken), lexicon, False) if count == wanted and _TONED.search(" ".join(taken)) else None
        if spelled is None:
            return match.group()
        return "".join(word + " " for word in words) + spelled + " (" + hanzi

    return _READING_THEN_HANZI.sub(before_hanzi, text)


# -- lessons -----------------------------------------------------------------------


def format_lessons(lessons: Mapping[str, dict[str, Any]], lexicon: Lexicon) -> None:
    """Write every learner-facing pinyin of the lessons, in place.

    Each pinyin field is spelled from the hanzi it reads. A pinyin choice of a dictation carries
    no hanzi: it takes the spelling that the lessons give its reading (a word's or a sentence's,
    like the text it is asked of), else the spelling of the asked text's hanzi (the made-up
    syllables of a minimal pair). Prose, last, gets `spell_prose`.
    """
    readings: dict[bool, dict[str, set[str]]] = {False: {}, True: {}}

    def field(owner: Any, key: str, hanzi: Any, sentence: bool) -> None:
        value = owner.get(key) if isinstance(owner, dict) else None
        if not isinstance(value, str) or not value.strip() or not isinstance(hanzi, str):
            return
        spelled = spell(hanzi, value, lexicon, sentence=sentence)
        owner[key] = spelled
        for text in (value, spelled):
            readings[sentence].setdefault(reading_key(text), set()).add(spelled)

    for lesson in lessons.values():
        for entry in lesson.get("vocabulary", []):
            field(entry, "pinyin", entry.get("hanzi"), False)
            for segment in entry.get("segmentation", []):
                field(segment, "pinyin", segment.get("surface"), False)
            field(entry.get("example"), "pinyin", (entry.get("example") or {}).get("hanzi"), True)
            for note in entry.get("grammarNotes", []):
                for example in note.get("examples", []):
                    field(example, "pinyin", example.get("hanzi"), True)
        for card in lesson.get("cards", []):
            for side in (card.get("front"), card.get("back")):
                if isinstance(side, dict) and isinstance(side.get("pinyin"), str) and isinstance(side.get("hanzi"), str):
                    side["pinyin"] = spell_card(side["hanzi"], side["pinyin"], lexicon)
        carriers = lesson.get("metadata", {}).get("carriers")
        if isinstance(carriers, dict):
            for hanzi in carriers:
                field(carriers, hanzi, hanzi, False)
        for block in lesson.get("blocks", []):
            for line in block.get("lines", []):
                field(line, "pinyin", line.get("hanzi"), True)
            for paragraph in block.get("paragraphs", []):
                field(paragraph, "pinyin", paragraph.get("hanzi"), True)
                for segment in paragraph.get("segmentation", []):
                    field(segment, "pinyin", segment.get("surface"), False)
            spec = block.get("spec")
            if not isinstance(spec, dict):
                continue
            for token in spec.get("tokens", []):
                field(token, "pinyin", token.get("hanzi"), False)
            for pair in spec.get("pairs", []):
                # A pair without pinyin under its hanzi asks for that pinyin on its right side.
                if pair.get("pinyin") is None:
                    field(pair.get("right"), "fr", pair.get("left"), False)
                else:
                    field(pair, "pinyin", pair.get("left"), False)
            for item in spec.get("replies", []) + spec.get("lines", []):
                field(item, "pinyin", item.get("hanzi"), True)
            if isinstance(spec.get("referencePinyin"), str):
                _format_speaking(spec, lexicon)

    for lesson in lessons.values():
        words = {entry.get("hanzi") for entry in lesson.get("vocabulary", [])} | set(lesson.get("metadata", {}).get("carriers") or {})
        for block in lesson.get("blocks", []):
            spec = block.get("spec")
            if isinstance(spec, dict) and spec.get("kind") == "dictation" and spec.get("script") == "pinyin":
                sentence = spec.get("promptText") not in words
                for choice in spec.get("choices", []):
                    label = choice["label"]["fr"]
                    known = readings[sentence].get(reading_key(label), set())
                    if len(known) > 1:
                        raise PinyinError(f"{lesson.get('id')}: '{label}' is spelled {' and '.join(sorted(known))}")
                    choice["label"]["fr"] = next(iter(known)) if known else spell(spec["promptText"], label, lexicon, sentence=sentence)
        _format_prose(lesson, lexicon)


def _format_speaking(spec: dict[str, Any], lexicon: Lexicon) -> None:
    """The reference pinyin of a speaking exercise, and its prompt when it quotes that pinyin (`Dis à voix haute : …`)."""
    raw = spec["referencePinyin"]
    spelled = spell(spec["referenceText"], raw, lexicon, sentence=True)
    spec["referencePinyin"] = spelled
    prompt = spec.get("header", {}).get("prompt", {})
    quoted = re.fullmatch(r"(.* : )(.+?)([.?!]?)", prompt.get("fr", ""), re.DOTALL)
    if quoted and reading_key(quoted.group(2)) in {reading_key(raw), reading_key(spelled)} and _TONED.search(quoted.group(2)):
        prompt["fr"] = quoted.group(1) + spelled + ("" if spelled[-1:] in _SENTENCE_END else quoted.group(3))


def _format_prose(value: Any, lexicon: Lexicon) -> Any:
    if isinstance(value, dict):
        for key, item in value.items():
            value[key] = _format_prose(item, lexicon)
    elif isinstance(value, list):
        value[:] = [_format_prose(item, lexicon) for item in value]
    elif isinstance(value, str) and ("(" in value or "Exemple " in value):
        return spell_prose(value, lexicon)
    return value
