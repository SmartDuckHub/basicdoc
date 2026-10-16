'' ============================================================
'' msxbasicdoc - lexer
''
'' Herkent sleutelwoorden zoals de MSX-tokenizer: op elke letter-
'' positie wordt eerst gekeken of daar een sleutelwoord begint, ook
'' midden in een "variabelenaam". FORI=1TO10 wordt dus FOR I = 1 TO 10,
'' en SCORE wordt (net als op een echte MSX) SC OR E.
'' ============================================================

Sub InitKeywords()
    Dim lst As String, w As String, p As Integer, q As Integer
    Dim i As Integer, j As Integer, tmp As String, c As Integer
    Dim swp As Integer

    lst = "ABS AND ASC ATN ATTR$ AUTO BASE BEEP BIN$ BLOAD BSAVE CALL CDBL CHR$ " & _
          "CINT CIRCLE CLEAR CLOAD CLOSE CLS CMD COLOR CONT COPY COS CSAVE CSNG " & _
          "CSRLIN CVD CVI CVS DATA DEF DEFDBL DEFINT DEFSNG DEFSTR DELETE DIM DRAW " & _
          "DSKF DSKI$ DSKO$ ELSE END EOF EQV ERASE ERL ERR ERROR EXP FIELD FILES FIX " & _
          "FN FOR FPOS FRE GET GOSUB GOTO HEX$ IF IMP INKEY$ INP INPUT INSTR INT " & _
          "INTERVAL IPL KEY KILL LEFT$ LEN LET LFILES LINE LIST LLIST LOAD LOC LOCATE " & _
          "LOF LOG LPOS LPRINT LSET MAX MERGE MID$ MKD$ MKI$ MKS$ MOD MOTOR NAME NEW " & _
          "NEXT NOT OCT$ OFF ON OPEN OR OUT PAD PAINT PDL PEEK PLAY POINT POKE POS " & _
          "PRESET PRINT PSET PUT READ REM RENUM RESTORE RESUME RETURN RIGHT$ RND RSET " & _
          "RUN SAVE SCREEN SET SGN SIN SOUND SPACE$ SPC( SPRITE SQR STEP STICK STOP " & _
          "STR$ STRIG STRING$ SWAP TAB( TAN THEN TIME TO TROFF TRON USING USR VAL " & _
          "VARPTR VDP VPEEK VPOKE WAIT WIDTH XOR"

    '' tellen en vullen
    gNKw = 0
    ReDim gKw(0 To 255)
    p = 1
    Do While p <= Len(lst)
        q = InStr(p, lst, " ")
        If q = 0 Then q = Len(lst) + 1
        w = Mid(lst, p, q - p)
        If Len(w) > 0 Then
            gKw(gNKw) = w
            gNKw += 1
        End If
        p = q + 1
    Loop

    '' sorteren: eerste letter oplopend, daarna lengte aflopend (langste match eerst)
    For i = 1 To gNKw - 1
        tmp = gKw(i)
        j = i - 1
        Do While j >= 0
            swp = 0
            If Asc(gKw(j), 1) > Asc(tmp, 1) Then
                swp = 1
            ElseIf Asc(gKw(j), 1) = Asc(tmp, 1) Then
                If Len(gKw(j)) < Len(tmp) Then swp = 1
            End If
            If swp = 0 Then Exit Do
            gKw(j + 1) = gKw(j)
            j -= 1
        Loop
        gKw(j + 1) = tmp
    Next

    For c = 0 To 25
        gKwFirst(c) = 0 : gKwLast(c) = -1
    Next
    For i = 0 To gNKw - 1
        c = Asc(gKw(i), 1) - 65
        If gKwLast(c) = -1 Then gKwFirst(c) = i
        gKwLast(c) = i
    Next
End Sub

'' Sleutelwoord dat op positie i in u (hoofdletters) begint, of ""
Function MatchKw(ByRef u As String, ByVal i As Integer) As String
    Dim k As Integer, c As Integer
    c = Asc(u, i)
    If c < 65 Or c > 90 Then
        MatchKw = "" : Exit Function
    End If
    c -= 65
    For k = gKwFirst(c) To gKwLast(c)
        If Mid(u, i, Len(gKw(k))) = gKw(k) Then
            MatchKw = gKw(k) : Exit Function
        End If
    Next
    MatchKw = ""
