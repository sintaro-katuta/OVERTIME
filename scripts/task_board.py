#!/usr/bin/env python3
"""Small, dependency-free task board for parallel AI-assisted development."""
from __future__ import annotations

import re
import subprocess
import sys
from datetime import date
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
TASKS = ROOT / "tasks"
VALID_STATUSES = ("backlog", "ready", "in_progress", "review", "done", "blocked")
ACTIVE_STATUSES = {"in_progress", "review"}


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


def parse_list(value: str) -> list[str]:
    """Read the compact YAML lists used by task frontmatter without PyYAML."""
    value = value.strip()
    if not value or value == "[]":
        return []
    if not (value.startswith("[") and value.endswith("]")):
        die(f"expected a bracketed list, got: {value}")
    return [item.strip().strip('"\'') for item in value[1:-1].split(",") if item.strip()]


def planned_files(path: Path) -> set[str]:
    text = path.read_text(encoding="utf-8")
    section = re.search(r"^## 変更予定ファイル\n(.*?)(?=^## |\Z)", text, re.MULTILINE | re.DOTALL)
    if not section:
        return set()
    return set(re.findall(r"`([^`]+)`", section.group(1)))


def section_body(path: Path, heading: str) -> str:
    text = path.read_text(encoding="utf-8")
    match = re.search(rf"^## {re.escape(heading)}\n(.*?)(?=^## |\Z)", text, re.MULTILINE | re.DOTALL)
    return match.group(1).strip() if match else ""


def assert_implementation_ready(path: Path) -> None:
    """Keep placeholder tasks out of the queue agents are allowed to claim."""
    acceptance = section_body(path, "受け入れ条件")
    verification = section_body(path, "検証")
    issues = []
    if not planned_files(path):
        issues.append("変更予定ファイルに具体的なバッククォート付きパスがありません")
    if "未設定" in verification or not verification:
        issues.append("検証が未設定です")
    if not acceptance or "実装後に具体的な動作を確認する" in acceptance:
        issues.append("受け入れ条件がテンプレートのままです")
    if issues:
        die("cannot mark ready: " + "; ".join(issues))


def tasks() -> list[tuple[Path, dict[str, str]]]:
    return [(path, parse_frontmatter(path)) for path in sorted(TASKS.glob("T-*.md"))]


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
    for path, meta in tasks():
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


def assert_dependencies_complete(meta: dict[str, str]) -> None:
    incomplete = []
    for dependency in parse_list(meta.get("depends_on", "[]")):
        dependency_meta = parse_frontmatter(task_path(dependency))
        if dependency_meta.get("status") != "done":
            incomplete.append(dependency)
    if incomplete:
        die(f"dependencies are not done: {', '.join(incomplete)}")


def active_conflicts(path: Path, meta: dict[str, str]) -> list[str]:
    requested_conflicts = set(parse_list(meta.get("conflicts_with", "[]")))
    requested_files = planned_files(path)
    conflicts = []
    for other_path, other_meta in tasks():
        other_id = other_meta.get("id", "")
        if other_path == path or other_meta.get("status") not in ACTIVE_STATUSES:
            continue
        other_files = planned_files(other_path)
        if other_id in requested_conflicts or meta.get("id") in parse_list(other_meta.get("conflicts_with", "[]")):
            conflicts.append(f"{other_id} (declared conflict)")
        elif requested_files and other_files and requested_files & other_files:
            conflicts.append(f"{other_id} (shared files: {', '.join(sorted(requested_files & other_files))})")
    return conflicts


def ready(task_id: str) -> None:
    path = task_path(task_id)
    meta = parse_frontmatter(path)
    if meta.get("status") != "backlog":
        die("only backlog tasks can be marked ready")
    assert_implementation_ready(path)
    assert_dependencies_complete(meta)
    set_status(task_id, "ready")


def claim(task_id: str, owner: str) -> None:
    path = task_path(task_id)
    meta = parse_frontmatter(path)
    if meta.get("status") != "ready":
        die("only ready tasks can be claimed")
    assert_dependencies_complete(meta)
    conflicts = active_conflicts(path, meta)
    if conflicts:
        die(f"cannot claim while active work conflicts: {'; '.join(conflicts)}")
    replace_field(path, "owner", owner)
    set_status(task_id, "in_progress")
    print(f"claimed by {owner}")


def worktree(task_id: str, owner: str) -> None:
    """Create an isolated task branch after claiming it."""
    path = task_path(task_id)
    meta = parse_frontmatter(path)
    if meta.get("status") != "in_progress" or meta.get("owner") != owner:
        die("claim the task with this owner before creating its worktree")
    directory = ROOT / ".agent-worktrees" / task_id
    if directory.exists():
        die(f"worktree already exists: {directory.relative_to(ROOT)}")
    branch = f"agent/{task_id}"
    result = subprocess.run(
        ["git", "worktree", "add", str(directory), "-b", branch], cwd=ROOT, text=True, capture_output=True
    )
    if result.returncode:
        die(result.stderr.strip() or "git worktree add failed")
    print(f"created {directory.relative_to(ROOT)} on {branch}")


def validate() -> None:
    errors = []
    required = {"id", "title", "status", "area", "owner", "created", "updated", "depends_on", "conflicts_with"}
    seen_ids = set()
    active = []
    for path, meta in tasks():
        missing = required - meta.keys()
        if missing:
            errors.append(f"{path.name}: missing fields: {', '.join(sorted(missing))}")
            continue
        if meta["id"] in seen_ids:
            errors.append(f"{path.name}: duplicate id {meta['id']}")
        seen_ids.add(meta["id"])
        if meta["status"] not in VALID_STATUSES:
            errors.append(f"{path.name}: invalid status {meta['status']}")
        try:
            parse_list(meta["depends_on"]); parse_list(meta["conflicts_with"])
        except SystemExit:
            errors.append(f"{path.name}: invalid list field")
        if meta["status"] in ACTIVE_STATUSES:
            active.append((path, meta))
    for path, meta in active:
        conflicts = active_conflicts(path, meta)
        if conflicts:
            errors.append(f"{meta['id']}: active conflict: {'; '.join(conflicts)}")
    if errors:
        print("task board validation failed:", file=sys.stderr)
        print("\n".join(f"- {error}" for error in errors), file=sys.stderr)
        raise SystemExit(1)
    print(f"task board valid ({len(tasks())} tasks)")


def usage() -> None:
    print("usage: task.sh {create|list|next|ready|claim|worktree|status|done|validate} ...")


def main(argv: list[str]) -> None:
    if not argv:
        usage(); return
    command, *args = argv
    if command == "create": create(args)
    elif command == "list": list_tasks()
    elif command == "next": list_tasks(only_next=True)
    elif command == "ready" and len(args) == 1: ready(args[0])
    elif command == "claim" and len(args) == 2: claim(args[0], args[1])
    elif command == "worktree" and len(args) == 2: worktree(args[0], args[1])
    elif command == "done" and len(args) == 1: set_status(args[0], "done")
    elif command == "status" and len(args) == 2: set_status(args[0], args[1])
    elif command == "validate" and not args: validate()
    else: usage(); raise SystemExit(2)


if __name__ == "__main__":
    main(sys.argv[1:])
