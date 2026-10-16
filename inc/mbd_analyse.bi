'' ============================================================
'' msxbasicdoc - analyse per regel
''
'' Verzamelt per regel: sprongen/aanroepen, of de regel doorloopt naar
'' de volgende, RETURN/END, variabelengebruik, DEF FN, externe
'' verwijzingen en DEFxxx-typebereiken.
'' ============================================================

Sub AddEdge(ByVal li As Integer, ByVal kind As Integer, ByVal num As Long, ByRef info As String)
    gEdFrom(gNE) = li
    gEdKind(gNE) = kind
    gEdNum(gNE) = num
    gEdTo(gNE) = -1
    gEdInfo(gNE) = info
    gNE += 1
End Sub

Sub AddUse(ByVal li As Integer, ByRef nm As String, ByVal isArr As Integer, ByVal mode As Integer)
    gUsLine(gNU) = li
    gUsName(gNU) = nm
    gUsArr(gNU) = isArr
    gUsMode(gNU) = mode
    gUsVar(gNU) = -1
    gNU += 1
End Sub

Sub AddExt(ByVal li As Integer, ByRef kind As String, ByRef nm As String)
    gExLine(gNX) = li
    gExKind(gNX) = kind
    gExName(gNX) = nm
    gNX += 1
End Sub

Function IsKwAt(ByVal k As Integer, ByVal b As Integer, ByRef w As String) As Integer
    IsKwAt = 0
    If k <= b Then
        If gTkType(k) = TK_KW And gTkText(k) = w Then IsKwAt = -1
    End If
End Function

Function IsOpAt(ByVal k As Integer, ByVal b As Integer, ByRef w As String) As Integer
    IsOpAt = 0
    If k <= b Then
        If gTkType(k) = TK_OP And gTkText(k) = w Then IsOpAt = -1
    End If
End Function

Function NumAt(ByVal k As Integer, ByVal b As Integer) As Integer
    NumAt = 0
    If k <= b Then
        If gTkType(k) = TK_NUM And gTkVal(k) >= 0 Then NumAt = -1
    End If
End Function

Function SkipParens(ByVal k As Integer, ByVal b As Integer) As Integer
    Dim d As Integer
    d = 0
    Do While k <= b
        If gTkType(k) = TK_OP Then
            If gTkText(k) = "(" Then d += 1
            If gTkText(k) = ")" Then
                d -= 1
                If d <= 0 Then
                    k += 1 : Exit Do
                End If
            End If
        ElseIf gTkType(k) = TK_SEP Then
            Exit Do
        End If
        k += 1
    Loop
    SkipParens = k
End Function

'' Tekst van de tokens vanaf k tot het einde van het statement
Function StmtText(ByVal k As Integer, ByVal b As Integer) As String
    Dim r As String
    r = ""
    Do While k <= b
        If gTkType(k) = TK_SEP Or gTkType(k) = TK_REM Then Exit Do
        If Len(r) > 0 And gTkType(k) <> TK_OP Then r &= " "
        r &= gTkText(k)
        k += 1
    Loop
    StmtText = r
End Function

'' Een sprong die het huidige pad beëindigt (GOTO, RETURN, END, ...)
Sub MarkTerm(ByRef topTerm As Integer, ByVal inIf As Integer, ByVal inElse As Integer, _
             ByVal nested As Integer, ByRef thenTerm As Integer, ByRef elseTerm As Integer)
    If inIf = 0 Then
        topTerm = 1
    ElseIf nested = 0 Then
        If inElse Then elseTerm = 1 Else thenTerm = 1
    End If
End Sub

