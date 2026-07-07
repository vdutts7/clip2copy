#!/usr/bin/env python3
"""Minimal TUI box renderer for clip2copy (z7z-style). Stdlib only."""

from __future__ import annotations

import json
import os
import sys

WIDTH = 41
EMOJI = {"ok": "🟢", "fail": "🔴", "warn": "🟡"}

PALETTE = {
    "reset": "\033[0m",
    "bold": "\033[1m",
    "dim": "\033[2m",
    "italic": "\033[3m",
    "underline": "\033[4m",
    "green": "\033[92m",
    "cyan": "\033[96m",
    "magenta": "\033[95m",
}

TITLE_COLORS = {"cyan": "cyan", "green": "green", "red": "green", "yellow": "green"}


def use_color() -> bool:
    if os.environ.get("NO_COLOR"):
        return False
    try:
        return os.isatty(1)
    except OSError:
        return False


def c(name: str | None) -> str:
    if not use_color() or not name:
        return ""
    return PALETTE.get(name, "")


def box_open(title: str, title_color: str = "cyan") -> None:
    if not use_color():
        print(f"\n== {title} ==")
        return
    tc = c(TITLE_COLORS.get(title_color, "cyan"))
    bar = "─" * WIDTH
    pad = max(1, WIDTH - len(title) - 2)
    print()
    print(f"{c('bold')}┌{bar}┐{c('reset')}")
    print(f"{c('bold')}│{c('reset')}  {tc}{title}{c('reset')}{' ' * pad}{c('bold')}│{c('reset')}")
    print(f"{c('bold')}├{bar}┤{c('reset')}")


def box_field(label: str, value: str, role: str = "value", suffix: str = "") -> None:
    label = label.lower()
    if not use_color():
        line = f"{label}: {value}"
        if suffix:
            line += f" ({suffix})" if not suffix.startswith(" ") else suffix
        print(line)
        return
    roles = {
        "value": "cyan",
        "output": "green",
        "elapsed": "magenta",
        "note": "dim",
        "status": None,
    }
    vc = c(roles.get(role, "cyan"))
    if role == "note":
        print(f"{c('bold')}│{c('reset')}  {c('dim')}{label}:{c('reset')} {c('dim')}{value}{c('reset')}")
        return
    if role == "status":
        print(f"{c('bold')}│{c('reset')}  {c('dim')}{label}:{c('reset')} {value}")
        return
    suf = ""
    if suffix:
        s = suffix.strip()
        suf = f"{c('dim')} ({s}){c('reset')}" if s else ""
    print(f"{c('bold')}│{c('reset')}  {c('dim')}{label}:{c('reset')} {vc}{value}{c('reset')}{suf}")


def box_close() -> None:
    if not use_color():
        print()
        return
    print(f"{c('bold')}└{'─' * WIDTH}┘{c('reset')}")
    print()


def content_row(text: str) -> None:
    text = text[: WIDTH - 1] + "…" if len(text) > WIDTH else text
    if not use_color():
        print(text)
        return
    print(f"{c('bold')}│{c('reset')}  {text}")


def render_list(box: dict) -> None:
    box_open(str(box.get("title") or "OPTIONS"), str(box.get("title_color") or "cyan"))
    for item in box.get("items") or []:
        if not isinstance(item, dict):
            continue
        prefix = str(item.get("prefix") or "● ")
        label = str(item.get("label") or "")
        desc = str(item.get("description") or item.get("suffix") or "")
        line = f"{prefix}{label}"
        if desc:
            line = f"{line}  {desc}"
        content_row(line)
    box_close()


def render_box(box: dict) -> None:
    box_open(str(box.get("title") or "RESULTS"), str(box.get("title_color") or "cyan"))
    for spec in box.get("fields") or []:
        if not isinstance(spec, dict):
            continue
        fid = str(spec.get("id") or "")
        label = str(spec.get("label") or fid or "field").lower()
        if fid == "status":
            level = str(spec.get("level") or "ok")
            emoji = EMOJI.get(level, "🟢")
            msg = str(spec.get("message") or "")
            box_field("status", emoji, "status")
            if msg:
                box_field("note", msg, "note")
            continue
        value = str(spec.get("value") or "")
        role = str(spec.get("role") or "value")
        suffix = str(spec.get("suffix") or "")
        box_field(label, value, role, suffix)
    box_close()


def render_hint(box: dict) -> None:
    text = str(box.get("text") or box.get("value") or "").lstrip()
    if text.startswith(">"):
        text = text[1:].lstrip()
    line = f"> {text}"
    if use_color():
        print(f"{c('dim')}{c('italic')}{line}{c('reset')}")
    else:
        print(line)


def render_session(data: dict) -> None:
    for box in data.get("boxes") or []:
        if not isinstance(box, dict):
            continue
        btype = str(box.get("type") or "box")
        if btype == "list":
            render_list(box)
        elif btype == "hint":
            render_hint(box)
        else:
            render_box(box)


def main() -> None:
    if len(sys.argv) < 2 or sys.argv[1] != "render":
        raise SystemExit("usage: tui_render.py render  (JSON on stdin)")
    render_session(json.load(sys.stdin))


if __name__ == "__main__":
    main()
