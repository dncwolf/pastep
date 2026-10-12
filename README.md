# pastep

macOS のメニューバーに常駐するクリップボード履歴マネージャー。

## 機能

- テキストとファイルパスのコピー履歴を最大 20 件保持（256KB を超えるテキストは対象外）
- `Cmd+Shift+V` でマウスカーソル位置に履歴メニューを表示して選択・ペースト
- メニューバーアイコンからも同じメニューを表示
- 再起動後も履歴を維持（`~/Library/Application Support/pastep/history.json`）

## 動作環境

- macOS 13 Ventura 以降
- Apple Silicon（arm64）

## ビルドと実行

```sh
# .app バンドルを作成して起動
make run

# バンドルのみ作成
make app

# テスト
make test

# クリーンアップ
make clean
```

## 使い方

1. `make run` で起動するとメニューバーにアイコンが表示される
2. `Cmd+Shift+V` または アイコンクリックで履歴メニューを表示
3. クリック、`↑`/`↓` + `Enter`、または数字キー（`1`〜`9`, `0` で先頭10件）で選ぶとクリップボードにセットされ、前のアプリへ自動ペースト
4. `Esc` またはメニュー外クリックで閉じる

自動ペースト（⌘V の送信）にはアクセシビリティ権限が必要。未許可の間は選択した内容をクリップボードにセットするだけになり、メニューに設定を開く項目が表示される。

## 構成

`Sources/pastep` の1ターゲットのみ。

| ファイル | 役割 |
|------|------|
| `AppDelegate.swift` | 起動・メニューバーアイコン・クリップボード監視 |
| `ClipboardEntry.swift` | 履歴の1件と表示用タイトル、NSPasteboard の読み書き |
| `History.swift` | 履歴の追加と JSON ファイルへの保存（旧 UserDefaults からの移行を含む） |
| `MenuController.swift` | 履歴メニューと選択時のペースト（⌘V 送信） |
| `HotKey.swift` | ⌘⇧V のグローバルショートカット |

## スコープ外

画像、検索、iCloud 同期、スニペット登録には対応していない。

## License
WTFPL