'' ON ... GOTO/GOSUB, ON ERROR GOTO, ON <event> GOSUB
Function ParseOn(ByVal li As Integer, ByVal j As Integer, ByVal b As Integer) As Integer
    Dim k As Integer, kind As Integer, info As String, t As Integer, kw As String
    k = j + 1 : kind = 0 : info = ""

    If k <= b Then
        If gTkType(k) = TK_KW Then
            kw = gTkText(k)
            If kw = "ERROR" Then
                k += 1
                If IsKwAt(k, b, "GOTO") Then
                    k += 1
                    If NumAt(k, b) Then
                        If gTkVal(k) > 0 Then AddEdge li, ED_ONERROR, gTkVal(k), "ERROR"
                        k += 1
                    End If
                End If
                ParseOn = k : Exit Function
            ElseIf kw = "INTERVAL" Or kw = "KEY" Or kw = "SPRITE" Or kw = "STRIG" Or kw = "STOP" Then
                kind = ED_ONEVENT : info = kw : k += 1
            End If
        End If
    End If

    '' zoek GOTO/GOSUB binnen het statement
    Do While k <= b
        t = gTkType(k)
        If t = TK_SEP Or t = TK_REM Then
            ParseOn = k : Exit Function
        ElseIf t = TK_KW Then
            kw = gTkText(k)
            If kw = "GOTO" Or kw = "GOSUB" Then Exit Do
            If kw = "ELSE" Or kw = "THEN" Then
                ParseOn = k : Exit Function
            End If
        ElseIf t = TK_ID Then
            AddUse li, gTkText(k), IsOpAt(k + 1, b, "("), 0
        End If
        k += 1
    Loop
    If k > b Then
        ParseOn = k : Exit Function
    End If

    If kind = 0 Then
        If gTkText(k) = "GOTO" Then kind = ED_ONGOTO Else kind = ED_ONGOSUB
    End If
    k += 1
    Do While k <= b
        t = gTkType(k)
        If t = TK_NUM Then
            If gTkVal(k) >= 0 Then AddEdge li, kind, gTkVal(k), info
        ElseIf t = TK_OP And gTkText(k) = "," Then
            '' volgende
        Else
            Exit Do
        End If
        k += 1
    Loop
    ParseOn = k
End Function

