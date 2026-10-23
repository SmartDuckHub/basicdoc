# BASIC-documentatietools

Twee commandline-tools die documentatie genereren uit BASIC-broncode:

| Tool | Voor | Uitvoer |
|---|---|---|
| **fbdoc** | FreeBASIC (`.bas`, `.bi`) | text, Markdown, HTML, JSON, Graphviz, Mermaid, aanroepboom |
| **msxbasicdoc** | MSX-BASIC (ASCII-opgeslagen `.BAS`) | HTML, optioneel Graphviz |

Beide tools zijn zelf in FreeBASIC geschreven en hebben geen externe bibliotheken nodig.

*English summary: see [below](#in-english).*

---

## Inhoud van de repository

```
fbdoc/
    fbdoc.bas
    inc/
        autodoc.bas    callgraph.bas    declares.bi    doccomment.bas
        files.bas      globales.bas     help.bas       layout.bas
        out_graph.bas  out_html.bas     out_text.bas    parser.bas
        tokenizer.base types.bi         util.bas
msxbasicdoc/
    msxbasicdoc.bas
    inc/
        mbd_globals.bi   mbd_util.bi    mbd_lexer.bi   mbd_load.bi
        mbd_analyse.bi   mbd_flow.bi    mbd_html.bi    mbd_svg.bi
LICENSE
CHANGELOG.md
README.md
```

## Compileren

Je hebt de [FreeBASIC-compiler](https://www.freebasic.net/) (`fbc`) nodig.

```sh
cd fbdoc
fbc -lang fblite -s console fbdoc.bas

cd ../msxbasicdoc
fbc -lang fblite msxbasicdoc.bas
```

Werkt op Linux en Windows; het padscheidingsteken wordt bij het compileren gekozen.

---

## fbdoc

Een soort javadoc voor FreeBASIC. fbdoc scant mappen (recursief), leest het commentaar boven elke declaratie en maakt daar documentatie van, inclusief een aanroepgraaf.

### Wat het doet

- Documenteert `Sub`, `Function`, `Property`, `Constructor`, `Destructor`, `Operator`, `Type`, `Union`, `Enum`, `Namespace`, `Const`, `Dim`/`Common`/`Extern`, `#define` en `#macro`
- Leest commentaar met een apostrof (`'` of `''`), `Rem` en `/' ... '/`-blokken (ook genest)
- Ondersteunt tags: `@param` `@return` `@returns` `@throws` `@author` `@since` `@see` `@deprecated` `@brief` `@note`
- Ontbreekt commentaar, dan wordt een beschrijving afgeleid uit de naam, de parameters en het returntype (gemarkeerd als *auto*)
- Bouwt een aanroepgraaf, ook voor aanroepen zonder haakjes (`MijnSub a, b`) en procedurepointers (`@proc`)
- Rapporteert documentatiedekking, onopgeloste aanroepen en mogelijk ongebruikte code
- Volgt desgewenst `#include`-bestanden om aanroepen op te lossen, zonder die bestanden zelf te documenteren

### Commentaar schrijven

```freebasic
'' Telt twee getallen op.
'' Langere uitleg mag op de volgende regels.
'' @param a  eerste getal
'' @param b  tweede getal
'' @return de som van a en b
'' @since 1.0
Function Som(ByVal a As Integer, ByVal b As Integer) As Integer
    Return a + b
End Function
```

De eerste zin wordt de korte omschrijving, de rest komt in de details.

### Gebruik

```
fbdoc [opties] <pad> [pad2 ...]
```

| Optie | Betekenis |
|---|---|
| `-o`, `--output <bestand>` | uitvoer naar bestand (anders stdout) |
| `-f`, `--format <fmt>` | `text` \| `md` \| `html` \| `json` \| `dot` \| `mermaid` \| `tree` (standaard `text`) |
| `-l`, `--lang <nl\|en>` | taal van gegenereerde teksten (standaard `nl`) |
| `-n`, `--name <naam>` | projectnaam in de kop |
| `-e`, `--ext <lijst>` | extensies, kommagescheiden (standaard `.bas,.bi`) |
| `-x`, `--exclude <patroon>` | pad uitsluiten (meerdere keren toegestaan) |
| `--no-private` | alleen publieke functies |
| `-R`, `--no-recursive` | niet recursief scannen |
| `-G`, `--no-generate` | geen beschrijvingen genereren |
| `-u`, `--undocumented` | alleen elementen zonder commentaar tonen |
| `-c`, `--coverage` | dekkingsoverzicht tonen |
| `--fail-under <pct>` | exitcode 1 bij dekking onder pct (handig in CI) |
| `--split` | HTML verdeeld over losse pagina's in een map (met `-f html`) |
| `--follow` | `#include`-bestanden meelezen als referentie |
| `-i`, `--include <map>` | zoekpad voor `#include` |
| `--follow-depth <n>` | hoe diep includes volgen (standaard 2) |
| `--refs <pad>` | extra code meelezen voor naamresolutie |
| `--ref-depth <n>` | hoeveel stappen referentiecode in het diagram (standaard 1) |
| `--extern` | ook onopgeloste aanroepen tonen |
| `--depth <n>` | maximale diepte van de aanroepboom (standaard 12) |
| `-q`, `-v`, `-d` | stil, uitgebreid, debug |
| `--log <bestand>` | meldingen ook naar een logbestand |
| `-h`, `--help`, `--version` | hulp en versie |

### Voorbeelden

```sh
fbdoc -f html -o api.html -n "Mijn project" ./src
fbdoc -f html --split -o docs --follow -i inc ./src
fbdoc -f md -o API.md ./src
fbdoc -u -c --fail-under 60 ./src
fbdoc -f tree -o calls.txt ./src
fbdoc -f dot -o calls.dot ./src && dot -Tsvg calls.dot -o calls.svg
```

De HTML-uitvoer bevat een zoombaar, versleepbaar aanroepdiagram, een filter in de navigatie en een donkere modus die de systeeminstelling volgt.

---

## msxbasicdoc

Brengt de structuur van een MSX-BASIC-programma in kaart door `GOTO`, `GOSUB`, `RETURN` en verwante sprongen te volgen, en maakt daar één HTML-pagina van.

### Wat het doet

- Deelt het programma op in routines op basis van sprongdoelen
- Toont welke routine welke aanroept, met een aanroepgraaf (SVG in de HTML, optioneel Graphviz)
- Bepaalt welke regels bereikbaar zijn
- Maakt een overzicht van gebruikte variabelen (met `DEFINT`/`DEFSTR`/... in acht genomen)
- Geeft waarschuwingen, bijvoorbeeld bij sprongen naar niet-bestaande regels

### Invoer

Het programma moet als **ASCII** zijn opgeslagen. Op de MSX:

```
SAVE "NAAM.BAS",A
```

Een getokeniseerd bestand wordt herkend en geweigerd met een melding.

### Commentaar schrijven

```
10 '## Kleuren - klein demoprogramma
20 ' Laat zien hoe msxbasicdoc commentaar oppikt.
30 GOSUB 1000
40 END
1000 '## TekenRand - tekent een rand om het scherm
1010 '@in  K = kleur
1020 '@uit niets
1030 ' Wist eerst het scherm.
1040 CLS
1050 RETURN
```

| Vorm | Betekenis |
|---|---|
| `'## Naam - omschrijving` | naam van de routine; bovenaan het programma: titel van het programma |
| `'@tag waarde` | vrije tags, bijvoorbeeld `'@in X,Y` of `'@uit A$` |
| `' tekst` | omschrijving |

### Gebruik

```
msxbasicdoc [opties] PROGRAMMA.BAS [...]
```

| Optie | Betekenis |
|---|---|
| `-o MAP` | uitvoer in MAP (standaard naast het bronbestand) |
| `-dot` | ook een Graphviz `.dot`-bestand maken |
| `-q` | stil: alleen fouten tonen |
| `-h` | hulp |

Per bestand ontstaat `PROGRAMMA.html` (en met `-dot` ook `PROGRAMMA.dot`).

---

## Licentie

Copyright © 2026 Marcel "SmartDuck" Beekman

Uitgebracht onder de [3-clause BSD-licentie](https://opensource.org/license/bsd-3-clause).
Je mag de tools vrij gebruiken, aanpassen en verspreiden, ook commercieel, zolang de
copyrightvermelding en licentietekst behouden blijven. Zie [`LICENSE`](LICENSE) voor de
volledige tekst.

---

## In English

Two command-line tools that generate documentation from BASIC source code, both written in FreeBASIC with no external dependencies.

**fbdoc** is a javadoc-style generator for FreeBASIC. It reads the comment above each declaration (`'`, `Rem` or `/' ... '/`), supports `@param`, `@return`, `@see` and other tags, generates descriptions where comments are missing, builds a call graph, and reports documentation coverage and possibly unused code. Output formats: text, Markdown, HTML (single page or split), JSON, Graphviz, Mermaid and a call tree. Use `-l en` for English generated text. Run `fbdoc --help` for all options.

**msxbasicdoc** maps the structure of an MSX-BASIC program by following `GOTO`/`GOSUB`/`RETURN`. It splits the program into routines, draws a call graph, lists variables, checks reachability and warns about jumps to missing lines. Input must be saved as ASCII on the MSX (`SAVE "NAME.BAS",A`). Name routines with `'## Name - description` and add tags with `'@tag value`.

Build:

```sh
fbc -lang fblite -s console fbdoc/fbdoc.bas
fbc -lang fblite msxbasicdoc/msxbasicdoc.bas
```

Released under the 3-clause BSD license, copyright © 2026 Marcel "SmartDuck" Beekman.
See [`LICENSE`](LICENSE).
