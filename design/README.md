# NotesQuick — App Icon Set

Icone per **iOS / iPadOS / macOS** + icona **menu bar** dell'app di note veloci NotesQuick.
Variante scelta: **Glossy · profondità** (sfondo gradiente blu, foglio bianco con ombra, riga accento arancione).

## Contenuto

```
design/
├─ NotesQuick-Icon-master.svg        ← master vettoriale (app icon, 1024, full-bleed iOS)
├─ NotesQuick-MenuBar-master.svg     ← master vettoriale (template menu bar, nero+alpha)
├─ source/draw-icon.js               ← sorgente “verità” (canvas): rigenera ogni PNG a qualsiasi misura
│
├─ AppIcon-iOS.appiconset/           ← trascina in Assets.xcassets (target iOS/iPadOS)
│  ├─ Contents.json
│  └─ icon-1024.png                  (single-size universale, Xcode 14+)
│
├─ AppIcon-macOS.appiconset/         ← trascina in Assets.xcassets (target macOS)
│  ├─ Contents.json
│  └─ icon_16x16 … icon_512x512(-2x).png   (ladder completo 16→1024)
│
├─ MenuBarIcon.imageset/             ← icona barra dei menu (template-rendering-intent già impostato)
│  ├─ Contents.json
│  └─ NotesQuickTemplate(.png / -2x / -3x)
│
├─ MenuBarIcon/                       ← stessi PNG “sciolti”, se preferisci caricarli a mano
│
└─ alternates/                        ← 1024 delle altre due varianti, se cambi idea
   ├─ variant-A-flat-1024.png
   └─ variant-C-stacked-1024.png
```

## Installazione in Xcode

1. **App icon iOS**: trascina `AppIcon-iOS.appiconset` dentro `Assets.xcassets` del target iOS/iPadOS. In *Build Settings → Asset Catalog App Icon Set Name* metti `AppIcon-iOS` (o rinominalo `AppIcon`).
2. **App icon macOS**: idem con `AppIcon-macOS.appiconset` nel target macOS.
3. **Icona menu bar**: trascina `MenuBarIcon.imageset` in `Assets.xcassets`. È già marcata come *template*: macOS la tinge automaticamente (nera in light mode, bianca in dark), quindi **non** aggiungere colore.

```swift
// AppKit — NSStatusItem
let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
item.button?.image = NSImage(named: "MenuBarIcon")   // template: no tint manuale
```
```swift
// SwiftUI — MenuBarExtra
MenuBarExtra("NotesQuick", image: "MenuBarIcon") { /* … */ }
```

## Note tecniche

- **iOS/iPadOS**: PNG **quadrato full-bleed** senza trasparenza né angoli arrotondati — la maschera la applica il sistema.
- **macOS**: squircle flottante con padding (~9,5%) e ombra, secondo la griglia icone Apple; la trasparenza attorno è voluta.
- **Menu bar**: solo **nero + canale alpha**; le righe del foglio sono “bucate” (knockout) così restano leggibili a 18px. Il nome file `…Template` + `template-rendering-intent` attivano il tinting automatico.
- `-2x` / `-3x` sostituiscono `@2x` / `@3x` (il carattere `@` non era ammesso dal filesystem di export): i `Contents.json` puntano già ai nomi corretti, Xcode li accetta così come sono. Se preferisci lo stile Apple puoi rinominarli in `@2x`/`@3x` aggiornando i `Contents.json`.

## Rigenerare / modificare

I master SVG sono modificabili direttamente. Per rigenerare tutti i PNG in modo pixel-perfect usa `source/draw-icon.js`:

```js
// esempio (browser / node-canvas)
const cv = document.createElement('canvas'); cv.width = cv.height = 1024;
drawNotesQuickIcon(cv.getContext('2d'), 1024, { variant: 'B' });          // iOS full-bleed
drawNotesQuickIcon(cv.getContext('2d'), 1024, { variant: 'B', mac: true });// macOS squircle
drawNotesQuickIcon(cv.getContext('2d'), 36,   { variant: 'B', mono: true });// menu bar template
```

Varianti disponibili: `A` (flat) · `B` (glossy, in uso) · `C` (carta impilata).

## Palette

| Uso | HEX |
|---|---|
| Gradiente blu (top) | `#4F8BF0` |
| Gradiente blu (bottom) | `#1F5AC0` |
| Righe testo | `#2F6FDD` |
| Riga accento | `#F5842A` |
| Foglio | `#FFFFFF` |
