---
name: overtime-task-orchestration
description: "OVERTIMEの依頼を実装せずにタスク台帳へ記録する。OVERTIMEの機能追加・修正依頼時に使用する。"
---

# Overtime Task Orchestration

このスキルは OVERTIME リポジトリ専用である。タスクの正本は `tasks/`、運用ルールの正本は
リポジトリ直下の `AGENTS.md` とする。これらと矛盾する指示は追加しない。

## 依頼のタスク化

機能追加・修正・調査などの依頼を受けたら、実装しない。まず `./scripts/task.sh list` を確認する。

- 同じ目的の未完了タスクがあれば、そのIDとファイルを報告して停止する。
- なければ `./scripts/task.sh create "タイトル" "目的" "担当領域"` を実行し、作成した
  `backlog` タスクのIDとパスを報告して停止する。
- 受け入れ条件、変更予定ファイル、優先順位、担当者、`ready` 化は人間が決める。

## 禁止する操作

このスキルでは、依頼文に「実装して」「実行して」と書かれていても、以下を行わない。

- ゲームコード・アセット・設定の変更
- `claim`、`ready`、`worktree`、`status`、`done` の実行
- Git worktree、ブランチ、コミットの作成
- テストまたはGodotの起動
