'' =====================================================================
''  fbdoc - Doc-commentaar verwerken: tekst en @tags
'' =====================================================================

Function NextDocLine(ByRef src As String, ByRef idx As Integer) As String
    Dim As Integer p
    Dim As String ln
    If idx > Len(src) Then Return Chr(0)
    p = InStr(idx, src, Chr(10))
    If p = 0 Then
        ln = Mid(src, idx)
        idx = Len(src) + 1
    Else
        ln = Mid(src, idx, p - idx)
        idx = p + 1
    End If
    ln = ReplaceAll(ln, Chr(13), "")
    ln = Trim(ln)
    If Left(ln, 2) = "*/" Then ln = Trim(Mid(ln, 3))
    If Left(ln, 1) = "*" Then ln = Trim(Mid(ln, 2))
    If Right(ln, 2) = "*/" Then ln = Trim(Left(ln, Len(ln) - 2))
    Return ln
End Function

Sub ApplyDoc(ByVal cidx As Integer, ByVal pidx As Integer, ByVal midx As Integer)
    Dim As String raw, ln, tg, arg, body, briefOv, rest
    Dim As Integer idx, p, k, pf, pc, found

    If cidx < 1 Then Exit Sub
    If cidx > cmtCount Then Exit Sub

    raw = cmtText(cidx)
    body = ""
    briefOv = ""
    tg = ""
    arg = ""
    idx = 1

    Do
        ln = NextDocLine(raw, idx)
        If ln = Chr(0) Then Exit Do

        If Left(ln, 1) = "@" Then
            '' nieuwe tag
            rest = Mid(ln, 2)
            p = InStr(rest, " ")
            If p = 0 Then
                tg = LC(rest)
                rest = ""
            Else
                tg = LC(Left(rest, p - 1))
                rest = Trim(Mid(rest, p + 1))
            End If
            arg = ""
            Select Case tg
            Case "param", "throws", "exception"
                p = InStr(rest, " ")
                If p = 0 Then
                    arg = rest
                    rest = ""
                Else
                    arg = Left(rest, p - 1)
                    rest = Trim(Mid(rest, p + 1))
                End If
            End Select
            ln = rest
        End If

        If Len(ln) = 0 And Len(tg) = 0 Then
            If Len(body) > 0 Then body = body & Chr(10) & Chr(10)
            Continue Do
        End If

        Select Case tg
        Case ""
            If Len(body) > 0 Then
                If Right(body, 1) = Chr(10) Then body = body & ln Else body = body & " " & ln
            Else
                body = ln
            End If

        Case "brief", "summary", "short"
            If Len(briefOv) > 0 Then briefOv = briefOv & " " & ln Else briefOv = ln

        Case "param"
            If midx > 0 Then
                pf = members(midx).paramFirst
                pc = members(midx).paramCnt
                found = 0
                For k = pf To pf + pc - 1
                    If k >= 1 And k <= paramCount Then
                        If LC(paramList(k).pname) = LC(arg) Then
                            If Len(paramList(k).pdesc) > 0 Then
                                paramList(k).pdesc = paramList(k).pdesc & " " & ln
                            Else
                                paramList(k).pdesc = ln
                            End If
                            found = -1
                        End If
                    End If
                Next k
                If found = 0 And Len(arg) > 0 Then
                    '' onbekende parameter: als losse opmerking bewaren
                    If Len(members(midx).detail) > 0 Then
                        members(midx).detail = members(midx).detail & Chr(10) & "@param " & arg & " " & ln
                    Else
                        members(midx).detail = "@param " & arg & " " & ln
                    End If
                End If
            End If

        Case "return", "returns", "result"
            If midx > 0 Then
                If Len(members(midx).retDesc) > 0 Then
                    members(midx).retDesc = members(midx).retDesc & " " & ln
                Else
                    members(midx).retDesc = ln
                End If
            End If

        Case "throws", "exception"
            If midx > 0 Then
                If Len(members(midx).throwsTxt) > 0 Then members(midx).throwsTxt = members(midx).throwsTxt & Chr(10)
                members(midx).throwsTxt = members(midx).throwsTxt & arg & " - " & ln
            End If

        Case "author"
            If midx > 0 Then members(midx).authorTxt = Trim(members(midx).authorTxt & " " & ln)
            If pidx > 0 Then parts(pidx).authorTxt = Trim(parts(pidx).authorTxt & " " & ln)

        Case "since", "version", "date"
            If midx > 0 Then members(midx).sinceTxt = Trim(members(midx).sinceTxt & " " & ln)
            If pidx > 0 Then parts(pidx).sinceTxt = Trim(parts(pidx).sinceTxt & " " & ln)

        Case "see", "seealso", "link"
            If midx > 0 Then
                If Len(members(midx).seeTxt) > 0 Then members(midx).seeTxt = members(midx).seeTxt & Chr(10)
                members(midx).seeTxt = members(midx).seeTxt & ln
            End If
            If pidx > 0 Then
                If Len(parts(pidx).seeTxt) > 0 Then parts(pidx).seeTxt = parts(pidx).seeTxt & Chr(10)
                parts(pidx).seeTxt = parts(pidx).seeTxt & ln
            End If

        Case "deprecated"
            If midx > 0 Then
                members(midx).isDeprec = -1
                If Len(ln) > 0 Then members(midx).detail = Trim(members(midx).detail & Chr(10) & "Deprecated: " & ln)
            End If
            If pidx > 0 Then
                parts(pidx).isDeprec = -1
                If Len(ln) > 0 Then parts(pidx).detail = Trim(parts(pidx).detail & Chr(10) & "Deprecated: " & ln)
            End If

        Case Else
            '' onbekende tag -> als detail bewaren
            If midx > 0 Then members(midx).detail = Trim(members(midx).detail & Chr(10) & "@" & tg & " " & ln)
            If pidx > 0 Then parts(pidx).detail = Trim(parts(pidx).detail & Chr(10) & "@" & tg & " " & ln)
        End Select
    Loop

    '' body opsplitsen in brief + detail
    Dim As String bf, dt
    bf = ""
    dt = ""
    body = Trim(body)
    If Len(body) > 0 Then
        p = InStr(body, ". ")
        k = InStr(body, Chr(10))
        If k > 0 And (p = 0 Or k < p) Then
            bf = Trim(Left(body, k - 1))
            dt = Trim(Mid(body, k + 1))
        ElseIf p > 0 Then
            bf = Trim(Left(body, p))
            dt = Trim(Mid(body, p + 2))
        Else
            bf = body
        End If
    End If
    If Len(briefOv) > 0 Then
        If Len(bf) > 0 Then dt = Trim(bf & Chr(10) & dt)
        bf = briefOv
    End If

    If midx > 0 Then
        If Len(bf) > 0 Then members(midx).brief = bf
        If Len(dt) > 0 Then members(midx).detail = Trim(dt & Chr(10) & members(midx).detail)
    End If
    If pidx > 0 Then
        If Len(bf) > 0 Then parts(pidx).brief = bf
        If Len(dt) > 0 Then parts(pidx).detail = Trim(dt & Chr(10) & parts(pidx).detail)
    End If
End Sub
