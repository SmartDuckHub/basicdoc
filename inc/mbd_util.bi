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

Function HtmlEsc(ByRef s As String) As String
    Dim r As String, i As Integer, c As Integer
    r = ""
    For i = 1 To Len(s)
        c = Asc(s, i)
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
            r &= "&#" & LTrim(Str(c)) & ";"
        Case Else
            r &= Chr(c)
        End Select
    Next
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

Function TodayNL() As String
    Dim d As String
    d = Date   '' mm-dd-yyyy
    TodayNL = Mid(d, 4, 2) & "-" & Left(d, 2) & "-" & Right(d, 4)
End Function

'' Percentage met een decimaal, Nederlandse notatie
Function Pct1(ByVal a As Integer, ByVal b As Integer) As String
    Dim p As Long
    If b = 0 Then
        Pct1 = "0" : Exit Function
    End If
    p = (CLng(a) * 1000 + b \ 2) \ b
    Pct1 = NStr(p \ 10) & "," & NStr(p Mod 10)
End Function
