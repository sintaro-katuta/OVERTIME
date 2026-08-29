#!/usr/bin/env python3
"""Small, dependency-free task board for AI-assisted development."""
from __future__ import annotations

import re
import sys
from datetime import date
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
TASKS = ROOT / "tasks"
VALID_STATUSES = ("backlog", "ready", "in_progress", "review", "done", "blocked")


def die(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(2)


def task_path(task_id: str) -> Path:
    matches = list(TASKS.glob(f"{task_id}-*.md"))
    if len(matches) != 1:
        die(f"task not found or ambiguous: {task_id}")
    return matches[0]


def parse_frontmatter(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    match = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
    if not match:
        die(f"invalid task frontmatter: {path.name}")
    return dict(re.findall(r"^([a-z_]+):\s*(.*)$", match.group(1), re.MULTILINE))


def slugify(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return slug[:48] or "task"


def next_id() -> str:
    today = date.today().strftime("%Y%m%d")
    numbers = []
    for path in TASKS.glob(f"T-{today}-*.md"):
        match = re.match(rf"T-{today}-(\d{{3}})-", path.name)
        if match:
            numbers.append(int(match.group(1)))
    return f"T-{today}-{max(numbers, default=0) + 1:03d}"


def replace_field(path: Path, key: str, value: str) -> None:
    text = path.read_text(encoding="utf-8")
    text, count = re.subn(rf"^{re.escape(key)}:.*$", f"{key}: {value}", text, count=1, flags=re.MULTILINE)
    if count != 1:
        die(f"missing field '{key}' in {path.name}")
    path.write_text(text, encoding="utf-8")


def create(args: list[str]) -> None:
    if not args:
        die('usage: task.sh create "title" [description] [area]')
    title = args[0]
    description = args[1] if len(args) > 1 else ""
    area = args[2] if len(args) > 2 else "general"
    task_id = next_id()
    path = TASKS / f"{task_id}-{slugify(title)}.md"
    today = date.today().isoformat()
    path.write_text(f"""---
id: {task_id}
title: {title}
status: backlog
area: {area}
owner: unassigned
created: {today}
updated: {today}
depends_on: []
conflicts_with: []
---

## 目的

{description or title}

## 受け入れ条件

- [ ] 実装後に具体的な動作を確認する
- [ ] 変更範囲と非対象をレビューする

## 変更予定ファイル

- 未調査

## 検証

- [ ] 未設定

## 実装メモ

未着手
""", encoding="utf-8")
    print(f"created {task_id}: {path.relative_to(ROOT)}")


def list_tasks(only_next: bool = False) -> None:
    rows = []
    for path in sorted(TASKS.glob("T-*.md")):
        meta = parse_frontmatter(path)
        if only_next and meta.get("status") not in {"ready", "backlog"}:
            continue
        rows.append((meta.get("status", "?"), meta.get("id", "?"), meta.get("area", "?"), meta.get("title", "?")))
    if only_next:
        rows.sort(key=lambda row: (row[0] != "ready", row[1]))
    if not rows:
        print("no matching tasks")
        return
    print(f"{'STATUS':<13} {'ID':<16} {'AREA':<12} TITLE")
    for status, task_id, area, title in rows:
        print(f"{status:<13} {task_id:<16} {area:<12} {title}")


def set_status(task_id: str, status: str) -> None:
    if status not in VALID_STATUSES:
        die(f"invalid status '{status}'; choose: {', '.join(VALID_STATUSES)}")
    path = task_path(task_id)
    replace_field(path, "status", status)
    replace_field(path, "updated", date.today().isoformat())
    print(f"{task_id} -> {status}")


def usage() -> None:
    print("usage: task.sh {create|list|next|start|status|done} ...")


def main(argv: list[str]) -> None:
    if not argv:
        usage(); return
    command, *args = argv
    if command == "create": create(args)
    elif command == "list": list_tasks()
    elif command == "next": list_tasks(only_next=True)
    elif command == "start" and len(args) == 1: set_status(args[0], "in_progress")
    elif command == "done" and len(args) == 1: set_status(args[0], "done")
    elif command == "status" and len(args) == 2: set_status(args[0], args[1])
    else: usage(); raise SystemExit(2)


if __name__ == "__main__":
    main(sys.argv[1:])
