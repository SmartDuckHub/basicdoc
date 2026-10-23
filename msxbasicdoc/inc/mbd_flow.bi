'' ============================================================
'' msxbasicdoc - structuur afleiden
''
'' Elke GOSUB-doelregel is een routine. Vanaf die regel wordt de
'' flow gevolgd (doorvallen, GOTO, THEN/ELSE-regelnummer, ON..GOTO)
'' tot RETURN/END. GOSUB's worden niet ingevolgd maar als aanroep
'' vastgelegd. Ook ON <event> GOSUB en ON ERROR GOTO leveren ingangen.
'' ============================================================

Function EdgeKindName(ByVal k As Integer) As String
    Select Case k
    Case ED_GOTO
        EdgeKindName = "GOTO"
    Case ED_GOSUB
        EdgeKindName = "GOSUB"
    Case ED_THEN
        EdgeKindName = "THEN"
    Case ED_ELSE
        EdgeKindName = "ELSE"
    Case ED_ONGOTO
        EdgeKindName = "ON..GOTO"
    Case ED_ONGOSUB
        EdgeKindName = "ON..GOSUB"
    Case ED_RETURNTO
        EdgeKindName = "RETURN"
    Case ED_RESUME
        EdgeKindName = "RESUME"
    Case ED_RUN
        EdgeKindName = "RUN"
    Case ED_ONERROR
        EdgeKindName = "ON ERROR GOTO"
    Case ED_ONEVENT
        EdgeKindName = "ON..GOSUB (event)"
    Case ED_RESTORE
        EdgeKindName = "RESTORE"
    Case Else
        EdgeKindName = "?"
    End Select
End Function

Sub ResolveEdges()
    Dim e As Integer, x As Integer
    For e = 0 To gNE - 1
        x = FindLine(gEdNum(e))
        gEdTo(e) = x
        If x < 0 Then
            AddWarn gEdFrom(e), Tr3("Line %1: %2 refers to non-existent line %3", NStr(gLnNum(gEdFrom(e))), _
                EdgeKindName(gEdKind(e)), NStr(gEdNum(e)))
        Else
            gLnTarget(x) = 1
        End If
    Next
End Sub

Sub ResolveVars()
    Dim u As Integer, v As Integer, nm As String, sfx As String, bas As String
    Dim ty As String, key As String, c As Integer
    ReDim gVarKey(0 To gNU + 1), gVarNames(0 To gNU + 1), gVarType(0 To gNU + 1), gVarArr(0 To gNU + 1)
    gNV = 0
    For u = 0 To gNU - 1
        nm = gUsName(u)
        sfx = Right(nm, 1)
        If sfx = "$" Or sfx = "%" Or sfx = "!" Or sfx = "#" Then
            bas = Left(nm, Len(nm) - 1)
        Else
            bas = nm : sfx = ""
        End If
        ty = sfx
        If ty = "" Then
            c = Asc(bas, 1) - 65
            If c >= 0 And c <= 25 Then ty = gDefType(c)
            If ty = "" Then ty = "#"     '' MSX-BASIC standaard: dubbele precisie
        End If
        key = Left(bas, 2) & ty
        If gUsArr(u) Then key &= "()"

        v = -1
        For c = 0 To gNV - 1
            If gVarKey(c) = key Then
                v = c : Exit For
            End If
        Next
        If v < 0 Then
            v = gNV
            gVarKey(v) = key : gVarType(v) = ty : gVarArr(v) = gUsArr(u) : gVarNames(v) = "|"
            gNV += 1
        End If
        If InStr(gVarNames(v), "|" & nm & "|") = 0 Then gVarNames(v) &= nm & "|"
        gUsVar(u) = v
    Next
End Sub

