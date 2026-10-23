'' ============================================================
'' msxbasicdoc - inlezen van een ASCII MSX-BASIC bestand
'' (SAVE "NAAM.BAS",A)
'' ============================================================

'' Resultaat: 0 = ok, -1 = kan niet openen, -2 = getokeniseerd bestand
Function LoadSource(ByRef fname As String) As Integer
    Dim h As Integer, sz As Long, buf As String
    Dim p As Long, q As Long, raw As String, cap As Integer
    Dim t As String, k As Integer, num As Long, srcLine As Integer
    Dim i As Integer, j As Integer, tn As Long, tt As String, dup As Integer
    Dim tmpNum() As Long, tmpText() As String, n As Integer

    h = FreeFile
    If Open(fname For Binary Access Read As #h) <> 0 Then
        LoadSource = -1 : Exit Function
    End If
    sz = LOF(h)
    buf = Space(sz)
    If sz > 0 Then Get #h, , buf
    Close #h

    If sz > 0 Then
        If Asc(buf, 1) = &HFF Then
            LoadSource = -2 : Exit Function
        End If
    End If

    '' Ctrl-Z (EOF-markering van MSX-DOS) en alles daarna weglaten
    p = InStr(buf, Chr(26))
    If p > 0 Then buf = Left(buf, p - 1)

    '' maximaal aantal regels bepalen
    cap = 1
    For p = 1 To Len(buf)
        If Asc(buf, p) = 10 Or Asc(buf, p) = 13 Then cap += 1
    Next
    ReDim tmpNum(0 To cap)
    ReDim tmpText(0 To cap)
    n = 0

    p = 1 : srcLine = 0
    Do While p <= Len(buf)
        q = p
        Do While q <= Len(buf)
            If Asc(buf, q) = 10 Or Asc(buf, q) = 13 Then Exit Do
            q += 1
        Loop
        raw = Mid(buf, p, q - p)
        '' CR LF / LF CR / losse CR of LF
        If q <= Len(buf) Then
            If q < Len(buf) Then
                If (Asc(buf, q) = 13 And Asc(buf, q + 1) = 10) Or (Asc(buf, q) = 10 And Asc(buf, q + 1) = 13) Then q += 1
            End If
        End If
        p = q + 1
        srcLine += 1

        t = LTrim(raw, Any " " & Chr(9))
        If Len(Trim(t)) = 0 Then Continue Do
        k = 1
        Do While k <= Len(t)
            If IsDigitC(Asc(t, k)) Then k += 1 Else Exit Do
        Loop
        If k = 1 Then
            AddWarn -1, Tr2("Source line %1 has no line number and was ignored: %2", NStr(srcLine), Left(Trim(t), 40))
            Continue Do
        End If
        num = CLng(Val(Left(t, k - 1)))
        t = Mid(t, k)
        If Left(t, 1) = " " Then t = Mid(t, 2)
        If num > 65529 Then
            AddWarn -1, Tr2("Line number %1 is greater than 65529 (source line %2)", NStr(num), NStr(srcLine))
        End If
        tmpNum(n) = num : tmpText(n) = t
        n += 1
    Loop

    '' sorteren (stabiel; meestal al gesorteerd) en dubbelen verwijderen
    For i = 1 To n - 1
        tn = tmpNum(i) : tt = tmpText(i)
        j = i - 1
        Do While j >= 0
            If tmpNum(j) <= tn Then Exit Do
            tmpNum(j + 1) = tmpNum(j) : tmpText(j + 1) = tmpText(j)
            j -= 1
        Loop
        If j + 1 <> i Then
            If j + 1 < i Then
                AddWarn -1, Tr1("Line %1 is out of order in the source file", NStr(tn))
            End If
        End If
        tmpNum(j + 1) = tn : tmpText(j + 1) = tt
    Next

    gNL = 0
    If n > 0 Then
        ReDim gLnNum(0 To n - 1)
        ReDim gLnText(0 To n - 1)
        For i = 0 To n - 1
            dup = 0
            If gNL > 0 Then
                If gLnNum(gNL - 1) = tmpNum(i) Then dup = 1
            End If
            If dup Then
                AddWarn -1, Tr1("Line %1 occurs more than once; the last version was used", NStr(tmpNum(i)))
                gLnText(gNL - 1) = tmpText(i)
            Else
                gLnNum(gNL) = tmpNum(i) : gLnText(gNL) = tmpText(i)
                gNL += 1
            End If
        Next
    End If

    '' overige regelarrays
    k = gNL
    If k < 1 Then k = 1
    ReDim gLnTk1(0 To k), gLnTkN(0 To k), gLnEd1(0 To k), gLnEdN(0 To k)
    ReDim gLnFalls(0 To k), gLnRet(0 To k), gLnEnd(0 To k), gLnRem(0 To k)
    ReDim gLnData(0 To k), gLnTarget(0 To k), gLnOwners(0 To k), gLnEntry(0 To k)

    '' tokenruimte: nooit meer tokens dan tekens (+ marge)
    cap = Len(buf) + gNL * 2 + 64
    ReDim gTkType(0 To cap), gTkText(0 To cap), gTkVal(0 To cap)
    gNT = 0
    LoadSource = 0
End Function
