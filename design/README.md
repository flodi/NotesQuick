# NotesQuick — icone

Icone dell'app per **iOS / iPadOS / macOS** e icona della **barra dei menu**.

Le icone app vengono dal **design system Quick** (`../designsystem/app-icons/`): matita bianca su tessera nera, quadrato arancio in basso a destra. Questa cartella ne tiene una copia; la fonte è il design system, quindi per aggiornarle si ricopia da lì.

## Contenuto

```
design/
├─ notes.svg · notes-dark.svg · notes-tinted.svg   ← master vettoriali dell'icona app
│
├─ AppIcon-iOS.appiconset/           ← copia di NotesQuickiOS/Resources/Assets.xcassets/AppIcon.appiconset
│  ├─ Contents.json
│  └─ icon-1024(.png / -dark / -tinted)
│
├─ AppIcon-macOS.appiconset/         ← copia di NotesQuickMac/Resources/Assets.xcassets/AppIcon.appiconset
│  ├─ Contents.json
│  └─ icon_16 … icon_1024.png
│
├─ NotesQuick-MenuBar-master.svg     ← master vettoriale dell'icona della barra dei menu (nero + alpha)
├─ MenuBarIcon.imageset/             ← icona della barra dei menu (template-rendering-intent già impostato)
├─ MenuBarIcon/                      ← gli stessi PNG "sciolti"
└─ source/draw-icon.js               ← sorgente canvas dell'icona della barra dei menu
```

## Icona della barra dei menu

Non fa parte del design system: è specifica di NotesQuick. È un'immagine *template* (solo nero + canale alpha), quindi macOS la tinge da solo e non va aggiunto colore.

```swift
MenuBarExtra("NotesQuick", image: "MenuBarIcon") { /* … */ }
```

Per rigenerare i PNG:

```js
const cv = document.createElement('canvas'); cv.width = cv.height = 36;
drawNotesQuickIcon(cv.getContext('2d'), 36, { variant: 'B', mono: true });
```

`draw-icon.js` disegna anche la vecchia icona app blu (varianti `A`, `B`, `C` senza `mono`), che non è più in uso.

I file `-2x` / `-3x` sostituiscono `@2x` / `@3x`: i `Contents.json` puntano già ai nomi corretti.

## Palette

| Uso | HEX |
|---|---|
| Accento | `#D9772E` |
| Accento (dark) | `#F08A3E` |

Il resto dei token (colori di stato, tipografia, spazi, raggi) è in `NotesQuick/Views/QuickDesign.swift`.
