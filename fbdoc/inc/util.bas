'' =====================================================================
''  fbdoc - Algemene helpers: meldingen, strings, escapes en paden
'' =====================================================================

Function LC(ByRef s As String) As String
    LC = LCase(s)
End Function

'' Alle meldingen lopen via Say: naar de console en, als er een logbestand
'' is geopend, ook daarheen. Zo blijft diagnose mogelijk wanneer de console
'' onbruikbaar is (bijv. GUI-subsystem of een IDE die uitvoer opslokt).
Sub Say(ByRef s As String)
    Print s
    If logH > 0 Then
        Print #logH, s
    End If
End Sub

'' Zoekt --log/-L in de argumenten voordat de rest wordt verwerkt, zodat
'' ook de eerste meldingen in het logbestand terechtkomen.
Sub OpenLogEarly()
    Dim As Integer a
    Dim As String t, v
    a = 1
    Do
        t = Command(a)
        If Len(t) = 0 Then Exit Do
        If LCase(t) = "--log" Then
            v = Command(a + 1)
            If Len(v) > 0 Then
                logH = FreeFile
                If Open(v For Output As #logH) <> 0 Then
                    logH = 0
                End If
            End If
            Exit Do
        End If
        a = a + 1
    Loop
End Sub

'' eenvoudige vervanging voor Format() zodat vbcompat.bi niet nodig is
Function Fmt1(ByVal d As Double) As String
    Dim As Integer whole, dec1
    Dim As String sg
    sg = ""
    If d < 0 Then
        sg = "-"
        d = -d
    End If
    whole = Int(d)
    dec1 = Int((d - whole) * 10 + 0.5)
    If dec1 >= 10 Then
        whole = whole + 1
        dec1 = 0
    End If
    Return sg & Str(whole) & "." & Str(dec1)
End Function

Function IsIdentCh(ByRef c As String) As Integer
    Dim As Integer a
    a = Asc(c)
    If (a >= 65 And a <= 90) Or (a >= 97 And a <= 122) Then Return -1
    If a >= 48 And a <= 57 Then Return -1
    If c = "_" Then Return -1
    Return 0
End Function

Function IsDigitCh(ByRef c As String) As Integer
    Dim As Integer a
    a = Asc(c)
    If a >= 48 And a <= 57 Then Return -1
    Return 0
End Function

Function ReplaceAll(ByRef s As String, ByRef f As String, ByRef r As String) As String
    Dim As String res
    Dim As Integer p, q, lf
    lf = Len(f)
    If lf = 0 Then Return s
    res = ""
    q = 1
    Do
        p = InStr(q, s, f)
        If p = 0 Then Exit Do
        res = res & Mid(s, q, p - q) & r
        q = p + lf
    Loop
    res = res & Mid(s, q)
    Return res
End Function

Function HtmlEsc(ByRef s As String) As String
    Dim As String t
    t = ReplaceAll(s, "&", "&amp;")
    t = ReplaceAll(t, "<", "&lt;")
    t = ReplaceAll(t, ">", "&gt;")
    t = ReplaceAll(t, Chr(34), "&quot;")
    Return t
End Function

Function JsonEsc(ByRef s As String) As String
    Dim As String t
    t = ReplaceAll(s, "\", "\\")
    t = ReplaceAll(t, Chr(34), "\" & Chr(34))
    t = ReplaceAll(t, Chr(13), "")
    t = ReplaceAll(t, Chr(10), "\n")
    t = ReplaceAll(t, Chr(9), "\t")
    Return t
End Function

Function NormSep(ByRef s As String) As String
    Return ReplaceAll(s, "\", "/")
End Function

Function PathBase(ByRef s As String) As String
    Dim As String t
    Dim As Integer i
    t = NormSep(s)
    For i = Len(t) To 1 Step -1
        If Mid(t, i, 1) = "/" Then Return Mid(t, i + 1)
    Next i
    Return t
End Function

Function PathExtOf(ByRef s As String) As String
    Dim As String b
    Dim As Integer i
    b = PathBase(s)
    For i = Len(b) To 1 Step -1
        If Mid(b, i, 1) = "." Then Return LC(Mid(b, i))
    Next i
    Return ""
End Function

Function ExtWanted(ByRef fn As String) As Integer
    Dim As String e
    e = PathExtOf(fn)
    If Len(e) = 0 Then Return 0
    If InStr(opt.extList, ";" & e & ";") > 0 Then Return -1
    Return 0
End Function

Function IsExcluded(ByRef p As String) As Integer
    Dim As String t, pat
    Dim As Integer q, r
    t = LC(NormSep(p))
    q = 1
    Do
        r = InStr(q + 1, opt.exclList, ";")
        If r = 0 Then Exit Do
        pat = Mid(opt.exclList, q + 1, r - q - 1)
        If Len(pat) > 0 Then
            If InStr(t, LC(pat)) > 0 Then Return -1
        End If
        q = r
    Loop
    Return 0
End Function

Function IsDirPath(ByRef p As String) As Integer
    Dim As Long oa, m
    Dim As String f, t
    t = p
    If Len(t) > 1 And Right(t, 1) = PSEP Then t = Left(t, Len(t) - 1)
    If Len(t) > 1 And Right(t, 1) = "/" Then t = Left(t, Len(t) - 1)
    m = ATTR_ALL
    oa = 0
    f = Dir(t, m, oa)
    If opt.debugOn Then
        Say "  [dbg] Dir(" & t & ") -> " & Chr(34) & f & Chr(34) & " attr=&h" & Hex(oa)
    End If
    If Len(f) > 0 Then
        If (oa And ATTR_DIR) <> 0 Then Return -1
    End If
    '' terugvalcontrole: bestaat er iets binnen dit pad?
    oa = 0
    f = Dir(t & PSEP & "*", m, oa)
    If opt.debugOn Then
        Say "  [dbg] Dir(" & t & PSEP & "*) -> " & Chr(34) & f & Chr(34) & " attr=&h" & Hex(oa)
    End If
    If Len(f) > 0 Then Return -1
    Return 0
End Function
