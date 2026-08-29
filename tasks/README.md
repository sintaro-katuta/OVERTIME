# タスク台帳

`tasks/` は AI エージェントと人間が共有する、軽量なファイルベースのカンバンです。
外部サービスに依存しないため、Git と一緒に履歴も残せます。

## 使い方

```bash
# タスク作成（説明と担当領域は任意）
./scripts/task.sh create "敵の被弾 VFX を追加" "命中時に視認性の高い VFX を表示する" gameplay

# 一覧と、次に着手しやすいタスク
./scripts/task.sh list
./scripts/task.sh next

# 作業開始・レビュー待ち・完了
./scripts/task.sh start T-20260829-001
./scripts/task.sh status T-20260829-001 review
./scripts/task.sh done T-20260829-001
```

依頼時は、たとえば「`敵の被弾 VFX を追加して`」だけで十分です。Codex はこの台帳にタスクを
作り、影響範囲を確認してから実装・検証を進めます。

## 状態

`backlog` → `ready` → `in_progress` → `review` → `done`

`blocked` は、外部の判断や素材待ちで進められないときだけ使用します。

## 並列エージェント

並列作業は必ず別 worktree に分けます。ベースの Git リポジトリ準備後に、例えば次のようにします。

```bash
git worktree add .agent-worktrees/T-20260829-001 -b agent/T-20260829-001
```

各 worktree では一つのタスクだけを扱い、完了後にコミットして main 側でレビュー・統合します。
同じホットスポット（現在は主に `main.gd`）を触る仕事は並列化しません。
