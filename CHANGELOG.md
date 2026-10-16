# Changelog

Alle noemenswaardige wijzigingen in dit project staan in dit bestand.

Het formaat is gebaseerd op [Keep a Changelog](https://keepachangelog.com/nl/1.1.0/)
en de versienummering volgt [Semantic Versioning](https://semver.org/lang/nl/).
Elke tool heeft een eigen versienummer.

---

## fbdoc

### [Unreleased]

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

### [Unreleased]

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

[Unreleased]: https://github.com/SmartDuckHub/REPO/compare/v1.0.0...HEAD