Function AddEntry(ByVal li As Integer, ByVal kind As Integer, ByRef info As String) As Integer
    Dim e As Integer
    For e = 0 To gNEn - 1
        If gEnLine(e) = li Then
            If gEnKind(e) = EN_GOSUB And kind = EN_EVENT Then
                '' wordt zowel aangeroepen als als event gebruikt: subroutine houden
            End If
            If gEnKind(e) = EN_EVENT And Len(info) > 0 Then
                If InStr(gEnInfo(e), info) = 0 Then gEnInfo(e) &= ", " & info
            End If
            AddEntry = e : Exit Function
        End If
    Next
    e = gNEn
    gEnLine(e) = li : gEnKind(e) = kind : gEnInfo(e) = info
    gEnName(e) = "" : gEnDesc(e) = "" : gEnTags(e) = ""
    gNEn += 1
    AddEntry = e
End Function

Sub BuildEntries()
    Dim e As Integer, i As Integer, j As Integer, cap As Integer, d As Integer
    Dim tl As Integer, tk As Integer, ti As String
    cap = gNE + 2
    ReDim gEnLine(0 To cap), gEnKind(0 To cap), gEnInfo(0 To cap)
    ReDim gEnName(0 To cap), gEnDesc(0 To cap), gEnTags(0 To cap)
    ReDim gEnDocd(0 To cap), gEnReach(0 To cap), gEnHasCaller(0 To cap)
    gNEn = 0
    If gNL = 0 Then Exit Sub

    d = AddEntry(0, EN_MAIN, "")
    For e = 0 To gNE - 1
        If gEdTo(e) >= 0 Then
            Select Case gEdKind(e)
            Case ED_GOSUB, ED_ONGOSUB
                d = AddEntry(gEdTo(e), EN_GOSUB, "")
            Case ED_ONEVENT
                d = AddEntry(gEdTo(e), EN_EVENT, gEdInfo(e))
            Case ED_ONERROR
                d = AddEntry(gEdTo(e), EN_ERROR, "")
            End Select
        End If
    Next

    '' sorteren op regel (hoofdprogramma blijft eerst: regelindex 0)
    For i = 1 To gNEn - 1
        tl = gEnLine(i) : tk = gEnKind(i) : ti = gEnInfo(i)
        j = i - 1
        Do While j >= 0
            If gEnLine(j) <= tl Then Exit Do
            gEnLine(j + 1) = gEnLine(j) : gEnKind(j + 1) = gEnKind(j) : gEnInfo(j + 1) = gEnInfo(j)
            j -= 1
        Loop
        gEnLine(j + 1) = tl : gEnKind(j + 1) = tk : gEnInfo(j + 1) = ti
    Next

    For i = 0 To gNL - 1
        gLnEntry(i) = -1
    Next
    For e = 0 To gNEn - 1
        gLnEntry(gEnLine(e)) = e
    Next
End Sub

Sub ComputeMembership()
    Dim e As Integer, sp As Integer, x As Integer, k As Integer, y As Integer
    Dim mbase As Long
    Dim stk() As Integer

    If gNEn = 0 Then Exit Sub
    ReDim gMem(0 To CLng(gNEn) * gNL)
    ReDim stk(0 To gNL + 1)

    For e = 0 To gNEn - 1
        mbase = CLng(e) * gNL
        sp = 0
        stk(sp) = gEnLine(e) : sp += 1
        gMem(mbase + gEnLine(e)) = 1
        If gEnKind(e) = EN_MAIN Then
            '' RETURN n, RESUME n en RUN n zetten het hoofdprogramma voort
            For k = 0 To gNE - 1
                Select Case gEdKind(k)
                Case ED_RETURNTO, ED_RESUME, ED_RUN
                    y = gEdTo(k)
                    If y >= 0 Then
                        If gMem(mbase + y) = 0 Then
                            gMem(mbase + y) = 1 : stk(sp) = y : sp += 1
                        End If
                    End If
                End Select
            Next
        End If

        Do While sp > 0
            sp -= 1
            x = stk(sp)
            If gLnFalls(x) <> 0 And x + 1 < gNL Then
                If gMem(mbase + x + 1) = 0 Then
                    gMem(mbase + x + 1) = 1 : stk(sp) = x + 1 : sp += 1
                End If
            End If
            For k = gLnEd1(x) To gLnEd1(x) + gLnEdN(x) - 1
                Select Case gEdKind(k)
                Case ED_GOTO, ED_THEN, ED_ELSE, ED_ONGOTO
                    y = gEdTo(k)
                    If y >= 0 Then
                        If gMem(mbase + y) = 0 Then
                            gMem(mbase + y) = 1 : stk(sp) = y : sp += 1
                        End If
                    End If
                End Select
            Next
        Loop
    Next

    For x = 0 To gNL - 1
        gLnOwners(x) = 0
        For e = 0 To gNEn - 1
            If gMem(CLng(e) * gNL + x) Then gLnOwners(x) += 1
        Next
    Next
