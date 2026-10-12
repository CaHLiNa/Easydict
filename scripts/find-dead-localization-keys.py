#!/usr/bin/env python3
"""Report localization keys that are unreferenced and belong to removed features.

A key is reported when both hold:
  1. no source file contains the key (or its interpolated prefix) as a literal;
  2. the key matches a pattern for a feature this fork has removed.

Usage:
    python3 scripts/find-dead-localization-keys.py [--delete]

The catalog is edited textually so the surrounding formatting stays intact.
"""

import json
import re
import sys
from pathlib import Path

CATALOG = Path("Easydict/App/Localizable.xcstrings")
SOURCE_ROOTS = [Path("Easydict"), Path("EasydictTests"), Path("scripts")]
SOURCE_SUFFIXES = {".swift", ".m", ".h", ".js", ".py", ".sh", ".plist", ".json", ".yml"}

# Keys whose owning feature no longer exists in this fork. Intersected with the
# unreferenced set so an accidentally matching but live key is never removed.
DEAD_PATTERNS = [
    r"deepl",
    r"google",
    r"baidu",
    r"bing",
    r"tencent",
    r"alibaba",
    r"\bali[_\.]",
    r"volcano",
    r"caiyun",
    r"niutrans",
    r"doubao",
    r"minimax",
    r"zhipu",
    r"groq",
    r"gemini",
    r"claude",
    r"ollama",
    r"mdict",
    r"copilot",
    r"codex",
    r"polish",
    r"summary",
    r"anki",
    r"beta",
    r"language_detect_optimize",
    r"detect_optimize",
    r"check_for_updates",
    r"check_updates",
    r"check_now",
    r"auto_check_update",
    r"lastest_version",
    r"include_beta",
    r"openai_translate",
    r"github_models",
    r"agent_cli",
]
DEAD_REGEX = re.compile("|".join(DEAD_PATTERNS), re.IGNORECASE)


def source_blob() -> str:
    chunks = []
    for root in SOURCE_ROOTS:
        for path in root.rglob("*"):
            if not path.is_file() or path.suffix not in SOURCE_SUFFIXES:
                continue
            if path.name == CATALOG.name:
                continue
            try:
                chunks.append(path.read_text(encoding="utf-8", errors="ignore"))
            except OSError:
                continue
    return "\n".join(chunks)


def needles_for(key: str) -> list[str]:
    needles = [key]
    # String catalog stores interpolated keys as e.g. "current_version %@"; the
    # source contains only the prefix.
    if " %" in key:
        needles.append(key.split(" %", 1)[0])
    return needles


def main() -> int:
    delete = "--delete" in sys.argv
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    strings = catalog["strings"]
    blob = source_blob()

    unreferenced, dead = [], []
    for key in strings:
        if not any(needle in blob for needle in needles_for(key)):
            unreferenced.append(key)
            if DEAD_REGEX.search(key):
                dead.append(key)

    print(f"total keys: {len(strings)}")
    print(f"unreferenced: {len(unreferenced)}")
    print(f"unreferenced and belonging to removed features: {len(dead)}")
    for key in sorted(dead):
        english = ""
        for entry in strings[key].get("localizations", {}).get("en", {}).get("stringUnit", {}).items():
            english = entry[1]
        print(f"  {key}  ->  {english}")

    others = sorted(set(unreferenced) - set(dead))
    if others:
        print(f"\nunreferenced but not matched by removed-feature patterns: {len(others)}")
        for key in others[:40]:
            print(f"  (kept) {key}")

    if not delete:
        return 0

    text = CATALOG.read_text(encoding="utf-8")
    for key in sorted(dead, key=len, reverse=True):
        text = remove_key_block(text, key)
    json.loads(text)  # fail fast if the edit broke the JSON
    CATALOG.write_text(text, encoding="utf-8")
    print(f"\nremoved {len(dead)} keys")
    return 0


def remove_key_block(text: str, key: str) -> str:
    """Remove the `"key" : { ... }` block, including its trailing comma."""
    quoted = json.dumps(key, ensure_ascii=False)
    start = text.find(f"    {quoted} : {{")
    if start == -1:
        return text

    depth = 0
    index = text.index("{", start)
    while True:
        char = text[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                break
        index += 1

    end = index + 1
    if text[end:end + 1] == ",":
        end += 1
    # Consume the rest of the line and the following blank/indent.
    newline = text.find("\n", end)
    if newline != -1 and not text[end:newline].strip():
        end = newline + 1

    # Removing the last member of an object also requires dropping the comma that
    # separated it from the previous member. A newline replaces the removed span so
    # the previous member and the closing brace stay on separate lines.
    if text[end:].lstrip().startswith("}"):
        before = text[:start].rstrip()
        if before.endswith(","):
            return text[:len(before) - 1] + "\n" + text[end:]

    return text[:start] + text[end:]


if __name__ == "__main__":
    raise SystemExit(main())
