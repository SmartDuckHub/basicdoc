#ifndef VOORRAAD_BI
#define VOORRAAD_BI

'' Maximaal aantal artikelen in het magazijn.
Const MAX_ARTIKELEN = 5000

'' Status van een artikel in de voorraad.
Enum ArtikelStatus
    ST_ONBEKEND
    '' Artikel is leverbaar.
    ST_LEVERBAAR
    ST_UITVERKOCHT
End Enum

'' Eén regel uit de voorraadadministratie.
Type Artikel
    '' Uniek artikelnummer.
    nummer As Integer
    omschrijving As String
    aantal As Integer
    prijs As Double
    status As ArtikelStatus

    '' Berekent de waarde van deze regel.
    Declare Function Waarde() As Double
End Type

'' Leest de voorraad uit een bestand.
''
'' @param pad het volledige pad naar het CSV-bestand
'' @param lijst de gevulde artikelenlijst
'' @return het aantal ingelezen regels, of -1 bij een leesfout
Declare Function LeesVoorraad(ByRef pad As String, lijst() As Artikel) As Integer

Declare Sub ToonVoorraad(lijst() As Artikel)

#endif
