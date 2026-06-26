# NotesQuick

A fast, minimal note‑taking app for macOS and iOS, built with SwiftUI. Notes are stored as **plain Markdown text files** in a folder you choose — no database, no proprietary format, no lock‑in. The editor renders Markdown **live, inline** as you type (headers, bold/italic, lists, links, code, quotes, tags) while keeping the underlying text fully editable.

- **macOS** — lives in the **menu bar** (no Dock icon), with each note opening in its own window.
- **iOS / iPadOS** — a standard `NavigationSplitView` list + editor.

Both apps share the same model, view‑model, and Markdown logic; only the platform‑specific UI differs.

---

## Features

- **Live Markdown highlighting** — Markdown is styled in place (the syntax markers stay visible but dimmed). Supported: headers `#`–`######`, `**bold**` / `__bold__`, `*italic*` / `_italic_`, `***bold italic***`, `~~strikethrough~~`, `` `inline code` ``, `> blockquotes`, `[links](url)`, unordered (`-` `*` `+`) and ordered (`1.`) lists, and `#tags`.
- **Plain‑file storage** — one note = one `.md` (or `.markdown` / `.txt`) file. Works with any folder, including **iCloud Drive, Dropbox**, and other Files providers.
- **Title from first line** — a note's title is its first non‑empty line, stripped of Markdown. The file is automatically renamed to match the title on save.
- **Tags** — `#tags` are detected automatically and shown as a tag cloud below the editor. Tapping a tag finds related notes (search on iOS, an inline results panel on macOS). Tags can optionally be hidden in the editor text.
- **List auto‑continuation** — pressing Return inside a list inserts the next bullet/number; pressing Return on an empty item ends the list.
- **Search** — filter notes by title or content. Notes are always sorted by most‑recently modified.
- **Auto‑save** — notes save on close; empty notes are deleted automatically. macOS also supports ⌘S.
- **Security‑scoped folder access** — the chosen folder is persisted via a security‑scoped bookmark so access survives relaunches inside the sandbox.

---

## Project structure

The project is generated with [**XcodeGen**](https://github.com/yonaskolb/XcodeGen) from [`project.yml`](project.yml) — treat `project.yml` as the source of truth; `NotesQuick.xcodeproj` is generated and should not be hand‑edited.

```
NotesQuick/                 # Shared code (both targets)
├── Models/Note.swift               # Note model — title derived from first line
├── ViewModels/NotesViewModel.swift # Load/create/save/delete + folder bookmarks
├── Utilities/Constants.swift       # Notification names (.saveCurrentNote)
├── Extensions/String+Markdown.swift# strippingMarkdown() + extractTags()
└── Views/TagCloudView.swift        # Tag chips + a custom FlowLayout

NotesQuickMac/              # macOS target (menu bar app)
├── App/NotesQuickMacApp.swift      # MenuBarExtra + Settings + editor WindowGroup
├── App/AppDelegate.swift           # .accessory activation policy (no Dock icon)
├── Views/NoteListView.swift        # Menu bar popover list
├── Views/NoteEditorView.swift      # Per‑note window editor + tag results panel
├── Views/MarkdownTextView.swift    # NSTextView-backed live highlighter
└── Views/SettingsView.swift        # Folder / extension / tags / launch-at-login

NotesQuickiOS/             # iOS / iPadOS target
├── App/NotesQuickiOSApp.swift
├── Views/ContentView.swift         # NavigationSplitView list + detail
├── Views/NoteEditorView.swift
├── Views/MarkdownTextView.swift    # UITextView-backed live highlighter
└── Views/SettingsView.swift

scripts/
├── archive.sh                      # Archive both targets, optional TestFlight upload
├── ExportOptions-Mac.plist
└── ExportOptions-iOS.plist
```

### Architecture

- **`Note`** (`struct`, `Identifiable`/`Hashable`) — wraps a `fileURL`, its `content`, and `modifiedDate`. Identity is the file path; the `title` is computed from the first non‑empty line via `strippingMarkdown()`.
- **`NotesViewModel`** (`ObservableObject`) — the single source of truth, shared as an `@EnvironmentObject`. Owns the notes array, the search text, and persisted settings (`notesFolderPath`, `fileExtension`, `hideTagsInEditor` in `UserDefaults`). Handles all file I/O and security‑scoped bookmark resolution.
- **`MarkdownTextView`** — a `UIViewRepresentable` (iOS, `UITextView`) / `NSViewRepresentable` (macOS, `NSTextView`) wrapping a native text view. A `Coordinator` re‑applies attributed‑string highlighting on every change and implements list auto‑continuation. The two platform versions are intentionally parallel implementations.

---

## Settings

| Setting | Stored key | Notes |
|---|---|---|
| Notes folder | `notesFolderPath` + `notesFolderBookmark` | Picked via Files (iOS) / `NSOpenPanel` (macOS); persisted as a security‑scoped bookmark. Defaults to `Documents/NotesQuick`. |
| File extension | `fileExtension` | `md` (default), `markdown`, or `txt`. Only matching files are listed. |
| Hide tags in editor | `hideTagsInEditor` | Renders `#tags` invisibly in the editor; they still appear in the tag cloud. |
| Launch at login | — (macOS only) | Via `SMAppService.mainApp`. |

---

## Building & running

### Requirements

- Xcode 16
- macOS 14.0+ / iOS 17.0+ deployment targets
- Swift 5.9
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) to (re)generate the project

### Generate & open

```bash
xcodegen generate
open NotesQuick.xcodeproj
```

Then select the **NotesQuickMac** or **NotesQuickiOS** scheme and run.

### Bundle identifiers

- macOS: `com.notesquick.mac`
- iOS: `com.notesquick.ios`

Both targets use Automatic signing under development team `P87G25W6U3` — change `DEVELOPMENT_TEAM` in `project.yml` to build under your own account, then re‑run `xcodegen generate`.

---

## Archiving & TestFlight

`scripts/archive.sh` bumps the shared build number in `project.yml`, regenerates the project, and archives both targets:

```bash
./scripts/archive.sh            # archive only
./scripts/archive.sh --upload   # archive, export, and upload both to TestFlight
```

Uploading requires an App Store Connect API key at `~/.appstoreconnect/private_keys/` and the key ID / issuer configured in the script.

---

## Sandbox & privacy

Both apps run sandboxed and request only **user‑selected read/write** file access (`com.apple.security.files.user-selected.read-write`). All notes stay in the folder you choose — nothing is sent anywhere; there is no network access and no analytics.

---

## Credits

App icon: *"Bloc Notes SZ"* by Fmaunier, licensed under [CC BY‑SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/), via Wikimedia Commons.
