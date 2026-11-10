#!/usr/bin/env python3
"""Check the optional filter data and phrase examples with Python 3.9+."""

from pathlib import Path
import re
import sys
import unicodedata

ROOT = Path(__file__).resolve().parents[1]


def content(path):
    for number, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        if not line or line.startswith("#"):
            continue
        if line != line.strip():
            raise ValueError(f"{path.name}:{number}: leading/trailing whitespace")
        if unicodedata.normalize("NFC", line) != line:
            raise ValueError(f"{path.name}:{number}: text must use NFC normalization")
        yield number, line


def check_words(path):
    seen = set()
    for number, word in content(path):
        if "\t" in word or word.lower() in seen:
            raise ValueError(f"{path.name}:{number}: duplicate word or unexpected tab")
        seen.add(word.lower())
    if not seen:
        raise ValueError(f"{path.name}: empty word list")
    return len(seen)


def check_rules(path):
    seen = set()
    for number, line in content(path):
        fields = line.split("\t")
        if len(fields) not in (2, 3):
            raise ValueError(f"{path.name}:{number}: expected 2 or 3 tab-separated columns")
        mode, term = fields[:2]
        if mode not in ("contains", "word") or not term or term != term.strip():
            raise ValueError(f"{path.name}:{number}: invalid mode or term")
        key = (mode, term.lower())
        if key in seen:
            raise ValueError(f"{path.name}:{number}: duplicate rule {term}")
        seen.add(key)
        exceptions = fields[2].split("|") if len(fields) == 3 else []
        lowered = [value.lower() for value in exceptions]
        if len(lowered) != len(set(lowered)):
            raise ValueError(f"{path.name}:{number}: duplicate exception")
        for value in exceptions:
            if not value or value != value.strip() or term.lower() not in value.lower():
                raise ValueError(f"{path.name}:{number}: exception must contain the matched term")
    if not seen:
        raise ValueError(f"{path.name}: empty rule list")
    return len(seen)


def check_phrases(path):
    seen = set()
    for number, line in content(path):
        fields = line.split("\t")
        if len(fields) != 3:
            raise ValueError(f"{path.name}:{number}: expected 3 tab-separated columns")
        text, code, weight = fields
        if not text or not re.fullmatch(r"[a-z']+", code):
            raise ValueError(f"{path.name}:{number}: invalid text or code")
        if not re.fullmatch(r"[1-9][0-9]*", weight):
            raise ValueError(f"{path.name}:{number}: weight must be a positive integer")
        key = (text, code)
        if key in seen:
            raise ValueError(f"{path.name}:{number}: duplicate phrase/code pair")
        seen.add(key)
    if not seen:
        raise ValueError(f"{path.name}: empty phrase list")
    return len(seen)


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    checks = [
        ("custom/blocked_words.txt", check_words),
        ("custom/blocked_word_rules.tsv", check_rules),
        ("custom/typing_corrections.tsv", check_rules),
        ("custom_phrase.example.txt", check_phrases),
    ]
    try:
        for name, checker in checks:
            count = checker(ROOT / name)
            print(f"PASS: {name}: {count} entries")
    except (OSError, UnicodeError, ValueError) as error:
        print(f"ERROR: {error}")
        return 1
    print("Checked data structure only; candidate behavior requires Rime deployment.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
