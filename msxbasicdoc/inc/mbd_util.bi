'' ============================================================
'' msxbasicdoc - hulpfuncties
'' ============================================================

Function IsDigitC(ByVal c As Integer) As Integer
    IsDigitC = (c >= 48 And c <= 57)
End Function

Function IsAlphaC(ByVal c As Integer) As Integer
    IsAlphaC = ((c >= 65 And c <= 90) Or (c >= 97 And c <= 122))
End Function

Function NStr(ByVal n As Long) As String
    NStr = LTrim(Str(n))
End Function

'' Lengte in bytes van het teken op positie i: 2-4 voor een geldige
'' UTF-8-reeks, anders 1 (ASCII, of een losse byte uit de MSX-tekenset).
Function U8Len(ByRef s As String, ByVal i As Integer) As Integer
    Dim c As Integer, L As Integer, k As Integer, ok As Integer
    c = Asc(s, i)
    L = 1
    If c >= &hC2 And c <= &hDF Then
        L = 2
    ElseIf c >= &hE0 And c <= &hEF Then
        L = 3
    ElseIf c >= &hF0 And c <= &hF4 Then
        L = 4
    End If
    If L > 1 Then
        ok = 1
        If i + L - 1 > Len(s) Then
            ok = 0
        Else
            For k = 1 To L - 1
                If Asc(s, i + k) < &h80 Or Asc(s, i + k) > &hBF Then ok = 0
            Next
        End If
        If ok = 0 Then L = 1
    End If
    U8Len = L
End Function

'' Schermbreedte van een teken met bytelengte L: Oost-Aziatische tekens
'' (kana, kanji, hangul en verder) zijn twee posities breed.
Function U8Width(ByRef s As String, ByVal i As Integer, ByVal L As Integer) As Integer
    U8Width = 1
    If L = 4 Then U8Width = 2
    If L = 3 And Asc(s, i) >= &hE3 Then U8Width = 2
End Function

'' Geldige UTF-8 (bijv. uit een vertaling) blijft staan; losse bytes vanaf
'' 128 (MSX-tekenset) worden een numerieke entiteit, zoals voorheen.
Function HtmlEsc(ByRef s As String) As String
    Dim r As String, i As Integer, c As Integer, L As Integer
    r = "" : i = 1
    Do While i <= Len(s)
        c = Asc(s, i)
        L = 1
        Select Case c
        Case 38
            r &= "&amp;"
        Case 60
            r &= "&lt;"
        Case 62
            r &= "&gt;"
        Case 34
            r &= "&quot;"
        Case Is >= 128
            L = U8Len(s, i)
            If L > 1 Then
                r &= Mid(s, i, L)
            Else
                r &= "&#" & LTrim(Str(c)) & ";"
            End If
        Case Else
            r &= Chr(c)
        End Select
        i += L
    Loop
    HtmlEsc = r
End Function

'' Vervangt elk voorkomen van a door b
Function ReplaceAll(ByRef s As String, ByRef a As String, ByRef b As String) As String
    Dim r As String, p As Integer, q As Integer
    r = "" : p = 1
    Do
        q = InStr(p, s, a)
        If q = 0 Then Exit Do
        r &= Mid(s, p, q - p) & b
        p = q + Len(a)
    Loop
    r &= Mid(s, p)
    ReplaceAll = r
End Function

'' Verwijdert sierranden als '=====', '-----', '*****' rondom commentaar
Function StripDeco(ByRef s As String) As String
    Dim t As String, deco As String
    deco = " =-*#~_+/\|<>" & Chr(9)
    t = s
    Do While Len(t) > 0
        If InStr(deco, Left(t, 1)) > 0 Then t = Mid(t, 2) Else Exit Do
    Loop
    Do While Len(t) > 0
        If InStr(deco, Right(t, 1)) > 0 Then t = Left(t, Len(t) - 1) Else Exit Do
    Loop
    StripDeco = t
End Function

'' Positie van de ':' die een DATA-statement afsluit (of Len+1)
Function DataEnd(ByRef s As String, ByVal p As Integer) As Integer
    Dim inq As Integer, c As Integer
    inq = 0
    Do While p <= Len(s)
        c = Asc(s, p)
        If c = 34 Then
            inq = Not inq
        ElseIf c = 58 And inq = 0 Then
            Exit Do
        End If
        p += 1
    Loop
    DataEnd = p
End Function

'' Binair zoeken naar regelnummer -> regelindex (of -1)
Function FindLine(ByVal num As Long) As Integer
    Dim lo As Integer, hi As Integer, md As Integer
    lo = 0 : hi = gNL - 1
    Do While lo <= hi
        md = (lo + hi) \ 2
        If gLnNum(md) = num Then
            FindLine = md : Exit Function
        ElseIf gLnNum(md) < num Then
            lo = md + 1
        Else
            hi = md - 1
        End If
    Loop
    FindLine = -1
End Function

Sub AddWarn(ByVal li As Integer, ByRef txt As String)
    Dim w As Integer
    For w = 0 To gNW - 1
        If gWText(w) = txt Then Exit Sub
    Next
    ReDim Preserve gWLine(0 To gNW)
    ReDim Preserve gWText(0 To gNW)
    gWLine(gNW) = li
    gWText(gNW) = txt
    gNW += 1
End Sub

Function LineLink(ByVal li As Integer) As String
    Dim n As String
    n = NStr(gLnNum(li))
    LineLink = "<a href=""#L" & n & """>" & n & "</a>"
End Function

Function TypeName(ByRef ty As String) As String
    Select Case ty
    Case "$"
        TypeName = "string"
    Case "%"
        TypeName = "integer"
    Case "!"
        TypeName = "single"
    Case Else
        TypeName = "double"
    End Select
End Function

'' Spellingen "|A|B|" -> "A, B"
Function Spellings(ByRef s As String) As String
    Dim t As String
    t = s
    If Left(t, 1) = "|" Then t = Mid(t, 2)
    If Right(t, 1) = "|" Then t = Left(t, Len(t) - 1)
    Spellings = ReplaceAll(t, "|", ", ")
End Function

Function CountSpellings(ByRef s As String) As Integer
    Dim i As Integer, n As Integer
    n = 0
    For i = 1 To Len(s)
        If Asc(s, i) = 124 Then n += 1
    Next
    CountSpellings = n - 1
End Function

'' Datum van vandaag; de volgorde komt uit de vertaling (standaard jjjj-mm-dd)
Function TodayTxt() As String
    Dim d As String
    d = Date   '' mm-dd-yyyy
    TodayTxt = Tr3("%1-%2-%3", Right(d, 4), Left(d, 2), Mid(d, 4, 2))
End Function

'' Percentage met een decimaal; het decimaalteken komt uit de vertaling
Function Pct1(ByVal a As Integer, ByVal b As Integer) As String
    Dim p As Long
    If b = 0 Then
        Pct1 = "0" : Exit Function
    End If
    p = (CLng(a) * 1000 + b \ 2) \ b
    Pct1 = Tr2("%1.%2", NStr(p \ 10), NStr(p Mod 10))
End Function
