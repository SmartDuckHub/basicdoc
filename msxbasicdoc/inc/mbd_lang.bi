'' ============================================================
'' msxbasicdoc - vertalingen
''
'' Alle teksten staan in het Engels in de broncode. Een vertaling is
'' een .po-bestand (gettext-formaat) in de map lang naast het
'' programma, bijvoorbeeld lang/nl.po. Kiezen gaat met -l nl, met
'' -l pad/naar/xx.po of met de omgevingsvariabele MSXBASICDOC_LANG.
''
'' Tr(s) geeft de vertaling van s, of s zelf als die ontbreekt.
'' Tr1, Tr2 en Tr3 vullen daarna %1, %2 en %3 in, zodat een
'' vertaling de woordvolgorde vrij kan kiezen.
''
'' Van het .po-formaat wordt gebruikt: msgid, msgstr, vervolgregels
'' die met een aanhalingsteken beginnen, de escapes \" \\ \n \t en de
'' vlag #, fuzzy (die vertaling wordt overgeslagen, net als bij
'' gettext). msgctxt en meervoudsvormen worden genegeerd.
''
'' Deze module gebruikt niets uit de andere modules, zodat hij als
'' eerste na de globals geladen kan worden.
'' ============================================================

Dim Shared trKey() As String
Dim Shared trVal() As String
Dim Shared trHashV() As Long
Dim Shared trCount As Integer, trCap As Integer
Dim Shared langCode As String

'' Eenvoudige hash, zodat bij het opzoeken eerst een getal wordt
'' vergeleken in plaats van een hele string.
Function TrHash(ByRef s As String) As Long
    Dim h As Long, i As Integer
    h = 0
    For i = 1 To Len(s)
        h = ((h * 31) + Asc(s, i)) And &hFFFFFF
    Next
    TrHash = h
End Function

Sub TrAdd(ByRef k As String, ByRef v As String)
    Dim i As Integer, h As Long
    h = TrHash(k)
    '' dubbele msgid: de laatste wint
    For i = 1 To trCount
        If trHashV(i) = h Then
            If trKey(i) = k Then
                trVal(i) = v
                Exit Sub
            End If
        End If
    Next
    If trCount >= trCap Then
        trCap += 256
        ReDim Preserve trKey(1 To trCap)
        ReDim Preserve trVal(1 To trCap)
        ReDim Preserve trHashV(1 To trCap)
    End If
    trCount += 1
    trKey(trCount) = k
    trVal(trCount) = v
    trHashV(trCount) = h
End Sub

Function Tr(ByRef s As String) As String
    Dim i As Integer, h As Long
    Tr = s
    If trCount = 0 Then Exit Function
    h = TrHash(s)
    For i = 1 To trCount
        If trHashV(i) = h Then
            If trKey(i) = s Then
                Tr = trVal(i)
                Exit Function
            End If
        End If
    Next
End Function

'' Vult %1, %2 en %3 in. Een % zonder cijfer erachter blijft staan.
Function TrFill(ByRef t As String, ByRef a As String, ByRef b As String, ByRef c As String) As String
    Dim res As String, ch As String, dg As String, i As Integer, n As Integer
    res = "" : n = Len(t) : i = 1
    Do While i <= n
        ch = Mid(t, i, 1)
        dg = ""
        If ch = "%" And i < n Then dg = Mid(t, i + 1, 1)
        If dg = "1" Then
            res &= a : i += 2
        ElseIf dg = "2" Then
            res &= b : i += 2
        ElseIf dg = "3" Then
            res &= c : i += 2
        Else
            res &= ch : i += 1
        End If
    Loop
    TrFill = res
End Function

Function Tr1(ByRef s As String, ByRef a As String) As String
    Tr1 = TrFill(Tr(s), a, "", "")
End Function

Function Tr2(ByRef s As String, ByRef a As String, ByRef b As String) As String
    Tr2 = TrFill(Tr(s), a, b, "")
End Function

Function Tr3(ByRef s As String, ByRef a As String, ByRef b As String, ByRef c As String) As String
    Tr3 = TrFill(Tr(s), a, b, c)
End Function

'' Haalt de aanhalingstekens weg en verwerkt de escapes van een .po-string.
Function PoUnq(ByRef src As String) As String
    Dim t As String, res As String, ch As String, i As Integer, n As Integer
    t = Trim(src)
    If Left(t, 1) = Chr(34) Then t = Mid(t, 2)
    If Right(t, 1) = Chr(34) Then t = Left(t, Len(t) - 1)
    res = "" : n = Len(t) : i = 1
    Do While i <= n
        ch = Mid(t, i, 1)
        If ch = "\" And i < n Then
            i += 1
            ch = Mid(t, i, 1)
            If ch = "n" Then
                ch = Chr(10)
            ElseIf ch = "t" Then
                ch = Chr(9)
            ElseIf ch = "r" Then
                ch = ""
            End If
        End If
        res &= ch
        i += 1
    Loop
    PoUnq = res
End Function

