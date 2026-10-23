'' =====================================================================
''  fbdoc - Automatische beschrijvingen bij ontbrekend commentaar
'' =====================================================================

Function Humanize(ByRef s As String) As String
    Dim As String res, c, nx, pv, w
    Dim As Integer i, n
    res = ""
    n = Len(s)
    For i = 1 To n
        c = Mid(s, i, 1)
        If c = "_" Or c = "-" Then
            res = res & " "
            Continue For
        End If
        If i > 1 Then
            pv = Mid(s, i - 1, 1)
            nx = ""
            If i < n Then nx = Mid(s, i + 1, 1)
            If c >= "A" And c <= "Z" Then
                If (pv >= "a" And pv <= "z") Or IsDigitCh(pv) Then
                    res = res & " "
                ElseIf (pv >= "A" And pv <= "Z") And (nx >= "a" And nx <= "z") Then
                    res = res & " "
                End If
            ElseIf IsDigitCh(c) Then
                If IsDigitCh(pv) = 0 Then res = res & " "
            End If
        End If
        res = res & c
    Next i

    '' woorden normaliseren: acronyms met hoofdletters laten staan
    Dim As String outS, tokW
    Dim As Integer p
    outS = ""
    res = Trim(res)
    Do
        p = InStr(res, " ")
        If p = 0 Then
            tokW = res
            res = ""
        Else
            tokW = Left(res, p - 1)
            res = Trim(Mid(res, p + 1))
        End If
        If Len(tokW) > 0 Then
            If tokW <> UCase(tokW) Then tokW = LCase(tokW)
            If Len(outS) > 0 Then outS = outS & " "
            outS = outS & tokW
        End If
        If Len(res) = 0 Then Exit Do
    Loop
    Return outS
End Function

