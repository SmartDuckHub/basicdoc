# Changelog

Alle noemenswaardige wijzigingen in dit project staan in dit bestand.

Het formaat is gebaseerd op [Keep a Changelog](https://keepachangelog.com/nl/1.1.0/)
en de versienummering volgt [Semantic Versioning](https://semver.org/lang/nl/).
Elke tool heeft een eigen versienummer.

---

## fbdoc

### [1.1.0] - 2026-10-23

#### Toegevoegd
- Ondersteuning voor vertalingen: een vertaling is een gettext `.po`-bestand in de map `lang`
  naast het programma
- `-l`/`--lang` accepteert een taalcode (`-l nl` laadt `lang/nl.po`) of het pad naar een
  `.po`-bestand; staat het bestand niet naast het programma, dan wordt `lang/<code>.po`
  in de huidige map geprobeerd
- Omgevingsvariabele `FBDOC_LANG` voor de standaardtaal
- `lang/fbdoc.pot` als sjabloon voor nieuwe vertalingen
- `lang/nl.po` met de Nederlandse vertaling
- Het `lang`-attribuut van de HTML volgt de gekozen taal (uit de `Language:`-kop van het
  `.po`-bestand, of anders de taalcode)

#### Gewijzigd
- Engels is de standaardtaal (was Nederlands); `-l nl` geeft het oude gedrag
- `-l` vertaalt nu alle teksten: meldingen, `--help` en de labels in de uitvoer als `text`,
  `md`, `html`, `dot` en `mermaid`; voorheen alleen de automatisch afgeleide beschrijvingen
- Automatisch afgeleide beschrijvingen gebruiken hele zinnen met plaatshouders
  (`Retrieves %1.` / `Haalt %1 op.`), zodat een vertaling de woordvolgorde zelf kiest
- De broncode is opgesplitst in include-bestanden in de map `inc`; `fbdoc.bas` bevat
  alleen nog het hoofdprogramma
- Diagnose-uitvoer van `-d` is altijd Engels

#### Opgelost
- Een voorbeeld in `--help` schreef naar `egldoc.json` in plaats van `fbdoc.json`

### [1.0.0] - 2026-10-16

Eerste publieke versie.

#### Toegevoegd
- Recursief scannen van `.bas`- en `.bi`-bestanden, met uitsluitpatronen en instelbare extensies
- Herkenning van `Sub`, `Function`, `Property`, `Constructor`, `Destructor`, `Operator`,
  `Type`, `Union`, `Enum`, `Namespace`, `Const`, `Dim`/`Common`/`Extern`, `#define` en `#macro`
- Commentaar via apostrof, `Rem` en geneste `/' ... '/`-blokken
- Tags `@param`, `@return`/`@returns`, `@throws`, `@author`, `@since`, `@see`,
  `@deprecated`, `@brief`; onbekende tags worden als detail bewaard
- Automatisch afgeleide beschrijvingen bij ontbrekend commentaar, in het Nederlands of Engels
- Aanroepgraaf, inclusief aanroepen zonder haakjes en procedurepointers (`@proc`)
- Uitvoerformaten: `text`, `md`, `html`, `json`, `dot`, `mermaid` en `tree`
- HTML als één pagina of met `--split` als map met losse pagina's
- Interactief SVG-diagram in de HTML: slepen, zoomen en relaties uitlichten
- Donkere modus in de HTML op basis van de systeeminstelling
- Overzichten van documentatiedekking, onopgeloste aanroepen en mogelijk ongebruikte code
- `--fail-under` voor gebruik in CI
- `--follow`, `-i` en `--refs` om ingesloten of externe code mee te lezen voor naamresolutie
- `--log` en `-d` voor diagnose

---

## msxbasicdoc

### [0.4.0] - 2026-10-23

#### Toegevoegd
- Ondersteuning voor vertalingen: een vertaling is een gettext `.po`-bestand in de map `lang`
  naast het programma
- Optie `-l`/`--lang` met een taalcode (`-l nl` laadt `lang/nl.po`) of het pad naar een
  `.po`-bestand; staat het bestand niet naast het programma, dan wordt `lang/<code>.po`
  in de huidige map geprobeerd
- Omgevingsvariabele `MSXBASICDOC_LANG` voor de standaardtaal
- `lang/msxbasicdoc.pot` als sjabloon voor nieuwe vertalingen
- `lang/nl.po` met de Nederlandse vertaling
- Het `lang`-attribuut van de HTML volgt de gekozen taal

#### Gewijzigd
- Engels is de standaardtaal (was Nederlands); `-l nl` geeft het oude gedrag
- Datumnotatie en decimaalteken komen uit de vertaling; in het Engels `jjjj-mm-dd` en een punt
- Geldige UTF-8 in de HTML-uitvoer blijft behouden, zodat bijvoorbeeld Japanse of Spaanse
  vertalingen goed worden weergegeven; losse bytes uit de MSX-tekenset worden nog steeds als
  numerieke entiteit geschreven
- Namen in de aanroepgraaf worden afgekapt op schermbreedte in tekens in plaats van bytes;
  Oost-Aziatische tekens tellen dubbel

### [0.3.0] - 2026-10-16

Eerste publieke versie.

#### Toegevoegd
- Inlezen van ASCII-opgeslagen MSX-BASIC; getokeniseerde bestanden worden herkend en geweigerd
- Opdeling in routines aan de hand van `GOTO`, `GOSUB`, `RETURN` en verwante sprongen
- Aanroepgraaf als SVG in de HTML, optioneel als Graphviz-bestand (`-dot`)
- Bereikbaarheidsanalyse en variabelenoverzicht, rekening houdend met `DEF`-typen
- Waarschuwingen, onder andere voor sprongen naar niet-bestaande regels
- Documentatieconventies `'## Naam - omschrijving`, `'@tag waarde` en vrije commentaartekst
- Opties `-o`, `-q` en meerdere bestanden in één aanroep