'' Slaat een gelezen msgid/msgstr-paar op en maakt de buffers leeg.
'' De lege msgid is de kop van het bestand; daaruit komt de taalcode.
'' Geeft -1 terug als er een vertaling bij is gekomen.
Function PoFlush(ByRef msgId As String, ByRef msgStr As String, ByRef fuzzy As Integer) As Integer
    Dim added As Integer, p As Integer, i As Integer, hd As String
    added = 0
    If Len(msgId) = 0 Then
        p = InStr(msgStr, "Language:")
        If p > 0 Then
            hd = Mid(msgStr, p + 9)
            p = InStr(hd, Chr(10))
            If p > 0 Then hd = Left(hd, p - 1)
            hd = Trim(hd)
            For i = 1 To Len(hd)
                If Mid(hd, i, 1) = "_" Then Mid(hd, i, 1) = "-"
            Next
            If Len(hd) > 0 Then langCode = hd
        End If
    ElseIf Len(msgStr) > 0 And fuzzy = 0 Then
        TrAdd msgId, msgStr
        added = -1
    End If
    msgId = "" : msgStr = "" : fuzzy = 0
    PoFlush = added
End Function

'' Leest een .po-bestand. Geeft het aantal vertalingen terug, of -1
'' als het bestand niet te openen is.
Function LoadPo(ByRef poPath As String) As Integer
    Dim fh As Integer, mode As Integer, fuzzy As Integer, pend As Integer, n As Integer
    Dim ln As String, msgId As String, msgStr As String
    LoadPo = -1
    fh = FreeFile
    If Open(poPath For Input As #fh) <> 0 Then Exit Function
    n = 0 : mode = 0 : pend = 0 : fuzzy = 0
    msgId = "" : msgStr = ""
    Do Until Eof(fh)
        Line Input #fh, ln
        '' UTF-8 BOM van sommige editors overslaan
        If Left(ln, 3) = Chr(239, 187, 191) Then ln = Mid(ln, 4)
        If Right(ln, 1) = Chr(13) Then ln = Left(ln, Len(ln) - 1)
        ln = Trim(ln)
        '' een nieuw item begint: het vorige paar eerst opslaan
        If pend Then
            If Len(ln) = 0 Or Left(ln, 1) = "#" Or Left(ln, 5) = "msgid" Or Left(ln, 7) = "msgctxt" Then
                If PoFlush(msgId, msgStr, fuzzy) Then n += 1
                pend = 0 : mode = 0
            End If
        End If
        If Len(ln) = 0 Then
            mode = 0
        ElseIf Left(ln, 1) = "#" Then
            If Left(ln, 2) = "#," And InStr(ln, "fuzzy") > 0 Then fuzzy = -1
        ElseIf Left(ln, 7) = "msgctxt" Then
            mode = 0
        ElseIf Left(ln, 12) = "msgid_plural" Then
            mode = 0
        ElseIf Left(ln, 5) = "msgid" Then
            msgId = PoUnq(Mid(ln, 6)) : mode = 1
        ElseIf Left(ln, 9) = "msgstr[0]" Then
            msgStr = PoUnq(Mid(ln, 10)) : mode = 2 : pend = -1
        ElseIf Left(ln, 7) = "msgstr[" Then
            mode = 0
        ElseIf Left(ln, 6) = "msgstr" Then
            msgStr = PoUnq(Mid(ln, 7)) : mode = 2 : pend = -1
        ElseIf Left(ln, 1) = Chr(34) Then
            If mode = 1 Then msgId &= PoUnq(ln)
            If mode = 2 Then msgStr &= PoUnq(ln)
        End If
    Loop
    Close #fh
    If pend Then
        If PoFlush(msgId, msgStr, fuzzy) Then n += 1
    End If
    LoadPo = n
End Function

'' Bepaalt de taal voordat de opties worden verwerkt, zodat ook de
'' hulptekst al vertaald is. Volgorde: MSXBASICDOC_LANG, daarna
'' -l/--lang (de laatste telt). Een code zoals nl laadt lang/nl.po
'' naast het programma, en anders lang/nl.po in de huidige map. Een
'' waarde die op .po eindigt is een pad.
Sub LangEarly()
    Dim a As Integer, n As Integer, i As Integer
    Dim t As String, v As String, fp As String, tried As String
    v = Environ("MSXBASICDOC_LANG")
    a = 1
    Do
        t = Command(a)
        If Len(t) = 0 Then Exit Do
        If LCase(t) = "-l" Or LCase(t) = "--lang" Then
            If Len(Command(a + 1)) > 0 Then v = Command(a + 1)
            a += 1
        End If
        a += 1
    Loop

    v = Trim(v)
    langCode = "en"
    If Len(v) = 0 Or LCase(v) = "en" Then Exit Sub

    If LCase(Right(v, 3)) = ".po" Then
        fp = v
        '' taalcode = bestandsnaam zonder map en zonder .po
        t = Left(v, Len(v) - 3)
        For i = Len(t) To 1 Step -1
            If Mid(t, i, 1) = "/" Or Mid(t, i, 1) = "\" Then
                t = Mid(t, i + 1) : Exit For
            End If
        Next
        langCode = t
        tried = fp
        n = LoadPo(fp)
    Else
        langCode = LCase(v)
        fp = ExePath & "/lang/" & LCase(v) & ".po"
        tried = fp
        n = LoadPo(fp)
        If n < 0 Then
            fp = "lang/" & LCase(v) & ".po"
            tried &= ", " & fp
            n = LoadPo(fp)
        End If
    End If

    If n < 0 Then
        Print "Warning: no translation found for language '" & v & "'."
        Print "         Looked for: " & tried
        Print "         Continuing in English."
        langCode = "en"
    End If
End Sub
