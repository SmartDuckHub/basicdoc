'' =====================================================================
''  fbdoc - Tokenizer: broncode naar tokens en commentaarblokken
'' =====================================================================

Sub AddCmt(ByRef txt As String, ByVal ls As Integer, ByVal le As Integer, ByVal inl As Integer, ByVal isDoc As Integer)
    If cmtCount + 1 > cmtCap Then
        If cmtCap = 0 Then cmtCap = 64 Else cmtCap = cmtCap * 2
        ReDim Preserve cmtText(1 To cmtCap)
        ReDim Preserve cmtStart(1 To cmtCap)
        ReDim Preserve cmtEnd(1 To cmtCap)
        ReDim Preserve cmtInline(1 To cmtCap)
        ReDim Preserve cmtIsDoc(1 To cmtCap)
    End If
    cmtCount = cmtCount + 1
    cmtText(cmtCount)   = txt
    cmtStart(cmtCount)  = ls
    cmtEnd(cmtCount)    = le
    cmtInline(cmtCount) = inl
    cmtIsDoc(cmtCount)  = isDoc
End Sub

Sub AddTok(ByRef t As String, ByVal ln As Integer, ByVal k As Integer)
    If tokCount + 1 > tokCap Then
        If tokCap = 0 Then tokCap = 1024 Else tokCap = tokCap * 2
        ReDim Preserve tokText(1 To tokCap)
        ReDim Preserve tokLine(1 To tokCap)
        ReDim Preserve tokKind(1 To tokCap)
        ReDim Preserve tokDoc(1 To tokCap)
    End If
    tokCount = tokCount + 1
    tokText(tokCount) = t
    tokLine(tokCount) = ln
    tokKind(tokCount) = k
    tokDoc(tokCount)  = pendingCmt
    pendingCmt = -1
End Sub

Function JoinTok(ByVal a As Integer, ByVal b As Integer) As String
    Dim As String s, t, pv
    Dim As Integer k
    s = ""
    If a < 1 Then Return ""
    If b > tokCount Then b = tokCount
    For k = a To b
        t = tokText(k)
        If Len(s) > 0 Then
            pv = Right(s, 1)
            If t = "," Or t = ")" Or t = "]" Or t = ";" Or t = "(" Or t = "[" Or t = "?" Or t = "." Then
                '' geen spatie
            ElseIf pv = "(" Or pv = "[" Or pv = "." Then
                '' geen spatie
            Else
                s = s & " "
            End If
        End If
        s = s & t
    Next k
    Return s
End Function