End Sub

Function IsMember(ByVal e As Integer, ByVal li As Integer) As Integer
    IsMember = gMem(CLng(e) * gNL + li)
End Function

Sub ComputeCalls()
    Dim e As Integer, x As Integer, k As Integer, f As Integer
    If gNEn = 0 Then Exit Sub
    ReDim gCall(0 To CLng(gNEn) * gNEn)
    For e = 0 To gNEn - 1
        For x = 0 To gNL - 1
            If IsMember(e, x) Then
                For k = gLnEd1(x) To gLnEd1(x) + gLnEdN(x) - 1
                    If gEdTo(k) >= 0 Then
                        f = gLnEntry(gEdTo(k))
                        If f >= 0 Then
                            Select Case gEdKind(k)
                            Case ED_GOSUB, ED_ONGOSUB
                                gCall(CLng(e) * gNEn + f) = 1
                            Case ED_ONEVENT, ED_ONERROR
                                If gCall(CLng(e) * gNEn + f) = 0 Then gCall(CLng(e) * gNEn + f) = 2
                            End Select
                        End If
                    End If
                Next
            End If
        Next
    Next
End Sub

'' --- documentatie uit commentaar ---

Function LineComment(ByVal li As Integer) As String
    Dim k As Integer
    LineComment = ""
    For k = gLnTk1(li) To gLnTk1(li) + gLnTkN(li) - 1
        If gTkType(k) = TK_REM Then
            LineComment = gTkText(k) : Exit Function
        End If
    Next
End Function

Sub DocText(ByVal e As Integer, ByRef txt As String)
    Dim t As String, rest As String, p As Integer, d As String
    Dim nm As String, ds As String
    t = Trim(txt, Any " " & Chr(9))
    If Left(t, 2) = "##" Then
        rest = Trim(Mid(t, 3))
        p = InStr(rest, " - ")
        If p > 0 Then
            nm = Trim(Left(rest, p - 1)) : ds = Trim(Mid(rest, p + 3))
        Else
            p = InStr(rest, ":")
            If p > 0 Then
                nm = Trim(Left(rest, p - 1)) : ds = Trim(Mid(rest, p + 1))
            Else
                nm = rest : ds = ""
            End If
        End If
        If gEnKind(e) = EN_MAIN Then
            If gProgTitle = "" Then gProgTitle = nm
            If ds <> "" Then gProgDesc &= ds & Chr(10)
        Else
            If gEnName(e) = "" Then gEnName(e) = nm
            If ds <> "" Then gEnDesc(e) &= ds & Chr(10)
        End If
    ElseIf Left(t, 1) = "@" Then
        p = InStr(t, " ")
        If p > 0 Then
            nm = Mid(t, 2, p - 2) : ds = Trim(Mid(t, p + 1))
        Else
            nm = Mid(t, 2) : ds = ""
        End If
        If gEnKind(e) = EN_MAIN Then
            gProgTags &= nm & Chr(9) & ds & Chr(10)
        Else
            gEnTags(e) &= nm & Chr(9) & ds & Chr(10)
        End If
    Else
        d = StripDeco(t)
        If d <> "" Then
            If gEnKind(e) = EN_MAIN Then
                gProgDesc &= d & Chr(10)
            Else
                gEnDesc(e) &= d & Chr(10)
            End If
        End If
    End If
End Sub

