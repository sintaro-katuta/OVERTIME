# スキル選択画面の動画

既存の実ゲーム録画を960×540 / 30fps / Ogg Theoraへ変換。準備画面で自動ループ再生するため音声トラックを除去し、一時停止/再開をUIから操作する。6本合計約9.1MB。外部ダウンロードや実行時ネットワークアクセスは不要。

| 出力 | 元の録画 |
|---|---|
| grapple.ogv | docs/screenshots/skills-recall/grapple.mp4 |
| repulse.ogv | docs/screenshots/skills-polished/repulse.mp4 |
| rewind.ogv | docs/screenshots/skills-recall/rewind.mp4 |
| vortex.ogv | docs/screenshots/skills-polished/vortex.mp4 |
| chrono.ogv | docs/screenshots/skills-field/chrono.mp4 |
| aegis.ogv | docs/screenshots/skills-field/aegis.mp4 |

録画は `tests/skill_motion_preview.gd` で固定配置・自動入力により実スキルのコントローラ、敵物理、弾の衝突を動かしたもの。グラップル/リワインドは帰還動作の更新版、クロノ/イージスは自己連射強化と青い盾の更新版を採用。映像内のHUDと武器外観は録画時点のもの。

再生成: `python3 scripts/encode_skill_previews.py --ffmpeg /path/to/ffmpeg`。

再生確認: `tests/skill_selection_video_test.gd`。6種類のデコード進行、選択切替、停止/再開、EOFでのループ、画面離脱時の停止を確認する。描画ありで実行すると各スキルの画面を `/tmp/skill-browser-<id>.png` に保存する。