End Function

Sub AddTok(ByVal t As Integer, ByRef txt As String, ByVal v As Long)
    gTkType(gNT) = t
    gTkText(gNT) = txt
    gTkVal(gNT) = v
    gNT += 1
End Sub

'' Leest een getal vanaf positie i; geeft nieuwe positie terug
Function LexNumber(ByRef s As String, ByRef u As String, ByVal i As Integer) As Integer
    Dim n As Integer, j As Integer, c As Integer, c2 As Integer, c3 As Integer
    Dim isInt As Integer, txt As String, v As Long
    n = Len(u) : j = i
    c = Asc(u, j)

    '' &H.. &O.. &B..
    If c = 38 Then
        c2 = 0
        If j < n Then c2 = Asc(u, j + 1)
        If c2 = 72 Or c2 = 79 Or c2 = 66 Then
            j += 2
            Do While j <= n
                c = Asc(u, j)
                If IsDigitC(c) Then
                    j += 1
                ElseIf c2 = 72 And c >= 65 And c <= 70 Then
                    j += 1
                Else
                    Exit Do
                End If
            Loop
            AddTok TK_NUM, Mid(s, i, j - i), -1
        Else
            AddTok TK_OP, "&", 0
            j += 1
        End If
        LexNumber = j : Exit Function
    End If

    isInt = -1
    Do While j <= n
        c = Asc(u, j)
        If IsDigitC(c) Then
            j += 1
        ElseIf c = 46 Then
            isInt = 0 : j += 1
        Else
            Exit Do
        End If
    Loop

    '' exponent: E/D gevolgd door cijfer of +/- cijfer
    If j <= n Then
        c = Asc(u, j)
        If c = 69 Or c = 68 Then
            c2 = 0 : c3 = 0
            If j + 1 <= n Then c2 = Asc(u, j + 1)
            If j + 2 <= n Then c3 = Asc(u, j + 2)
            If IsDigitC(c2) Or ((c2 = 43 Or c2 = 45) And IsDigitC(c3)) Then
                isInt = 0
                j += 2
                Do While j <= n
                    If IsDigitC(Asc(u, j)) Then j += 1 Else Exit Do
                Loop
            End If
        End If
    End If

    '' type-suffix
    If j <= n Then
        c = Asc(u, j)
        If c = 37 Or c = 33 Or c = 35 Then
            isInt = 0 : j += 1
        End If
    End If

    txt = Mid(s, i, j - i)
    v = -1
    If isInt And Len(txt) <= 5 And Len(txt) > 0 Then v = CLng(Val(txt))
    AddTok TK_NUM, txt, v
    LexNumber = j
End Function

'' Leest de naam na CALL of _
Function LexCallName(ByRef u As String, ByVal i As Integer) As Integer
    Dim n As Integer, j As Integer, c As Integer
    n = Len(u)
    Do While i <= n
        If Asc(u, i) = 32 Then i += 1 Else Exit Do
    Loop
    j = i
    Do While j <= n
        c = Asc(u, j)
        If IsDigitC(c) Or (c >= 65 And c <= 90) Then j += 1 Else Exit Do
    Loop
    If j > i Then AddTok TK_CALL, Mid(u, i, j - i), 0
    LexCallName = j
End Function

