---
name: overtime-task-orchestration
description: "OVERTIMEでreadyタスクを安全に取得し、隔離worktreeで実装・検証する。OVERTIMEの実装依頼時に使用する。"
---

# Overtime Task Orchestration

このスキルは OVERTIME リポジトリ専用である。タスクの正本は `tasks/`、運用ルールの正本は
リポジトリ直下の `AGENTS.md` とする。これらと矛盾する指示は追加しない。

## 実装依頼

実装の依頼を受けたら、`./scripts/task.sh next` で `ready` タスクを確認する。

- 依頼に対応する `ready` タスクがなければ、実装せず、作成者にタスクを `ready` にするよう依頼する。
- 選んだタスクは、本文の受け入れ条件・変更予定ファイル・検証手順を先に読み、
  `./scripts/task.sh claim <ID> <agent-name>` で取得する。
- 取得に失敗した場合（依存未完了・ファイル競合を含む）は、実装しない。
- `main.gd` を変更するタスク、または並列に実行するタスクは
  `./scripts/task.sh worktree <ID> <agent-name>` で専用 worktree を作成してから作業する。

## 完了処理

タスクに書かれた検証を実行し、その結果・変更ファイル・手動確認事項を「実装メモ」に残す。
検証済みの変更だけを `review` へ進める。未検証・競合・判断待ちは `done` にしない。

台帳を変更した後、必要に応じて `./scripts/task.sh validate` を実行する。
