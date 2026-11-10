#!/usr/bin/env python3
"""Check the maintained radar/statistics dictionary.

Run with Python 3.9 or newer; no third-party packages are needed.
Pass --chars with a local Wanxiang character dictionary to check every reading.
Without --chars, check structure, spelling format, and technical phrase readings.
The checker only reads files and never deploys Rime.
"""

import argparse
from collections import Counter, defaultdict
from pathlib import Path
import re
import sys
import unicodedata

ROOT = Path(__file__).resolve().parents[1]
CATEGORY = re.compile(r"# \[([a-z_]+)\] (.+)")
PINYIN = re.compile(r"[a-züāáǎàōóǒòēéěèīíǐìūúǔùǖǘǚǜńňǹḿ]+")
HANZI = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff\U00020000-\U000323af]+")

# These readings depend on the technical meaning, not just individual characters.
CONTEXT_READINGS = {
    "相控": "xiàng kòng",
    "相位": "xiàng wèi",
    "相干": "xiāng gān",
    "调频": "tiáo pín",
    "调制": "tiáo zhì",
    "解调": "jiě tiáo",
    "似然": "sì rán",
    "泊松": "pō sōng",
    "伽马": "gā mǎ",
    "卡方": "kǎ fāng",
    "卡尔曼": "kǎ ěr màn",
    "协方差": "xié fāng chā",
    "概率": "gài lǜ",
    "频率": "pín lǜ",
    "分辨率": "fēn biàn lǜ",
    "重采样": "chóng cǎi yàng",
    "多重": "duō chóng",
    "重尾": "zhòng wěi",
    "分量": "fēn liàng",
    "主成分": "zhǔ chéng fèn",
    "共轭": "gòng è",
    "徙动": "xǐ dòng",
    "奇异": "qí yì",
    "最小二乘": "zuì xiǎo èr chéng",
    "蒙特卡洛": "méng tè kǎ luò",
}


def read_dictionary(path):
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    try:
        start = lines.index("---")
        end = lines.index("...", start + 1)
    except ValueError as error:
        raise ValueError(f"{path}: missing Rime header delimiters --- / ...") from error
    return lines, start, end


def load_character_readings(path):
    lines, _, end = read_dictionary(path)
    readings = defaultdict(set)
    for line in lines[end + 1:]:
        if not line or line.startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) >= 2 and len(fields[0]) == 1:
            readings[fields[0]].add(fields[1])
    if not readings:
        raise ValueError(f"{path}: no character readings found")
    return readings


def check(path, chars_path=None):
    lines, start, end = read_dictionary(path)
    readings = load_character_readings(chars_path) if chars_path is not None else None
    errors = []
    header = {}
    for number in range(start + 1, end):
        line = lines[number]
        if not line or line.startswith("#"):
            continue
        match = re.fullmatch(r'([a-z_]+):\s*(.+)', line)
        if not match:
            errors.append(f"{number + 1}: invalid header field")
            continue
        key, value = match.groups()
        if key in header:
            errors.append(f"{number + 1}: duplicate header key {key}")
        header[key] = value.strip('"\'')
    expected = {
        "name": path.name.removesuffix(".dict.yaml"),
        "sort": "by_weight",
        "use_preset_vocabulary": "false",
    }
    for key, value in expected.items():
        if header.get(key) != value:
            errors.append(f"header: expected {key}: {value}")
    if not re.fullmatch(r"\d{4}\.\d{2}\.\d{2}\.\d+", header.get("version", "")):
        errors.append("header: version must be YYYY.MM.DD.N")

    counts = Counter()
    labels = {}
    seen_words = {}
    category = None
    for number, line in enumerate(lines[end + 1:], end + 2):
        if not line:
            continue
        if line != line.strip():
            errors.append(f"{number}: leading/trailing whitespace")
        if unicodedata.normalize("NFC", line) != line:
            errors.append(f"{number}: text must use NFC Unicode normalization")
        match = CATEGORY.fullmatch(line)
        if match:
            category, label = match.groups()
            if category in labels:
                errors.append(f"{number}: repeated category {category}")
            labels[category] = label
            continue
        if line.startswith("#"):
            continue
        fields = line.split("\t")
        if len(fields) != 3:
            errors.append(f"{number}: expected exactly 3 tab-separated columns")
            continue
        word, code, weight = fields
        if category is None:
            errors.append(f"{number}: entry outside a category")
        counts[category] += 1
        if word in seen_words:
            errors.append(f"{number}: duplicate {word}; first at line {seen_words[word]}")
        seen_words[word] = number
        if not HANZI.fullmatch(word):
            errors.append(f"{number}: this dictionary requires Chinese-only entries: {word}")
        if not re.fullmatch(r"[1-9]\d*", weight) or not 1 <= int(weight) <= 1000:
            errors.append(f"{number}: weight must be an integer between 1 and 1000")
        syllables = code.split(" ")
        if len(word) != len(syllables):
            errors.append(f"{number}: {word}: {len(word)} characters / {len(syllables)} syllables")
            continue
        for char, syllable in zip(word, syllables):
            if not PINYIN.fullmatch(syllable):
                errors.append(f"{number}: invalid pinyin token {syllable!r}")
            elif readings is not None and syllable not in readings.get(char, set()):
                allowed = ", ".join(sorted(readings.get(char, set()))) or "character absent"
                errors.append(f"{number}: {word}: {char}={syllable}; local readings: {allowed}")
        for phrase, expected_code in CONTEXT_READINGS.items():
            for occurrence in re.finditer(re.escape(phrase), word):
                actual = " ".join(syllables[occurrence.start():occurrence.end()])
                if actual != expected_code:
                    errors.append(f"{number}: {word}: use {expected_code} for {phrase}, got {actual}")
    if not seen_words:
        errors.append("dictionary contains no entries")
    for key, label in labels.items():
        if not counts[key]:
            errors.append(f"empty category: {label}")
    return header, counts, labels, errors


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dictionary", nargs="?", type=Path,
                        default=ROOT / "radar_statistics.dict.yaml")
    parser.add_argument("--chars", type=Path,
                        help="Optional path to Wanxiang's chars.dict.yaml")
    args = parser.parse_args()
    try:
        header, counts, labels, errors = check(args.dictionary, args.chars)
    except (OSError, UnicodeError, ValueError) as error:
        print(f"ERROR: {error}")
        return 1
    for error in errors:
        print(f"ERROR: {error}")
    if errors:
        print(f"FAILED: {len(errors)} issue(s)")
        return 1
    print(f"PASS: {args.dictionary.resolve()}")
    print(f"Version: {header['version']}")
    print(f"Entries: {sum(counts.values())}; categories: {len(labels)}")
    for key, label in labels.items():
        print(f"  {label}: {counts[key]}")
    print("Checked: headers, categories, columns, duplicates, weights, pinyin format, technical readings.")
    if args.chars is not None:
        print(f"Character readings checked against: {args.chars.resolve()}")
    else:
        print("Character readings not checked; pass --chars with a local Wanxiang character dictionary.")
    print("This check does not replace Rime deployment or review of terminology.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
