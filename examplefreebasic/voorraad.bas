#include once "voorraad.bi"

'' Interne teller voor het aantal leesfouten.
Dim Shared leesFouten As Integer

'' Berekent de waarde van deze regel.
Function Artikel.Waarde() As Double
    Return aantal * prijs
End Function

'' Splitst een regel op puntkomma's.
''
'' @param regel de ruwe tekstregel
'' @param velden de gevonden velden
'' @return het aantal velden
Private Function SplitsRegel(ByRef regel As String, velden() As String) As Integer
    Dim As Integer n, p, q
    n = 0
    q = 1
    Do
        p = InStr(q, regel, ";")
        If p = 0 Then Exit Do
        n = n + 1
        ReDim Preserve velden(1 To n)
        velden(n) = Mid(regel, q, p - q)
        q = p + 1
    Loop
    Return n
End Function

Function LeesVoorraad(ByRef pad As String, lijst() As Artikel) As Integer
    Dim As Integer fh, n
    Dim As String regel, velden()

    fh = FreeFile
    If Open(pad For Input As #fh) <> 0 Then
        MeldFout("kan bestand niet openen: " & pad)
        Return -1
    End If
    n = 0
    While Not EOF(fh)
        Line Input #fh, regel
        If SplitsRegel(regel, velden) >= 4 Then
            n = n + 1
            ReDim Preserve lijst(1 To n)
            lijst(n).nummer = Val(velden(1))
            lijst(n).omschrijving = velden(2)
        End If
    Wend
    Close #fh
    Return n
End Function

Sub ToonVoorraad(lijst() As Artikel)
    Dim As Integer i
    For i = LBound(lijst) To UBound(lijst)
        Print lijst(i).nummer, lijst(i).omschrijving, lijst(i).Waarde()
    Next i
End Sub

'' Schrijft een foutmelding en houdt de teller bij.
Sub MeldFout(ByRef tekst As String)
    leesFouten = leesFouten + 1
    Print "FOUT: " & tekst
End Sub

'' Wordt nergens aangeroepen: kandidaat voor het opruimlijstje.
Private Sub OudeExportRoutine()
    Print "niet meer in gebruik"
End Sub

Dim Shared artikelen() As Artikel

If LeesVoorraad("voorraad.csv", artikelen) > 0 Then
    ToonVoorraad(artikelen)
End If