Sub CollectDocs()
    Dim e As Integer, L As Integer, k As Integer, first As Integer, p As Integer

    For e = 0 To gNEn - 1
        L = gEnLine(e)
        first = L
        If gEnKind(e) <> EN_MAIN Then
            k = L - 1
            Do While k >= 0
                If gLnRem(k) = 0 Or gLnTarget(k) <> 0 Or gLnTkN(k) = 0 Then Exit Do
                first = k
                k -= 1
            Loop
        End If
        For k = first To L - 1
            DocText e, LineComment(k)
        Next
        If gLnRem(L) Then
            k = L
            Do While k < gNL
                If gLnRem(k) = 0 Then Exit Do
                If k > L And gLnTarget(k) <> 0 Then Exit Do
                If gLnTkN(k) > 0 Then DocText e, LineComment(k)
                k += 1
            Loop
        Else
            If Len(LineComment(L)) > 0 Then DocText e, LineComment(L)
        End If

        If gEnKind(e) = EN_MAIN Then
            gEnDocd(e) = (gProgTitle <> "" Or gProgDesc <> "" Or gProgTags <> "")
        Else
            gEnDocd(e) = (gEnName(e) <> "" Or gEnDesc(e) <> "" Or gEnTags(e) <> "")
        End If

        '' naam bepalen
        If gEnKind(e) = EN_MAIN Then
            gEnName(e) = Tr("Main program")
        ElseIf gEnName(e) = "" Then
            If Len(gEnDesc(e)) > 0 Then
                p = InStr(gEnDesc(e), Chr(10))
                gEnName(e) = Left(gEnDesc(e), p - 1)
                gEnDesc(e) = Mid(gEnDesc(e), p + 1)
            Else
                Select Case gEnKind(e)
                Case EN_EVENT
                    gEnName(e) = Tr("Event handler")
                Case EN_ERROR
                    gEnName(e) = Tr("Error handler")
                Case Else
                    gEnName(e) = Tr("Subroutine")
                End Select
            End If
        End If
    Next
    If gProgTitle = "" And gProgDesc <> "" Then
        p = InStr(gProgDesc, Chr(10))
        gProgTitle = Left(gProgDesc, p - 1)
        gProgDesc = Mid(gProgDesc, p + 1)
    End If
End Sub

'' Bereiken van aaneengesloten regels -> tekst. mode: 0 = regels zonder eigenaar,
'' 1 = regels van ingang e
Function RangesHtml(ByVal e As Integer) As String
    Dim r As String, x As Integer, s As Integer
    r = "" : x = 0
    Do While x < gNL
        If IsMember(e, x) Then
            s = x
            Do While x + 1 < gNL
                If IsMember(e, x + 1) = 0 Then Exit Do
                x += 1
            Loop
            If Len(r) > 0 Then r &= ", "
            If s = x Then
                r &= LineLink(s)
            Else
                r &= LineLink(s) & "&ndash;" & LineLink(x)
            End If
        End If
        x += 1
    Loop
    RangesHtml = r
End Function

Function OwnerSig(ByVal x As Integer) As String
    Dim e As Integer, r As String
    r = ""
    For e = 0 To gNEn - 1
        If IsMember(e, x) Then
            If Len(r) > 0 Then r &= ", "
            If gEnKind(e) = EN_MAIN Then r &= Tr("main program") Else r &= NStr(gLnNum(gEnLine(e)))
        End If
    Next
    OwnerSig = r
End Function