Sub TokenizeFile(ByRef fpath As String)
    Dim As Integer fh, lineNo, i, blockLvl, hadCode, blkStart, blkInline
    Dim As Integer p, lastLineCmt, lastCmtEnd, contLine
    Dim As String ln, ch, nx, buf, blkBuf, q, trimmed

    tokCount = 0
    cmtCount = 0
    pendingCmt = -1
    blockLvl = 0
    blkBuf = ""
    lineNo = 0
    lastLineCmt = 0
    lastCmtEnd = -99
    contLine = 0

    fh = FreeFile
    If Open(fpath For Input As #fh) <> 0 Then
        Say "  ! kan bestand niet openen: " & fpath
        skippedFiles = skippedFiles + 1
        Exit Sub
    End If

    While Not EOF(fh)
        Line Input #fh, ln
        lineNo = lineNo + 1
        ln = ReplaceAll(ln, Chr(9), " ")
        hadCode = 0
        i = 1

        While i <= Len(ln)
            ch = Mid(ln, i, 1)

            If blockLvl > 0 Then
                '' in een /' ... '/ blok; die zijn in FreeBASIC nestbaar
                If Mid(ln, i, 2) = "/'" Then
                    blockLvl = blockLvl + 1
                    blkBuf = blkBuf & "/'"
                    i = i + 2
                ElseIf Mid(ln, i, 2) = "'/" Then
                    blockLvl = blockLvl - 1
                    If blockLvl = 0 Then
                        i = i + 2
                        AddCmt(blkBuf, blkStart, lineNo, blkInline, 0)
                        If blkInline = 0 Then
                            pendingCmt = cmtCount
                            lastCmtEnd = lineNo
                            lastLineCmt = 0
                        End If
                        blkBuf = ""
                    Else
                        blkBuf = blkBuf & "'/"
                        i = i + 2
                    End If
                Else
                    blkBuf = blkBuf & ch
                    i = i + 1
                End If

            ElseIf ch = " " Then
                i = i + 1

            ElseIf Mid(ln, i, 2) = "/'" Then
                blkStart = lineNo
                blkInline = hadCode
                blockLvl = 1
                blkBuf = ""
                i = i + 2
                '' /'' markeert een doc-blok; de extra apostrof hoort niet in de tekst
                If Mid(ln, i, 1) = "'" Then i = i + 1
                lastLineCmt = 0

            ElseIf ch = "'" Then
                '' regelcommentaar tot einde regel
                buf = Trim(Mid(ln, i + 1))
                While Left(buf, 1) = "'"
                    buf = Trim(Mid(buf, 2))
                Wend
                If hadCode Then
                    AddCmt(buf, lineNo, lineNo, -1, 0)
                Else
                    If lastLineCmt <> 0 And lastCmtEnd = lineNo - 1 And cmtCount > 0 Then
                        cmtText(cmtCount) = cmtText(cmtCount) & Chr(10) & buf
                        cmtEnd(cmtCount) = lineNo
                        pendingCmt = cmtCount
                    Else
                        AddCmt(buf, lineNo, lineNo, 0, 0)
                        pendingCmt = cmtCount
                    End If
                    lastLineCmt = -1
                    lastCmtEnd = lineNo
                End If
                i = Len(ln) + 1

            ElseIf ch = Chr(34) Then
                q = ch
                buf = ch
                i = i + 1
                While i <= Len(ln)
                    nx = Mid(ln, i, 1)
                    buf = buf & nx
                    If nx = q Then
                        If Mid(ln, i + 1, 1) = q Then
                            buf = buf & q
                            i = i + 2
                        Else
                            i = i + 1
                            Exit While
                        End If
                    Else
                        i = i + 1
                    End If
                Wend
                AddTok(buf, lineNo, TK_STR)
                hadCode = -1
                lastLineCmt = 0

            ElseIf IsIdentCh(ch) Then
                buf = ""
                While i <= Len(ln)
                    nx = Mid(ln, i, 1)
                    If IsIdentCh(nx) = 0 Then Exit While
                    buf = buf & nx
                    i = i + 1
                Wend
                '' typesuffix zoals naam$ hoort bij de naam
                If i <= Len(ln) Then
                    If Mid(ln, i, 1) = "$" Then
                        buf = buf & "$"
                        i = i + 1
                    End If
                End If
                If IsDigitCh(Left(buf, 1)) Then
                    AddTok(buf, lineNo, TK_NUM)
                ElseIf LC(buf) = "rem" And hadCode = 0 Then
                    '' Rem-commentaar gedraagt zich als een apostrof
                    buf = Trim(Mid(ln, i))
                    AddCmt(buf, lineNo, lineNo, 0, 0)
                    pendingCmt = cmtCount
                    lastLineCmt = -1
                    lastCmtEnd = lineNo
                    i = Len(ln) + 1
                Else
                    AddTok(buf, lineNo, TK_IDENT)
                    hadCode = -1
                    lastLineCmt = 0
                End If

            ElseIf ch = "&" And (LC(Mid(ln, i + 1, 1)) = "h" Or LC(Mid(ln, i + 1, 1)) = "b" Or LC(Mid(ln, i + 1, 1)) = "o") Then
                buf = Mid(ln, i, 2)
                i = i + 2
                While i <= Len(ln)
                    nx = Mid(ln, i, 1)
                    If IsIdentCh(nx) = 0 Then Exit While
                    buf = buf & nx
                    i = i + 1
                Wend
                AddTok(buf, lineNo, TK_NUM)
                hadCode = -1
                lastLineCmt = 0

            ElseIf ch = ":" Then
                '' statementscheider binnen een regel
                AddTok(":", lineNo, TK_EOL)
                i = i + 1
                hadCode = -1
                lastLineCmt = 0

            Else
                AddTok(ch, lineNo, TK_PUNCT)
                i = i + 1
                hadCode = -1
                lastLineCmt = 0
            End If
        Wend

        '' regeleinde is een statementeinde, tenzij de regel op _ eindigt
        contLine = 0
        trimmed = RTrim(ln)
        If Right(trimmed, 1) = "_" Then
            If Len(trimmed) = 1 Then
                contLine = -1
            ElseIf IsIdentCh(Mid(trimmed, Len(trimmed) - 1, 1)) = 0 Then
                contLine = -1
            End If
        End If
        If blockLvl > 0 Then
            blkBuf = blkBuf & Chr(10)
        ElseIf contLine = 0 Then
            If tokCount > 0 Then
                If tokKind(tokCount) <> TK_EOL Then AddTok("", lineNo, TK_EOL)
            End If
        Else
            '' de _ zelf is geen token
            If tokCount > 0 Then
                If tokText(tokCount) = "_" Then tokCount = tokCount - 1
            End If
        End If
    Wend

    Close #fh

    If blockLvl > 0 Then AddCmt(blkBuf, blkStart, lineNo, blkInline, 0)
    AddTok("", lineNo + 1, TK_EOL)
End Sub