Sub TokenizeLine(ByVal li As Integer)
    Dim s As String, u As String, kw As String, op2 As String
    Dim n As Integer, i As Integer, j As Integer, c As Integer, c2 As Integer
    Dim kwStop As Integer, kw2 As String, p As Integer, wEnd_ As Integer

    s = gLnText(li) : u = UCase(s) : n = Len(s)
    gLnTk1(li) = gNT
    i = 1
    Do While i <= n
        c = Asc(u, i)
        If c = 32 Or c = 9 Then
            i += 1
        ElseIf c = 34 Then
            j = InStr(i + 1, s, Chr(34))
            If j = 0 Then j = n
            AddTok TK_STR, Mid(s, i, j - i + 1), 0
            i = j + 1
        ElseIf c = 39 Then
            AddTok TK_REM, Mid(s, i + 1), 0
            i = n + 1
        ElseIf c = 58 Then
            AddTok TK_SEP, ":", 0
            i += 1
        ElseIf c = 63 Then
            AddTok TK_KW, "PRINT", 0
            i += 1
        ElseIf c = 95 Then
            AddTok TK_KW, "CALL", 0
            i = LexCallName(u, i + 1)
        ElseIf IsDigitC(c) Or c = 46 Or c = 38 Then
            i = LexNumber(s, u, i)
        ElseIf c >= 65 And c <= 90 Then
            kw = MatchKw(u, i)
            If kw = "REM" Then
                AddTok TK_REM, Mid(s, i + 3), 0
                i = n + 1
            ElseIf kw = "DATA" Then
                AddTok TK_KW, "DATA", 0
                j = DataEnd(s, i + 4)
                AddTok TK_DATA, Mid(s, i + 4, j - i - 4), 0
                i = j
            ElseIf kw = "CALL" Then
                AddTok TK_KW, "CALL", 0
                i = LexCallName(u, i + 4)
            ElseIf Len(kw) > 0 Then
                If Right(kw, 1) = "(" Then
                    AddTok TK_KW, Left(kw, Len(kw) - 1), 0
                    AddTok TK_OP, "(", 0
                Else
                    AddTok TK_KW, kw, 0
                End If
                i += Len(kw)
            Else
                '' variabelenaam: letters/cijfers tot er een sleutelwoord begint
                j = i + 1 : kwStop = 0
                Do While j <= n
                    c2 = Asc(u, j)
                    If IsDigitC(c2) Then
                        j += 1
                    ElseIf c2 >= 65 And c2 <= 90 Then
                        If Len(MatchKw(u, j)) > 0 Then
                            kwStop = 1 : Exit Do
                        End If
                        j += 1
                    Else
                        Exit Do
                    End If
                Loop
                '' waarschuwing: sleutelwoord midden in een langere naam (SCORE -> SC OR E)
                If kwStop <> 0 And j - i >= 2 Then
                    kw2 = MatchKw(u, j)
                    p = j + Len(kw2)
                    If p <= n Then
                        If Asc(u, p) >= 65 And Asc(u, p) <= 90 Then
                            wEnd_ = p
                            Do While wEnd_ <= n
                                c2 = Asc(u, wEnd_)
                                If IsDigitC(c2) Or (c2 >= 65 And c2 <= 90) Then wEnd_ += 1 Else Exit Do
                            Loop
                            AddWarn li, "Regel " & NStr(gLnNum(li)) & ": " & Mid(u, i, wEnd_ - i) & " bevat het sleutelwoord " & _
                                kw2 & "; MSX leest dit als " & Mid(u, i, j - i) & " " & kw2 & " " & Mid(u, p, wEnd_ - p)
                        End If
                    End If
                End If
                If j <= n Then
                    c2 = Asc(u, j)
                    If c2 = 36 Or c2 = 37 Or c2 = 33 Or c2 = 35 Then j += 1
                End If
                AddTok TK_ID, Mid(u, i, j - i), 0
                i = j
            End If
        Else
            op2 = ""
            If i < n Then op2 = Mid(u, i, 2)
            Select Case op2
            Case "<=", "=<"
                AddTok TK_OP, "<=", 0 : i += 2
            Case ">=", "=>"
                AddTok TK_OP, ">=", 0 : i += 2
            Case "<>", "><"
                AddTok TK_OP, "<>", 0 : i += 2
            Case Else
                AddTok TK_OP, Chr(c), 0 : i += 1
            End Select
        End If
    Loop
    gLnTkN(li) = gNT - gLnTk1(li)
End Sub

Sub TokenizeAll()
    Dim li As Integer
    For li = 0 To gNL - 1
        TokenizeLine li
    Next
End Sub
