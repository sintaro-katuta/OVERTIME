---
name: overtime-github-issue-orchestration
description: OVERTIME の GitHub Issue を実装可能なタスクへ整備し、Issue の定義に従って実装・検証・進捗更新する。機能追加、修正、調査を Issue 起点で進めるときに使用する。
---

# OVERTIME GitHub Issue Orchestration

このリポジトリでは GitHub Issue がタスクの正本である。Issue Form は作業に必要な情報を一律に集める契約、当スキルはその情報を実行・更新する手順である。Issue の記載を推測で補完してスコープを広げない。

## タスクの整備

依頼に対応する未完了 Issue を `gh issue list` で探す。該当するものがなければ、依頼から確定できる内容だけを Issue Form と同じ見出し（目的、背景、スコープ、完了定義、依存・競合・注意点）で起票し、`status:triage` にする。

`status:ready` にする前に、全見出しが具体的であり、完了定義に観測可能な確認方法が含まれていることを確認する。情報が不足している場合は Issue に質問を残し、`status:triage` のまま停止する。

## 実装の進め方

`status:ready` の Issue だけを開始できる。開始時に以下を行う。

1. 依存 Issue が完了していること、スコープが他の `status:in-progress` Issue と競合しないことを確認する。必要な技術的な影響範囲は、エージェントが調査して `AGENTS.md` のホットスポット規則を守る。Issue 作成者にファイル名の記載を求めない。
2. Issue に開始コメントを残し、ラベルを `status:in-progress` に更新する。
3. `AGENTS.md` の並列作業境界を守って実装し、Issue のスコープ外は別 Issue に切り出す。
4. Issue の完了定義に含まれる確認を実行する。実行できない確認は理由と手動確認手順を記録する。
5. 変更概要・検証結果・未解決事項を Issue に記録し、完了なら `status:review` に更新する。障害があれば `status:blocked` にして、必要な判断または依存を明記する。

Issue を閉じるのは、レビュー可能な変更が統合された後だけである。コメントとラベルは Issue 本文の代替ではなく、進捗履歴として使う。

## GitHub 操作の境界

Issue 作成、ラベル更新、コメント、PR 作成、push などの外部変更は、実行直前にユーザーの依頼範囲を確認する。権限やスコープが曖昧なら、ローカルでの調査結果を示して確認を求める。
