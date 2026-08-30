# OVERTIME: AI Agent Working Agreement

## GitHub Issue によるタスク管理

- タスクの正本は GitHub Issue。新規タスクは `.github/ISSUE_TEMPLATE/task.yml` の必須項目に従って起票する。
- `status:triage` は情報整理中、`status:ready` は自律実装可能、`status:in-progress` は作業中、`status:review` は検証済みで統合待ち、`status:blocked` は外部判断待ちを表す。
- 実装前に、Issue の目的・背景・スコープ・完了定義・依存/競合を確認する。情報が不足する場合は `status:triage` のまま質問する。
- 実装開始、検証結果、ブロック理由は Issue コメントに記録する。Issue は変更が統合されるまで閉じない。

## 並列作業の境界

- `main.gd` は当面、**一度に一つの実装タスクだけ**が変更してよいホットスポット。
- 新機能は可能な限り `scripts/`、`docs/`、または新しい `gameplay/` 配下の専用ファイルへ分離する。
- アセット追加は `assets/` 内で専用サブディレクトリを使い、既存アセットを上書きしない。
- `project.godot`、`main.tscn`、`main.gd` の変更が必要かは、実装前にエージェントが調査し、同時進行中の作業との競合を避ける。
- `.godot/` と `.agent-worktrees/` は生成物であり、編集・コミットしない。