Function GenMemberBrief(ByVal midx As Integer) As String
    Dim As String words, verb, rest, s
    Dim As Integer p

    If members(midx).kind = "variable" Then Return Tr1("Variable %1.", Humanize(members(midx).mname))
    If members(midx).kind = "constant" Then Return Tr1("Constant %1.", Humanize(members(midx).mname))
    If members(midx).kind = "enum" Then Return Tr1("Value %1.", Humanize(members(midx).mname))

    words = Humanize(members(midx).mname)
    p = InStr(words, " ")
    If p = 0 Then
        verb = LCase(words)
        rest = ""
    Else
        verb = LCase(Left(words, p - 1))
        rest = Trim(Mid(words, p + 1))
    End If
    If Len(rest) = 0 Then rest = Tr("the data")

    '' een zin per werkwoord, met %1 voor de rest van de naam, zodat een
    '' vertaling de woordvolgorde zelf kan kiezen ("Haalt %1 op.")
    s = ""
    Select Case verb
    Case "get", "fetch", "retrieve", "read", "obtain", "haal", "lees"
        s = Tr1("Retrieves %1.", rest)
    Case "load", "laad"
        s = Tr1("Loads %1.", rest)
    Case "set", "assign", "zet"
        s = Tr1("Sets %1.", rest)
    Case "is", "has", "can", "must", "should", "exists", "contains", "equals"
        s = Tr1("Determines whether %1 applies.", rest)
    Case "validate", "check", "verify", "valideer", "controleer"
        s = Tr1("Validates %1.", rest)
    Case "calc", "calculate", "compute", "sum", "total", "bereken"
        s = Tr1("Calculates %1.", rest)
    Case "create", "make", "build", "generate", "new", "maak", "genereer"
        s = Tr1("Creates %1.", rest)
    Case "add", "append", "insert", "push", "voeg"
        s = Tr1("Adds %1.", rest)
    Case "delete", "remove", "clear", "drop", "purge", "verwijder"
        s = Tr1("Deletes %1.", rest)
    Case "update", "modify", "change", "wijzig", "werk"
        s = Tr1("Updates %1.", rest)
    Case "save", "store", "persist", "write", "commit", "bewaar", "sla"
        s = Tr1("Stores %1.", rest)
    Case "find", "search", "lookup", "query", "select", "zoek"
        s = Tr1("Searches for %1.", rest)
    Case "convert", "to", "parse", "format", "transform", "map", "converteer"
        s = Tr1("Converts %1.", rest)
    Case "init", "initialize", "initialise", "setup", "start", "prepare"
        s = Tr1("Initialises %1.", rest)
    Case "process", "handle", "execute", "perform", "do", "exec", "verwerk"
        s = Tr1("Processes %1.", rest)
    Case "send", "post", "submit", "publish", "verstuur", "verzend"
        s = Tr1("Sends %1.", rest)
    Case "open"
        s = Tr1("Opens %1.", rest)
    Case "close", "finish", "stop"
        s = Tr1("Closes %1.", rest)
    Case "show", "display", "render", "draw", "toon"
        s = Tr1("Displays %1.", rest)
    Case "hide", "verberg"
        s = Tr1("Hides %1.", rest)
    Case "refresh", "reload", "reset", "vernieuw"
        s = Tr1("Refreshes %1.", rest)
    Case "count", "tel"
        s = Tr1("Counts %1.", rest)
    Case "sort", "order", "sorteer"
        s = Tr1("Sorts %1.", rest)
    Case "filter"
        s = Tr1("Filters %1.", rest)
    Case "copy", "clone", "duplicate", "kopieer"
        s = Tr1("Copies %1.", rest)
    Case "import", "importeer"
        s = Tr1("Imports %1.", rest)
    Case "export", "exporteer"
        s = Tr1("Exports %1.", rest)
    Case "log", "trace", "audit"
        s = Tr1("Logs %1.", rest)
    Case "print"
        s = Tr1("Prints %1.", rest)
    Case "on", "before", "after"
        s = Tr1("Event handler for %1.", rest)
    Case "main"
        s = Tr1("Entry point of %1.", rest)
    Case Else
        s = Tr1("Function %1.", Humanize(members(midx).mname))
    End Select

    '' returntype toevoegen
    If Len(members(midx).retType) > 0 Then
        s = s & " " & Tr1("Returns %1.", members(midx).retType)
    End If
    Return s
End Function

Function GenPartBrief(ByVal pidx As Integer) As String
    Dim As String s, lbl
    Dim As Integer k, cnt
    lbl = KindLabel(parts(pidx).kind)
    cnt = 0
    For k = 1 To memberCount
        If members(k).ownerPart = pidx Then
            If members(k).kind = "function" Then cnt = cnt + 1
        End If
    Next k
    s = lbl & " " & Humanize(parts(pidx).pname) & "."
    If cnt > 0 Then s = s & " " & Tr1("Contains %1 function(s).", Str(cnt))
    Return s
End Function

Sub GenerateMissing()
    Dim As Integer i, k, pf, pc

    For i = 1 To partCount
        If Len(Trim(parts(i).brief)) = 0 Then
            parts(i).isAuto = -1
            If opt.doGen Then parts(i).brief = GenPartBrief(i)
        End If
    Next i

    For i = 1 To memberCount
        If Len(Trim(members(i).brief)) = 0 Then
            members(i).isAuto = -1
            If opt.doGen Then members(i).brief = GenMemberBrief(i)
        End If
        pf = members(i).paramFirst
        pc = members(i).paramCnt
        For k = pf To pf + pc - 1
            If k >= 1 And k <= paramCount Then
                If Len(Trim(paramList(k).pdesc)) = 0 Then
                    paramList(k).pauto = -1
                    If opt.doGen Then paramList(k).pdesc = Humanize(paramList(k).pname)
                End If
            End If
        Next k
        If Len(members(i).retType) > 0 And Len(Trim(members(i).retDesc)) = 0 Then
            If opt.doGen Then
                members(i).retDesc = Tr1("value of type %1", members(i).retType)
            End If
        End If
    Next i
End Sub
