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
    Dim As String words, verb, rest, pre, post, s, fallback
    Dim As Integer p, nl

    nl = 0
    If LC(opt.langTxt) = "nl" Then nl = -1

    If members(midx).kind = "variable" Then
        If nl Then Return "Variabele " & Humanize(members(midx).mname) & "."
        Return "Variable " & Humanize(members(midx).mname) & "."
    End If
    If members(midx).kind = "constant" Then
        If nl Then Return "Constante " & Humanize(members(midx).mname) & "."
        Return "Constant " & Humanize(members(midx).mname) & "."
    End If
    If members(midx).kind = "enum" Then
        If nl Then Return "Waarde " & Humanize(members(midx).mname) & "."
        Return "Value " & Humanize(members(midx).mname) & "."
    End If

    words = Humanize(members(midx).mname)
    p = InStr(words, " ")
    If p = 0 Then
        verb = LCase(words)
        rest = ""
    Else
        verb = LCase(Left(words, p - 1))
        rest = Trim(Mid(words, p + 1))
    End If

    If nl Then fallback = "de gegevens" Else fallback = "the data"
    If Len(rest) = 0 Then rest = fallback

    pre = ""
    post = ""
    Select Case verb
    Case "get", "fetch", "retrieve", "read", "obtain", "haal", "lees"
        pre = Pick("Haalt ", "Retrieves ", nl)
        post = Pick(" op.", ".", nl)
    Case "load", "laad"
        pre = Pick("Laadt ", "Loads ", nl)
        post = "."
    Case "set", "assign", "zet"
        pre = Pick("Stelt ", "Sets ", nl)
        post = Pick(" in.", ".", nl)
    Case "is", "has", "can", "must", "should", "exists", "contains", "equals"
        pre = Pick("Bepaalt of ", "Determines whether ", nl)
        post = Pick(" van toepassing is.", " applies.", nl)
    Case "validate", "check", "verify", "valideer", "controleer"
        pre = Pick("Valideert ", "Validates ", nl)
        post = "."
    Case "calc", "calculate", "compute", "sum", "total", "bereken"
        pre = Pick("Berekent ", "Calculates ", nl)
        post = "."
    Case "create", "make", "build", "generate", "new", "maak", "genereer"
        pre = Pick("Creeert ", "Creates ", nl)
        post = "."
    Case "add", "append", "insert", "push", "voeg"
        pre = Pick("Voegt ", "Adds ", nl)
        post = Pick(" toe.", ".", nl)
    Case "delete", "remove", "clear", "drop", "purge", "verwijder"
        pre = Pick("Verwijdert ", "Deletes ", nl)
        post = "."
    Case "update", "modify", "change", "wijzig", "werk"
        pre = Pick("Werkt ", "Updates ", nl)
        post = Pick(" bij.", ".", nl)
    Case "save", "store", "persist", "write", "commit", "bewaar", "sla"
        pre = Pick("Slaat ", "Stores ", nl)
        post = Pick(" op.", ".", nl)
    Case "find", "search", "lookup", "query", "select", "zoek"
        pre = Pick("Zoekt ", "Searches for ", nl)
        post = "."
    Case "convert", "to", "parse", "format", "transform", "map", "converteer"
        pre = Pick("Converteert ", "Converts ", nl)
        post = "."
    Case "init", "initialize", "initialise", "setup", "start", "prepare"
        pre = Pick("Initialiseert ", "Initialises ", nl)
        post = "."
    Case "process", "handle", "execute", "perform", "do", "exec", "verwerk"
        pre = Pick("Verwerkt ", "Processes ", nl)
        post = "."
    Case "send", "post", "submit", "publish", "verstuur", "verzend"
        pre = Pick("Verzendt ", "Sends ", nl)
        post = "."
    Case "open"
        pre = Pick("Opent ", "Opens ", nl)
        post = "."
    Case "close", "finish", "stop"
        pre = Pick("Sluit ", "Closes ", nl)
        post = Pick(" af.", ".", nl)
    Case "show", "display", "render", "draw", "toon"
        pre = Pick("Toont ", "Displays ", nl)
        post = "."
    Case "hide", "verberg"
        pre = Pick("Verbergt ", "Hides ", nl)
        post = "."
    Case "refresh", "reload", "reset", "vernieuw"
        pre = Pick("Vernieuwt ", "Refreshes ", nl)
        post = "."
    Case "count", "tel"
        pre = Pick("Telt ", "Counts ", nl)
        post = "."
    Case "sort", "order", "sorteer"
        pre = Pick("Sorteert ", "Sorts ", nl)
        post = "."
    Case "filter"
        pre = Pick("Filtert ", "Filters ", nl)
        post = "."
    Case "copy", "clone", "duplicate", "kopieer"
        pre = Pick("Kopieert ", "Copies ", nl)
        post = "."
    Case "import", "importeer"
        pre = Pick("Importeert ", "Imports ", nl)
        post = "."
    Case "export", "exporteer"
        pre = Pick("Exporteert ", "Exports ", nl)
        post = "."
    Case "log", "trace", "audit"
        pre = Pick("Logt ", "Logs ", nl)
        post = "."
    Case "print"
        pre = Pick("Print ", "Prints ", nl)
        post = "."
    Case "on", "before", "after"
        pre = Pick("Event-handler voor ", "Event handler for ", nl)
        post = "."
    Case "main"
        pre = Pick("Startpunt van ", "Entry point of ", nl)
        post = "."
    Case Else
        pre = Pick("Functie ", "Function ", nl)
        post = "."
        rest = Humanize(members(midx).mname)
    End Select

    s = pre & rest & post

    '' returntype toevoegen
    If Len(members(midx).retType) > 0 Then
        If nl Then
            s = s & " Retourneert " & members(midx).retType & "."
        Else
            s = s & " Returns " & members(midx).retType & "."
        End If
    End If
    Return s
End Function

Function GenPartBrief(ByVal pidx As Integer) As String
    Dim As String s, lbl
    Dim As Integer nl, k, cnt
    nl = 0
    If LC(opt.langTxt) = "nl" Then nl = -1
    lbl = KindLabel(parts(pidx).kind)
    cnt = 0
    For k = 1 To memberCount
        If members(k).ownerPart = pidx Then
            If members(k).kind = "function" Then cnt = cnt + 1
        End If
    Next k
    If nl Then
        s = lbl & " " & Humanize(parts(pidx).pname) & "."
        If cnt > 0 Then s = s & " Bevat " & Str(cnt) & " functie(s)."
    Else
        s = lbl & " " & Humanize(parts(pidx).pname) & "."
        If cnt > 0 Then s = s & " Contains " & Str(cnt) & " function(s)."
    End If
    Return s
End Function

Sub GenerateMissing()
    Dim As Integer i, k, pf, pc, nl
    nl = 0
    If LC(opt.langTxt) = "nl" Then nl = -1

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
                If nl Then
                    members(i).retDesc = "waarde van het type " & members(i).retType
                Else
                    members(i).retDesc = "value of type " & members(i).retType
                End If
            End If
        End If
    Next i
End Sub