Sub ComputeWarnings()
    Dim x As Integer, s As Integer, e As Integer, k As Integer, v As Integer
    Dim sig As String, hasRet As Integer, hasEnd As Integer, dead As Integer

    '' hoofdprogramma bereikt RETURN
    For x = 0 To gNL - 1
        If gNEn > 0 Then
            If IsMember(0, x) And gLnRet(x) <> 0 Then
                AddWarn x, Tr1("Line %1: the main program can reach a RETURN here without a GOSUB (falling through into a subroutine?)", NStr(gLnNum(x)))
            End If
        End If
    Next

    '' routines zonder RETURN
    For e = 0 To gNEn - 1
        If gEnKind(e) = EN_GOSUB Or gEnKind(e) = EN_EVENT Then
            hasRet = 0 : hasEnd = 0
            For x = 0 To gNL - 1
                If IsMember(e, x) Then
                    If gLnRet(x) Then hasRet = 1
                    If gLnEnd(x) Then hasEnd = 1
                End If
            Next
            If hasRet = 0 Then
                If hasEnd Then
                    AddWarn gEnLine(e), Tr1("Routine %1 ends with END/STOP but does not reach a RETURN", NStr(gLnNum(gEnLine(e))))
                Else
                    AddWarn gEnLine(e), Tr1("Routine %1 does not reach a RETURN", NStr(gLnNum(gEnLine(e))))
                End If
            End If
        End If
    Next

    '' gedeelde code
    x = 0
    Do While x < gNL
        If gLnOwners(x) > 1 Then
            s = x : sig = OwnerSig(x)
            Do While x + 1 < gNL
                If gLnOwners(x + 1) <= 1 Then Exit Do
                If OwnerSig(x + 1) <> sig Then Exit Do
                x += 1
            Loop
            If s = x Then
                AddWarn s, Tr2("Line %1 belongs to several routines: %2", NStr(gLnNum(s)), sig)
            Else
                AddWarn s, Tr3("Lines %1-%2 belong to several routines: %3", NStr(gLnNum(s)), NStr(gLnNum(x)), sig)
            End If
        End If
        x += 1
    Loop

    '' onbereikbare code
    x = 0
    Do While x < gNL
        dead = 0
        If gLnOwners(x) = 0 And gLnRem(x) = 0 And gLnData(x) = 0 Then dead = 1
        If dead Then
            s = x
            Do While x + 1 < gNL
                If gLnOwners(x + 1) <> 0 Then Exit Do
                If gLnRem(x + 1) = 0 And gLnData(x + 1) = 0 Then
                    x += 1
                ElseIf x + 2 < gNL Then
                    '' commentaar/DATA binnen een dood blok overslaan als er daarna nog dode code volgt
                    If gLnOwners(x + 2) = 0 And gLnRem(x + 2) = 0 And gLnData(x + 2) = 0 Then
                        x += 1
                    Else
                        Exit Do
                    End If
                Else
                    Exit Do
                End If
            Loop
            If s = x Then
                AddWarn s, Tr1("Line %1 is unreachable", NStr(gLnNum(s)))
            Else
                AddWarn s, Tr2("Lines %1-%2 are unreachable", NStr(gLnNum(s)), NStr(gLnNum(x)))
            End If
        End If
        x += 1
    Loop

    '' variabelen die alleen in de eerste twee tekens overeenkomen
    For v = 0 To gNV - 1
        If CountSpellings(gVarNames(v)) > 1 Then
            k = -1
            For x = 0 To gNU - 1
                If gUsVar(x) = v Then
                    k = gUsLine(x) : Exit For
                End If
            Next
            AddWarn k, Tr1("%1 are the same variable in MSX-BASIC (only the first 2 characters count)", Spellings(gVarNames(v)))
        End If
    Next
End Sub

'' Welke ingangen zijn via aanroepen bereikbaar vanuit het hoofdprogramma,
'' en welke hebben een aanroeper binnen bereikbare code?
Sub ComputeReach()
    Dim e As Integer, f As Integer, sp As Integer, x As Integer
    Dim stk() As Integer
    If gNEn = 0 Then Exit Sub
    ReDim stk(0 To gNEn + 1)
    For e = 0 To gNEn - 1
        gEnReach(e) = 0 : gEnHasCaller(e) = 0
        For f = 0 To gNEn - 1
            If gCall(CLng(f) * gNEn + e) <> 0 Then gEnHasCaller(e) = 1
        Next
    Next
    gEnReach(0) = 1 : stk(0) = 0 : sp = 1
    Do While sp > 0
        sp -= 1 : x = stk(sp)
        For f = 0 To gNEn - 1
            If gCall(CLng(x) * gNEn + f) <> 0 And gEnReach(f) = 0 Then
                gEnReach(f) = 1 : stk(sp) = f : sp += 1
            End If
        Next
    Loop
End Sub