Sub AnalyseLine(ByVal li As Integer)
    Dim a As Integer, b As Integer, j As Integer, k As Integer, t As Integer
    Dim q As Integer, lastL As Integer, rng As Integer, L As Integer
    Dim topTerm As Integer, inIf As Integer, inElse As Integer, nested As Integer
    Dim thenTerm As Integer, elseTerm As Integer
    Dim stmtStart As Integer, wmode As Integer, depth As Integer
    Dim isArr As Integer, mode As Integer
    Dim kw As String, nm As String, defParams As String, ty As String

    a = gLnTk1(li) : b = a + gLnTkN(li) - 1
    gLnEd1(li) = gNE

    If gLnTkN(li) = 0 Then
        gLnRem(li) = 1
    Else
        If gTkType(a) = TK_REM Then gLnRem(li) = 1
        If gTkType(a) = TK_KW And gTkText(a) = "DATA" Then gLnData(li) = 1
    End If

    stmtStart = 1 : wmode = 0 : depth = 0 : defParams = ""
    j = a
    Do While j <= b
        t = gTkType(j)

        If t = TK_REM Then Exit Do

        If t = TK_SEP Then
            stmtStart = 1 : wmode = 0 : depth = 0 : defParams = ""
            j += 1 : Continue Do
        End If

        If t = TK_KW Then
            kw = gTkText(j)
            Select Case kw
            Case "THEN", "ELSE"
                If kw = "ELSE" And inIf <> 0 And nested = 0 Then inElse = 1
                stmtStart = 1 : wmode = 0 : depth = 0
                If NumAt(j + 1, b) Then
                    If kw = "THEN" Then
                        AddEdge li, ED_THEN, gTkVal(j + 1), ""
                    Else
                        AddEdge li, ED_ELSE, gTkVal(j + 1), ""
                    End If
                    MarkTerm topTerm, inIf, inElse, nested, thenTerm, elseTerm
                    j += 2
                Else
                    j += 1
                End If
                Continue Do

            Case "IF"
                If inIf Then nested = 1 Else inIf = 1

            Case "GOTO"
                If NumAt(j + 1, b) Then
                    AddEdge li, ED_GOTO, gTkVal(j + 1), ""
                    MarkTerm topTerm, inIf, inElse, nested, thenTerm, elseTerm
                    j += 1
                End If

            Case "GOSUB"
                If NumAt(j + 1, b) Then
                    AddEdge li, ED_GOSUB, gTkVal(j + 1), ""
                    j += 1
                End If

            Case "RETURN"
                gLnRet(li) = 1
                If NumAt(j + 1, b) Then
                    AddEdge li, ED_RETURNTO, gTkVal(j + 1), ""
                    j += 1
                End If
                MarkTerm topTerm, inIf, inElse, nested, thenTerm, elseTerm

            Case "END"
                gLnEnd(li) = 1
                MarkTerm topTerm, inIf, inElse, nested, thenTerm, elseTerm

            Case "STOP"
                '' STOP ON/OFF/STOP schakelt alleen de STOP-trap
                If IsKwAt(j + 1, b, "ON") = 0 And IsKwAt(j + 1, b, "OFF") = 0 And IsKwAt(j + 1, b, "STOP") = 0 Then
                    gLnEnd(li) = 1
                    MarkTerm topTerm, inIf, inElse, nested, thenTerm, elseTerm
                End If

            Case "RUN"
                If NumAt(j + 1, b) Then
                    AddEdge li, ED_RUN, gTkVal(j + 1), ""
                    j += 1
                ElseIf j + 1 <= b Then
                    If gTkType(j + 1) = TK_STR Then
                        AddExt li, "RUN", gTkText(j + 1)
                        j += 1
                    End If
                End If
                MarkTerm topTerm, inIf, inElse, nested, thenTerm, elseTerm

            Case "RESUME"
                If NumAt(j + 1, b) Then
                    If gTkVal(j + 1) > 0 Then AddEdge li, ED_RESUME, gTkVal(j + 1), ""
                    j += 1
                End If
                MarkTerm topTerm, inIf, inElse, nested, thenTerm, elseTerm

            Case "ON"
                j = ParseOn(li, j, b)
                stmtStart = 0
                Continue Do

            Case "RESTORE"
                If NumAt(j + 1, b) Then
                    AddEdge li, ED_RESTORE, gTkVal(j + 1), ""
                    j += 1
                End If

            Case "LOAD", "MERGE", "BLOAD"
                If j + 1 <= b Then
                    If gTkType(j + 1) = TK_STR Then
                        AddExt li, kw, gTkText(j + 1)
                        j += 1
                    End If
                End If

            Case "CALL"
                If j + 1 <= b Then
                    If gTkType(j + 1) = TK_CALL Then
                        AddExt li, "CALL", gTkText(j + 1)
                        j += 1
                    End If
                End If

            Case "DEFINT", "DEFSNG", "DEFDBL", "DEFSTR"
                Select Case kw
                Case "DEFINT"
                    ty = "%"
                Case "DEFSNG"
                    ty = "!"
                Case "DEFDBL"
                    ty = "#"
                Case Else
                    ty = "$"
                End Select
                k = j + 1 : lastL = -1 : rng = 0
                Do While k <= b
                    If gTkType(k) = TK_SEP Or gTkType(k) = TK_REM Then Exit Do
                    If gTkType(k) = TK_ID Then
                        L = Asc(gTkText(k), 1) - 65
                        If L >= 0 And L <= 25 Then
                            If rng <> 0 And lastL >= 0 Then
                                For q = lastL To L
                                    gDefType(q) = ty
                                Next
                            Else
                                gDefType(L) = ty
                            End If
                            lastL = L
                        End If
                        rng = 0
                    ElseIf gTkType(k) = TK_OP And gTkText(k) = "-" Then
                        rng = 1
                    End If
                    k += 1
                Loop
                j = k : stmtStart = 0
                Continue Do

            Case "DEF"
                If IsKwAt(j + 1, b, "FN") Then
                    k = j + 2
                    If k <= b Then
                        If gTkType(k) = TK_ID Then
                            gFnName(gNF) = gTkText(k) : gFnLine(gNF) = li : gNF += 1
                            k += 1
                            defParams = "|"
                            If IsOpAt(k, b, "(") Then
                                k += 1
                                Do While k <= b
                                    If IsOpAt(k, b, ")") Then
                                        k += 1 : Exit Do
                                    End If
                                    If gTkType(k) = TK_ID Then defParams &= gTkText(k) & "|"
                                    k += 1
                                Loop
                            End If
                        End If
                    End If
                    j = k : stmtStart = 0
                    Continue Do
                ElseIf IsKwAt(j + 1, b, "USR") Then
                    AddExt li, "DEF USR", StmtText(j + 1, b)
                End If

            Case "FN"
                If j + 1 <= b Then
                    If gTkType(j + 1) = TK_ID Then
                        gFuName(gNFU) = gTkText(j + 1) : gFuLine(gNFU) = li : gNFU += 1
                        j += 2 : stmtStart = 0
                        Continue Do
                    End If
                End If

            Case "FOR", "LET"
                wmode = 2
            Case "INPUT", "READ", "SWAP"
                wmode = 1 : depth = 0
            Case "DIM"
                wmode = 3 : depth = 0
            End Select

            stmtStart = 0
            j += 1
            Continue Do
        End If

        If t = TK_ID Then
            nm = gTkText(j)
            isArr = IsOpAt(j + 1, b, "(")
            If InStr(defParams, "|" & nm & "|") = 0 Or Len(defParams) = 0 Then
                mode = 0
                If stmtStart Then
                    k = j + 1
                    If isArr Then k = SkipParens(k, b)
                    If IsOpAt(k, b, "=") Then mode = 1
                ElseIf wmode = 2 Then
                    mode = 1 : wmode = 0
                ElseIf wmode = 1 And depth = 0 Then
                    mode = 1
                ElseIf wmode = 3 And depth = 0 Then
                    mode = 2
                End If
                AddUse li, nm, isArr, mode
            End If
            stmtStart = 0
            j += 1
            Continue Do
        End If

        If t = TK_OP Then
            If gTkText(j) = "(" Then depth += 1
            If gTkText(j) = ")" Then depth -= 1
        End If
        stmtStart = 0
        j += 1
    Loop

    '' doorlopen naar de volgende regel?
    gLnFalls(li) = 1
    If topTerm Then
        gLnFalls(li) = 0
    ElseIf inIf <> 0 And nested = 0 And thenTerm <> 0 And elseTerm <> 0 Then
        gLnFalls(li) = 0
    End If
    gLnEdN(li) = gNE - gLnEd1(li)
End Sub

Sub AnalyseAll()
    Dim li As Integer, cap As Integer
    cap = gNT + 16
    ReDim gEdFrom(0 To cap), gEdKind(0 To cap), gEdNum(0 To cap), gEdTo(0 To cap), gEdInfo(0 To cap)
    ReDim gExLine(0 To cap), gExKind(0 To cap), gExName(0 To cap)
    ReDim gUsLine(0 To cap), gUsName(0 To cap), gUsArr(0 To cap), gUsMode(0 To cap), gUsVar(0 To cap)
    ReDim gFnName(0 To cap), gFnLine(0 To cap), gFuName(0 To cap), gFuLine(0 To cap)
    gNE = 0 : gNX = 0 : gNU = 0 : gNF = 0 : gNFU = 0
    For li = 0 To gNL - 1
        AnalyseLine li
    Next
End Sub
