#!/usr/bin/env python3
"""Demo notes folder for the store screenshots (no third-party brands).

  make-demo-notes.py <out-dir> <lang: it|en> [--pins]
"""
import datetime, json, os, sys, time
from PIL import Image, ImageDraw

OUT, LANG = sys.argv[1], sys.argv[2]
PINS = "--pins" in sys.argv
ITEMS = {
 "it": [("Riunione di progetto.md", "# Riunione di progetto\n\nPresenti: **Marta**, Luca, Giulia. Prossimo incontro *giovedì alle 10*.\n\n## Decisioni\n- Il preventivo va inviato entro venerdì\n- Luca prepara la bozza del contratto\n- Si passa alla **fase due** a novembre\n\n## Da fare\n1. Rivedere il piano dei costi\n2. Scrivere a `fornitori@example.com`\n3. Aggiornare il [calendario condiviso](https://example.com/calendario)\n\n> Ricordarsi di chiedere conferma sulle date.\n\n#lavoro #riunioni #progetto\n", 0.4),
        ("Lista della spesa.md", "# Lista della spesa\n\n- Pane\n- Pomodori\n- Caffè\n- Parmigiano\n\n#casa\n", 3),
        ("Ricetta del pane fatto in casa.md", "[Ricetta del pane fatto in casa](https://example.com/pane)\n", 26),
        ("Preventivo cucina.pdf", None, 50),
        ("Idee per il viaggio a Lisbona.md", "# Idee per il viaggio a Lisbona\n\n- Tram 28 al mattino presto\n- Belém e i pastéis\n- Una giornata a Sintra\n\n#viaggi\n", 75),
        ("Libri da leggere.md", "# Libri da leggere\n\n1. *Il barone rampante*\n2. *Lessico famigliare*\n3. *Se questo è un uomo*\n\n#letture\n", 124),
        ("Lavagna riunione.jpg", None, 170),
        ("Regalo per Anna.md", "# Regalo per Anna\n\nCompleanno il **14 novembre**. Idee: una stampa incorniciata, un corso di ceramica.\n\n#famiglia\n", 300),
        ("Manutenzione bici.md", "# Manutenzione bici\n\n- Cambiare i pattini dei freni\n- Lubrificare la catena\n\n#casa\n", 520)],
 "en": [("Project meeting.md", "# Project meeting\n\nAttendees: **Martha**, Luke, Julia. Next meeting *Thursday at 10*.\n\n## Decisions\n- The quote goes out by Friday\n- Luke drafts the contract\n- **Phase two** starts in November\n\n## To do\n1. Review the cost plan\n2. Write to `suppliers@example.com`\n3. Update the [shared calendar](https://example.com/calendar)\n\n> Remember to confirm the dates.\n\n#work #meetings #project\n", 0.4),
        ("Shopping list.md", "# Shopping list\n\n- Bread\n- Tomatoes\n- Coffee\n- Parmesan\n\n#home\n", 3),
        ("Homemade bread recipe.md", "[Homemade bread recipe](https://example.com/bread)\n", 26),
        ("Kitchen quote.pdf", None, 50),
        ("Ideas for the Lisbon trip.md", "# Ideas for the Lisbon trip\n\n- Tram 28 early in the morning\n- Belém and the pastéis\n- A day in Sintra\n\n#travel\n", 75),
        ("Books to read.md", "# Books to read\n\n1. *Middlemarch*\n2. *The Remains of the Day*\n3. *To the Lighthouse*\n\n#reading\n", 124),
        ("Meeting whiteboard.jpg", None, 170),
        ("Gift for Anna.md", "# Gift for Anna\n\nBirthday on **November 14**. Ideas: a framed print, a pottery class.\n\n#family\n", 300),
        ("Bike maintenance.md", "# Bike maintenance\n\n- Replace the brake pads\n- Oil the chain\n\n#home\n", 520)],
}[LANG]
REMIND = {1: 3, 7: 12}          # item index -> reminder in N days
PINNED = {1, 7}                 # with --pins

os.makedirs(OUT, exist_ok=True)
now = time.time()
for name, body, age_h in ITEMS:
    path = os.path.join(OUT, name)
    if name.endswith(".pdf"):
        im = Image.new("RGB", (1240, 1754), "white"); d = ImageDraw.Draw(im)
        d.rectangle([120, 140, 700, 170], fill=(40, 40, 44))
        for i in range(14): d.rectangle([120, 260 + i * 70, 1120 - (i % 3) * 180, 274 + i * 70], fill=(200, 200, 205))
        im.save(path, "PDF")
    elif name.endswith(".jpg"):
        im = Image.new("RGB", (1600, 1200), (245, 245, 247)); d = ImageDraw.Draw(im)
        d.rectangle([200, 200, 1400, 1000], outline=(60, 60, 67), width=6)
        for i in range(5): d.line([300, 330 + i * 130, 1100 - (i % 2) * 250, 330 + i * 130], fill=(60, 60, 67), width=10)
        im.save(path, "JPEG")
    else:
        open(path, "w").write(body)
    os.utime(path, (now - age_h * 3600,) * 2)

meta = {}
for i, days in {5: 3, 7: 12}.items():
    when = (datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=days)).replace(hour=7, minute=0, second=0, microsecond=0)
    meta.setdefault(ITEMS[i][0], {})["remindAt"] = when.strftime("%Y-%m-%dT%H:%M:%SZ")
if PINS:
    for i in PINNED: meta.setdefault(ITEMS[i][0], {})["pinned"] = True
json.dump(meta, open(os.path.join(OUT, ".notesquick-meta.json"), "w"))
