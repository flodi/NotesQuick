# Scheda App Store — NotesQuick

Un solo record su App Store Connect (`com.notesquick.app`, Apple ID `6788065433`) con due
piattaforme, iOS e macOS. I testi stanno in `Store/listing.json` e si applicano con
`scripts/asc_listing.py`; questo file spiega la procedura e tiene lo stato.

Scheda: <https://appstoreconnect.apple.com/apps/6788065433/distribution>

## Credenziali

Il repository è pubblico: nessuna credenziale nei file.

```sh
export ASC_API_ISSUER=…        # Issuer ID di App Store Connect
export ASC_API_KEY=…           # Key ID, serve solo a scripts/archive.sh
export ASC_REVIEW_PHONE="+39 …" # telefono del contatto per la revisione, serve solo a `metadata`
```

La chiave `.p8` sta in `~/.appstoreconnect/private_keys/`; `scripts/asc.py` prova quelle presenti
e usa la prima valida per il team.

## Procedura

```sh
./scripts/archive.sh --upload            # archivia Mac e iOS, carica, aspetta l'elaborazione e
                                         # assegna la build al gruppo interno di TestFlight
python3 scripts/asc_listing.py metadata      # testi it + en, categorie, versione, copyright, dati revisione
python3 scripts/asc_listing.py agerating     # 4+
python3 scripts/asc_listing.py pricing       # gratuita, tutti i paesi
python3 scripts/asc_listing.py screenshots   # iPhone, iPad e Mac, in italiano e in inglese
python3 scripts/asc_listing.py status
python3 scripts/asc_listing.py submit <build> # aggancia la build e invia iOS e macOS in revisione
```

I comandi sono idempotenti. Il questionario sulla privacy non ha API: va compilato nel sito.

## Cosa c'è nella scheda

| Campo | Valore |
|---|---|
| Nome | NotesQuick |
| Sottotitolo | Note Markdown in una cartella · Markdown notes in a folder |
| Categorie | Produttività, Utility |
| Prezzo | Gratuita, tutti i paesi |
| Classificazione | 4+ |
| Copyright | 2026 Fabrizio Lodi |
| Supporto | <https://quickmac.in/notes/> · <https://quickmac.in/en/notes/> |
| Privacy | <https://quickmac.in/notes/privacy.html> · <https://quickmac.in/en/notes/privacy.html> |
| Lingue | Italiano (principale) e inglese, nell'app e nella scheda |

Le pagine di supporto e privacy stanno nel sito `quickmac.in` (cartella `site/` accanto alle app,
`notes/` e `en/notes/`), pubblicato con `site/deploy.sh`.

## Privacy dell'app

Alla domanda «Raccogli dati da questa app?» la risposta è **No**: l'app legge e scrive solo la
cartella scelta dall'utente, non fa richieste di rete, non ha account né analitiche.
`NotesQuick/Resources/PrivacyInfo.xcprivacy` dichiara solo UserDefaults e date dei file.

## Screenshot

Stanno in `Store/screenshots/`, italiani e inglesi, con contenuti dimostrativi senza marchi altrui.

- **iPhone e iPad**: dal simulatore (iPhone 16 Pro Max → `APP_IPHONE_67`, iPad Pro 13" →
  `APP_IPAD_PRO_3GEN_129`). La build Debug accetta gli argomenti `-screenshotMode YES`,
  `-screenshotNote <titolo>` e `-screenshotSchedule YES`; le note dimostrative vanno copiate in
  `Documents/NotesQuick` nel contenitore dell'app (`xcrun simctl get_app_container … data`).
- **Mac**: senza lanciare l'app. `Tools/mac-store-shots.sh` compila le viste Mac in un programma
  senza finestre che le disegna fuori schermo, con una home privata; `Tools/compose-mac-shots.py`
  le compone sulla tela 2880×1800.

```sh
Tools/mac-store-shots.sh <cartella-demo> it "Riunione" build/shots/it
python3 Tools/compose-mac-shots.py build/shots/it Store/screenshots it
```

## Cosa si è copiato da OrgQuick e FolderQuick

- Note di revisione che rispondono in anticipo alle domande solite: scopo, come provarla passo per
  passo su ogni piattaforma, servizi esterni, regioni, sandbox.
- Su Mac l'app è solo un'icona nella barra dei menu: le note di revisione dicono dove guardare.
- Nessun marchio altrui in nome, sottotitolo, parole chiave e screenshot.
- Export compliance nel binario (`ITSAppUsesNonExemptEncryption = NO`).
- Prezzo e **disponibilità** sono cose separate: senza disponibilità un'app approvata resta
  invisibile. `pricing` imposta entrambe.
- Le build caricate non arrivano ai tester finché non sono nel gruppo interno: lo fa
  `scripts/asc.py finalize`, chiamato da `archive.sh`.

## Stato

1. ~~Testi it + en, categorie, versione 1.0.0, copyright, diritti, dati per la revisione~~
2. ~~Classificazione 4+, prezzo gratuito, disponibilità in 175 paesi~~
3. ~~Screenshot iPhone, iPad e Mac, it e en-US~~
4. ~~Pagine di supporto e privacy online su quickmac.in/notes/~~
5. ~~Build 33 (bilingue, manifest privacy) su TestFlight, nel gruppo interno~~
6. ~~Questionario privacy nel sito: «Nessun dato raccolto», pubblicato~~
7. ~~Build 33 provata da TestFlight~~
8. ~~Inviate in revisione iOS e macOS 1.0.0 (build 33)~~ — 3 ottobre 2026, rilascio automatico dopo
   l'approvazione (invii `d27d688e-e458-4810-911b-f0574e47ba4b` iOS e
   `c5f4b615-b4e0-4c98-b08d-08f81f45e824` macOS)

Dopo l'invio: se App Review risponde con domande, rispondere dal Centro risoluzione **e poi
premere «Invia di nuovo al team di verifica»**, altrimenti la risposta resta ferma. Dopo
l'approvazione controllare che l'app compaia davvero nello store
(`https://itunes.apple.com/lookup?id=6788065433&country=it`): la propagazione può richiedere un giorno.
