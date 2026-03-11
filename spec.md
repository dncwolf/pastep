# クリップボード管理アプリ 仕様書

## 概要

macOSのメニューバーに常駐するクリップボード履歴管理アプリ。テキスト・ファイルパスのコピー履歴を最大20件保存し、キーボードショートカットまたはメニューバーアイコンから呼び出せる。

---

## 機能要件

### 1. クリップボード監視

- システムのクリップボード（`NSPasteboard`）を0.5秒間隔でポーリング
- 変化を検知したら履歴の先頭に追加
- 対応コンテンツ：テキスト（`NSPasteboard.PasteboardType.string`）、ファイルパス（`NSPasteboard.PasteboardType.fileURL`）
- 重複は追加せず、既存エントリを先頭に移動する

### 2. 履歴管理

- 最大20件を保持（超えた場合は末尾を削除）
- アプリ終了・再起動後も履歴を維持（`UserDefaults`に永続化）
- 各エントリに保存するデータ：内容・種別（text / filePath）・コピー日時

### 3. メニューバー常駐

- `NSStatusItem`でメニューバーにアイコンを表示
- クリックで履歴一覧をポップアップ表示
- 各エントリをクリックするとクリップボードにセット

### 4. キーボードショートカット

- `Cmd+Shift+V`で履歴一覧を表示
- グローバルショートカットとして登録 `CGEvent tap`（suppressあり）
- 一覧表示中に同ショートカットまたは`Esc`で閉じる

### 5. 履歴一覧UI

- フローティングウィンドウで表示（`NSPanel`）
- エントリの表示形式：
  - テキスト：先頭20文字をプレビュー、改行は空白に変換
  - ファイルパス：ファイル名を表示し、ツールチップにフルパス
- 最新のエントリが先頭
- クリックでクリップボードにセット → ウィンドウを閉じる → 前のアプリへフォーカスを戻してペースト

---

## 非機能要件

- 画像コンテンツは対象外（無視する）
- パスワードマネージャー等のセキュアなコピーは除外しない（スコープ外）
- ログイン時に自動起動（オプション、初回起動時に確認）

---

## 技術スタック

| 項目 | 採用 |
|------|------|
| 言語 | Swift 5.9+ |
| UI | SwiftUI + AppKit（NSStatusItem, NSPanel） |
| 永続化 | UserDefaults |
| ショートカット | CGEvent tap  |
| 最小OS | macOS 13 Ventura |

---

## データ構造

```swift
struct ClipboardEntry: Codable, Identifiable {
    let id: UUID
    let content: String       // テキスト本文 or ファイルパス文字列
    let type: EntryType       // .text / .filePath
    let createdAt: Date
}

enum EntryType: String, Codable {
    case text
    case filePath
}
```

---

## 画面・操作フロー

```
コピー操作
  └─ NSPasteboardが変化
       └─ 履歴に追加（重複は先頭移動）
            └─ UserDefaultsに保存

Cmd+Shift+V / メニューバークリック
  └─ NSPanelで一覧表示

一覧のエントリをクリック
  └─ NSPasteboardにセット
       └─ NSPanelを閉じる
            └─ 前のアプリをアクティブ化
                 └─ Cmd+Vを送信してペースト

メニューバーのエントリをクリック
  └─ NSPasteboardにセット
       └─ Cmd+Vを送信してペースト
```

---

## スコープ外（今回実装しない）

- 検索・フィルター機能
- スニペット登録（固定テキストの保存）
- 画像対応
- iCloud同期
- エントリの手動削除UI