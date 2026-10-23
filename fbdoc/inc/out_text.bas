'' =====================================================================
''  fbdoc - Uitvoer: text, markdown, json, tree en de uitvoerhelpers
'' =====================================================================

Sub Emit(ByRef s As String)
    If outH > 0 Then
        Print #outH, s
    Else
        Print s
    End If
End Sub

Sub OpenOut(ByRef p As String)
    If outH > 0 Then
        Close #outH
        outH = 0
    End If
    outH = FreeFile
    If Open(p For Output As #outH) <> 0 Then
        outH = 0
        Say Tr1("ERROR: cannot write to %1", p)
        End 2
    End If
End Sub

Sub CloseOut()
    If outH > 0 Then
        Close #outH
        outH = 0
    End If
End Sub

Sub OutText()
    Dim As Integer i, k, pf, pc, j
    Dim As String s

    Emit "=====================================================================" 
    Emit " " & Tr("FreeBASIC documentation")
    If Len(opt.projName) > 0 Then Emit Tr1(" Project : %1", opt.projName)
    Emit Tr2(" Date    : %1 %2", Date, Time)
    Emit Tr2(" Parts   : %1   members: %2", Str(partCount), Str(memberCount))
    Emit "====================================================================="
    Emit ""

    For i = 1 To partCount
        If parts(i).isRef Then Continue For
        Emit "---------------------------------------------------------------------"
        s = KindLabel(parts(i).kind) & " " & parts(i).pname
        If Len(parts(i).stereo) > 0 Then s = s & "  (type " & parts(i).stereo & ")"
        Emit s
        Emit Tr2("  file    : %1:%2", NormSep(parts(i).filePath), Str(parts(i).lineNo))
        If Len(parts(i).pkg) > 0 Then Emit "  package : " & parts(i).pkg
        If parts(i).isAuto Then
            Emit "  " & parts(i).brief & "   [auto]"
        Else
            Emit "  " & parts(i).brief
        End If
        If Len(parts(i).detail) > 0 Then Emit "  " & ReplaceAll(parts(i).detail, Chr(10), Chr(10) & "  ")
        If Len(parts(i).authorTxt) > 0 Then Emit Tr1("  author  : %1", parts(i).authorTxt)
        Emit ""

        For k = 1 To memberCount
            If members(k).ownerPart <> i Then Continue For
            If members(k).isPrivate And opt.inclPriv = 0 Then Continue For

            s = "  "
            If members(k).kind = "function" Then
                If members(k).isPrivate Then s = s & "private "
                s = s & "function " & members(k).sigTxt
            Else
                s = s & members(k).kind & " " & members(k).sigTxt
            End If
            Emit s
            Emit Tr1("      line %1", Str(members(k).lineNo))
            If members(k).isDeprec Then Emit "      *** DEPRECATED ***"
            If members(k).isAuto Then
                Emit "      " & members(k).brief & "   [auto]"
            Else
                Emit "      " & members(k).brief
            End If
            If Len(members(k).detail) > 0 Then
                Emit "      " & ReplaceAll(members(k).detail, Chr(10), Chr(10) & "      ")
            End If
            pf = members(k).paramFirst
            pc = members(k).paramCnt
            For j = pf To pf + pc - 1
                If j < 1 Or j > paramCount Then Continue For
                s = "      @param  " & paramList(j).pname
                s = s & " [" & paramList(j).ptype
                If Len(paramList(j).pmode) > 0 Then s = s & ", " & paramList(j).pmode
                s = s & "] : " & paramList(j).pdesc
                If paramList(j).pauto Then s = s & "  [auto]"
                Emit s
            Next j
            If Len(members(k).retType) > 0 Then
                Emit "      @return " & members(k).retType & " : " & members(k).retDesc
            End If
            If Len(members(k).throwsTxt) > 0 Then
                Emit "      @throws " & ReplaceAll(members(k).throwsTxt, Chr(10), Chr(10) & "      @throws ")
            End If
            If Len(members(k).seeTxt) > 0 Then
                Emit "      @see    " & ReplaceAll(members(k).seeTxt, Chr(10), Chr(10) & "      @see    ")
            End If
            For j = 1 To edgeCount
                If edges(j).fromM <> k Then Continue For
                If edges(j).toM < 1 And edges(j).isSys And opt.inclExtern = 0 Then Continue For
                If edges(j).toM > 0 Then
                    s = "      -> " & Tr1("calls %1", MemberFullName(edges(j).toM))
                Else
                    s = "      -> " & Tr1("calls %1", edges(j).toNm) & " [extern]"
                End If
                If edges(j).cnt > 1 Then s = s & " (" & Str(edges(j).cnt) & "x)"
                If edges(j).kindC > 0 Then s = s & "  [" & EdgeKindLabel(edges(j).kindC) & "]"
                Emit s
            Next j
            For j = 1 To edgeCount
                If edges(j).toM <> k Then Continue For
                s = "      <- " & Tr1("from %1", MemberFullName(edges(j).fromM))
                If edges(j).kindC > 0 Then s = s & "  [" & EdgeKindLabel(edges(j).kindC) & "]"
                Emit s
            Next j
            Emit ""
        Next k
    Next i
End Sub

Sub OutMd()
    Dim As Integer i, k, pf, pc, j, hasAny
    Dim As String s

    Emit "# " & Tr("FreeBASIC documentation")
    Emit ""
    If Len(opt.projName) > 0 Then Emit "**Project:** " & opt.projName & "  "
    Emit Tr3("**Generated:** %1 %2 by %3", Date, Time, APP_NAME & " " & APP_VERSION) & "  "
    Emit Tr2("**Parts:** %1 | **Members:** %2", Str(partCount), Str(memberCount))
    Emit ""
    Emit "## " & Tr("Contents")
    Emit ""
    For i = 1 To partCount
        If parts(i).isRef Then Continue For
        Emit "- [" & KindLabel(parts(i).kind) & " " & parts(i).pname & "](#" & LCase(parts(i).kind) & "-" & LCase(parts(i).pname) & ")"
    Next i
    Emit ""

    For i = 1 To partCount
        Emit "---"
        Emit ""
        Emit "## " & KindLabel(parts(i).kind) & " " & parts(i).pname
        Emit ""
        s = "`" & NormSep(parts(i).filePath) & ":" & Str(parts(i).lineNo) & "`"
        If Len(parts(i).pkg) > 0 Then s = s & " &middot; package `" & parts(i).pkg & "`"
        If Len(parts(i).stereo) > 0 Then s = s & " &middot; type `" & parts(i).stereo & "`"
        Emit s
        Emit ""
        If parts(i).isAuto Then
            Emit "> " & parts(i).brief & " _(" & Tr("automatically generated") & ")_"
        Else
            Emit parts(i).brief
        End If
        Emit ""
        If Len(parts(i).detail) > 0 Then
            Emit ReplaceAll(parts(i).detail, Chr(10), "  " & Chr(10))
            Emit ""
        End If
        If Len(parts(i).authorTxt) > 0 Then
            Emit "**" & Tr("Author:") & "** " & parts(i).authorTxt
            Emit ""
        End If

        hasAny = 0
        For k = 1 To memberCount
            If members(k).ownerPart <> i Then Continue For
            If members(k).isPrivate And opt.inclPriv = 0 Then Continue For
            If members(k).kind <> "function" Then Continue For
            hasAny = -1
            Emit "### " & members(k).mname
            Emit ""
            Emit "```freebasic"
            s = ""
            If members(k).isPrivate Then s = "private "
            Emit s & "function " & members(k).sigTxt
            Emit "```"
            Emit ""
            If members(k).isDeprec Then
                Emit "> **DEPRECATED**"
                Emit ""
            End If
            If members(k).isAuto Then
                Emit members(k).brief & " _(" & Tr("automatically generated") & ")_"
            Else
                Emit members(k).brief
            End If
            Emit ""
            If Len(members(k).detail) > 0 Then
                Emit ReplaceAll(members(k).detail, Chr(10), "  " & Chr(10))
                Emit ""
            End If
            pf = members(k).paramFirst
            pc = members(k).paramCnt
            If pc > 0 Then
                Emit "| " & Tr("Parameter") & " | " & Tr("Type") & " | " & Tr("Direction") & " | " & Tr("Description") & " |"
                Emit "|---|---|---|---|"
                For j = pf To pf + pc - 1
                    If j < 1 Or j > paramCount Then Continue For
                    Emit "| `" & paramList(j).pname & "` | `" & paramList(j).ptype & "` | " & paramList(j).pmode & " | " & paramList(j).pdesc & " |"
                Next j
                Emit ""
            End If
            If Len(members(k).retType) > 0 Then
                Emit "**" & Tr("Returns") & "** `" & members(k).retType & "` &mdash; " & members(k).retDesc
                Emit ""
            End If
            If Len(members(k).throwsTxt) > 0 Then
                Emit "**" & Tr("Exceptions:") & "** " & ReplaceAll(members(k).throwsTxt, Chr(10), "; ")
                Emit ""
            End If
            If Len(members(k).seeTxt) > 0 Then
                Emit "**" & Tr("See also:") & "** " & ReplaceAll(members(k).seeTxt, Chr(10), ", ")
                Emit ""
            End If
            Emit "<sub>" & NormSep(parts(i).filePath) & ":" & Str(members(k).lineNo) & "</sub>"
            Emit ""
        Next k

        '' velden / constanten
        hasAny = 0
        For k = 1 To memberCount
            If members(k).ownerPart <> i Then Continue For
            If members(k).kind = "function" Then Continue For
            If hasAny = 0 Then
                Emit "### " & Tr("Fields and constants")
                Emit ""
                Emit "| " & Tr("Name") & " | " & Tr("Type") & " | " & Tr("Kind") & " | " & Tr("Description") & " |"
                Emit "|---|---|---|---|"
                hasAny = -1
            End If
            Emit "| `" & members(k).mname & "` | `" & members(k).retType & "` | " & members(k).kind & " | " & members(k).brief & " |"
        Next k
        If hasAny Then Emit ""
    Next i
End Sub

Sub OutJson()
    Dim As Integer i, k, pf, pc, j, firstM, firstP, firstPart
    Dim As String s

    Emit "{"
    Emit "  " & Chr(34) & "generator" & Chr(34) & ": " & Chr(34) & APP_NAME & " " & APP_VERSION & Chr(34) & ","
    Emit "  " & Chr(34) & "build" & Chr(34) & ": " & Chr(34) & APP_BUILD & Chr(34) & ","
    Emit "  " & Chr(34) & "generated" & Chr(34) & ": " & Chr(34) & Date & " " & Time & Chr(34) & ","
    Emit "  " & Chr(34) & "project" & Chr(34) & ": " & Chr(34) & JsonEsc(opt.projName) & Chr(34) & ","
    Emit "  " & Chr(34) & "parts" & Chr(34) & ": ["
    firstPart = -1
    For i = 1 To partCount
        If parts(i).isRef Then Continue For
        If firstPart = 0 Then Emit "    ,"
        firstPart = 0
        s = "    {"
        s = s & Chr(34) & "kind" & Chr(34) & ":" & Chr(34) & JsonEsc(parts(i).kind) & Chr(34) & ","
        s = s & Chr(34) & "name" & Chr(34) & ":" & Chr(34) & JsonEsc(parts(i).pname) & Chr(34) & ","
        s = s & Chr(34) & "stereotype" & Chr(34) & ":" & Chr(34) & JsonEsc(parts(i).stereo) & Chr(34) & ","
        s = s & Chr(34) & "package" & Chr(34) & ":" & Chr(34) & JsonEsc(parts(i).pkg) & Chr(34) & ","
        s = s & Chr(34) & "file" & Chr(34) & ":" & Chr(34) & JsonEsc(NormSep(parts(i).filePath)) & Chr(34) & ","
        s = s & Chr(34) & "line" & Chr(34) & ":" & Str(parts(i).lineNo) & ","
        s = s & Chr(34) & "brief" & Chr(34) & ":" & Chr(34) & JsonEsc(parts(i).brief) & Chr(34) & ","
        s = s & Chr(34) & "detail" & Chr(34) & ":" & Chr(34) & JsonEsc(parts(i).detail) & Chr(34) & ","
        s = s & Chr(34) & "autoGenerated" & Chr(34) & ":"
        If parts(i).isAuto Then s = s & "true," Else s = s & "false,"
        s = s & Chr(34) & "members" & Chr(34) & ": ["
        Emit s
        firstM = -1
        For k = 1 To memberCount
            If members(k).ownerPart <> i Then Continue For
            If members(k).isPrivate And opt.inclPriv = 0 Then Continue For
            If firstM = 0 Then Emit "      ,"
            firstM = 0
            s = "      {"
            s = s & Chr(34) & "kind" & Chr(34) & ":" & Chr(34) & JsonEsc(members(k).kind) & Chr(34) & ","
            s = s & Chr(34) & "name" & Chr(34) & ":" & Chr(34) & JsonEsc(members(k).mname) & Chr(34) & ","
            s = s & Chr(34) & "signature" & Chr(34) & ":" & Chr(34) & JsonEsc(members(k).sigTxt) & Chr(34) & ","
            s = s & Chr(34) & "line" & Chr(34) & ":" & Str(members(k).lineNo) & ","
            s = s & Chr(34) & "private" & Chr(34) & ":"
            If members(k).isPrivate Then s = s & "true," Else s = s & "false,"
            s = s & Chr(34) & "deprecated" & Chr(34) & ":"
            If members(k).isDeprec Then s = s & "true," Else s = s & "false,"
            s = s & Chr(34) & "autoGenerated" & Chr(34) & ":"
            If members(k).isAuto Then s = s & "true," Else s = s & "false,"
            s = s & Chr(34) & "brief" & Chr(34) & ":" & Chr(34) & JsonEsc(members(k).brief) & Chr(34) & ","
            s = s & Chr(34) & "detail" & Chr(34) & ":" & Chr(34) & JsonEsc(members(k).detail) & Chr(34) & ","
            s = s & Chr(34) & "returnType" & Chr(34) & ":" & Chr(34) & JsonEsc(members(k).retType) & Chr(34) & ","
            s = s & Chr(34) & "returnDesc" & Chr(34) & ":" & Chr(34) & JsonEsc(members(k).retDesc) & Chr(34) & ","
            s = s & Chr(34) & "callers" & Chr(34) & ":" & Str(CallerCount(k)) & ","
            s = s & Chr(34) & "params" & Chr(34) & ": ["
            Emit s
            pf = members(k).paramFirst
            pc = members(k).paramCnt
            firstP = -1
            For j = pf To pf + pc - 1
                If j < 1 Or j > paramCount Then Continue For
                s = "        "
                If firstP = 0 Then s = s & "," Else s = s & " "
                firstP = 0
                s = s & "{" & Chr(34) & "name" & Chr(34) & ":" & Chr(34) & JsonEsc(paramList(j).pname) & Chr(34) & ","
                s = s & Chr(34) & "type" & Chr(34) & ":" & Chr(34) & JsonEsc(paramList(j).ptype) & Chr(34) & ","
                s = s & Chr(34) & "mode" & Chr(34) & ":" & Chr(34) & JsonEsc(paramList(j).pmode) & Chr(34) & ","
                s = s & Chr(34) & "desc" & Chr(34) & ":" & Chr(34) & JsonEsc(paramList(j).pdesc) & Chr(34) & "}"
                Emit s
            Next j
            Emit "      ], " & Chr(34) & "calls" & Chr(34) & ": ["
            firstP = -1
            For j = 1 To edgeCount
                If edges(j).fromM <> k Then Continue For
                s = "        "
                If firstP = 0 Then s = s & "," Else s = s & " "
                firstP = 0
                s = s & "{" & Chr(34) & "target" & Chr(34) & ":" & Chr(34) & JsonEsc(edges(j).toNm) & Chr(34) & ","
                s = s & Chr(34) & "resolved" & Chr(34) & ":"
                If edges(j).toM > 0 Then
                    s = s & Chr(34) & JsonEsc(MemberFullName(edges(j).toM)) & Chr(34) & ","
                Else
                    s = s & "null,"
                End If
                s = s & Chr(34) & "external" & Chr(34) & ":"
                If edges(j).isExt Then s = s & "true," Else s = s & "false,"
                s = s & Chr(34) & "count" & Chr(34) & ":" & Str(edges(j).cnt) & ","
                s = s & Chr(34) & "callKind" & Chr(34) & ":" & Chr(34)
                If edges(j).kindC = 1 Then
                    s = s & "callback"
                ElseIf edges(j).kindC = 2 Then
                    s = s & "onException"
                Else
                    s = s & "direct"
                End If
                s = s & Chr(34) & ","
                s = s & Chr(34) & "line" & Chr(34) & ":" & Str(edges(j).lineNo) & "}"
                Emit s
            Next j
            Emit "      ]}"
        Next k
        Emit "    ]}"
    Next i
    Emit "  ]"
    Emit "}"
End Sub

Sub OutUndoc()
    Dim As Integer i, k, n
    Dim As String s
    n = 0
    s = Tr("Elements without source comments")
    Emit s
    Emit String(Len(s), "-")
    For i = 1 To partCount
        If parts(i).isRef Then Continue For
        If parts(i).isAuto Then
            Emit NormSep(parts(i).filePath) & ":" & Str(parts(i).lineNo) & ": " & KindLabel(parts(i).kind) & " " & parts(i).pname
            n = n + 1
        End If
    Next i
    For k = 1 To memberCount
        If members(k).isAuto = 0 Then Continue For
        If members(k).isPrivate And opt.inclPriv = 0 Then Continue For
        i = members(k).ownerPart
        If i < 1 Then i = 1
        Emit NormSep(parts(i).filePath) & ":" & Str(members(k).lineNo) & ": " & members(k).kind & " " & members(k).mname
        n = n + 1
    Next k
    Emit ""
    Emit Tr1("Total: %1", Str(n))
End Sub

Sub OutExternText()
    Dim As Integer k, p, q2
    Dim As String s, fn

    CollectExterns()
    Emit "---------------------------------------------------------------------"
    Emit Tr("Unresolved calls (not found in the scanned code):")
    Emit ""
    If extN = 0 Then
        Emit "  (" & Tr("none") & ")"
        Exit Sub
    End If
    For k = 1 To extN
        s = "  " & extQual(k)
        If Len(extPkg(k)) > 0 Then s = s & "   [" & extPkg(k) & "]"
        Emit s
        fn = extFn(k)
        p = 2
        Do
            q2 = InStr(p, fn, "|")
            If q2 = 0 Then Exit Do
            Emit "      " & Mid(fn, p, q2 - p)
            p = q2 + 1
        Loop While p < Len(fn)
    Next k
    Emit ""
    Emit Tr("Use --follow to read the included files as well, or give")
    Emit Tr("an extra path with --refs.")

    CollectAmbig()
    If ambN > 0 Then
        Emit ""
        Emit Tr("Not unambiguously resolved (name occurs in several parts):")
        For k = 1 To ambN
            Emit "  " & ambNm(k) & "   (" & Str(ambCnt(k)) & "x)"
        Next k
        Emit Tr("Qualify those calls in the source code, or narrow the scan.")
    End If
End Sub

Sub TreeBranch(ByVal midx As Integer, ByVal lvl As Integer, ByRef pfx As String)
    Dim As Integer e, n, seen, kids, idx
    Dim As String s

    If midx < 1 Then Exit Sub
    If lvl > opt.maxDepth Then
        Emit pfx & "  +-- ... (" & Tr1("maximum depth %1 reached", Str(opt.maxDepth)) & ")"
        Exit Sub
    End If

    '' aantal zichtbare kinderen bepalen
    kids = 0
    For e = 1 To edgeCount
        If edges(e).fromM <> midx Then Continue For
        If edges(e).toM < 1 And edges(e).isSys And opt.inclExtern = 0 Then Continue For
        kids = kids + 1
    Next e

    n = 0
    For e = 1 To edgeCount
        If edges(e).fromM <> midx Then Continue For
        If edges(e).toM < 1 And edges(e).isSys And opt.inclExtern = 0 Then Continue For
        n = n + 1
        idx = edges(e).toM

        If idx < 1 Then
            Emit pfx & "+-- " & edges(e).toNm & "  [extern]"
            Continue For
        End If

        s = MemberFullName(idx)
        If edges(e).cnt > 1 Then s = s & "  (" & Str(edges(e).cnt) & "x)"

        If onPath(idx) Then
            Emit pfx & "+-- " & s & "  [" & Tr("recursive") & "]"
            Continue For
        End If

        seen = 0
        If expandedM(idx) Then
            If CalleeCount(idx) > 0 Then seen = -1
        End If
        If seen Then
            Emit pfx & "+-- " & s & "  [" & Tr("see above") & "]"
            Continue For
        End If

        Emit pfx & "+-- " & s
        onPath(idx) = -1
        expandedM(idx) = -1
        If n < kids Then
            TreeBranch(idx, lvl + 1, pfx & "|   ")
        Else
            TreeBranch(idx, lvl + 1, pfx & "    ")
        End If
        onPath(idx) = 0
    Next e
End Sub

Sub OutTree()
    Dim As Integer i, k, roots, isolated
    Dim As String s

    ReDim onPath(1 To memberCount + 1)
    ReDim expandedM(1 To memberCount + 1)
    For i = 1 To memberCount + 1
        onPath(i) = 0
        expandedM(i) = 0
    Next i

    Emit "====================================================================="
    Emit " " & Tr("Call structure")
    If Len(opt.projName) > 0 Then Emit Tr1(" Project : %1", opt.projName)
    Emit Tr2(" Date    : %1 %2", Date, Time)
    Emit Tr1(" Relations: %1", Str(edgeCount))
    Emit "====================================================================="
    Emit ""
    Emit Tr("Entry points (functions not called within the scanned code):")
    Emit ""

    roots = 0
    For k = 1 To memberCount
        If members(k).kind <> "function" Then Continue For
        If members(k).isPrivate And opt.inclPriv = 0 Then Continue For
        If CallerCount(k) > 0 Then Continue For
        If CalleeCount(k) = 0 Then Continue For
        roots = roots + 1
        s = MemberFullName(k)
        Emit s
        onPath(k) = -1
        expandedM(k) = -1
        TreeBranch(k, 1, "")
        onPath(k) = 0
        Emit ""
    Next k
    If roots = 0 Then
        Emit "  (" & Tr("none; possibly everything is interconnected or no calls were recognised") & ")"
        Emit ""
    End If

    Emit "---------------------------------------------------------------------"
    Emit Tr("Possibly unused (no caller, no property binding, no entry point):")
    isolated = 0
    For k = 1 To memberCount
        If DeadKind(k) <> 1 Then Continue For
        isolated = isolated + 1
        i = members(k).ownerPart
        Emit "  " & MemberFullName(k) & "   (" & PathBase(parts(i).filePath) & ":" & Str(members(k).lineNo) & ")"
    Next k
    If isolated = 0 Then Emit "  (" & Tr("none") & ")"
    Emit ""

    Emit "---------------------------------------------------------------------"
    Emit Tr("Standalone functions (no callers and no calls):")
    isolated = 0
    For k = 1 To memberCount
        If members(k).kind <> "function" Then Continue For
        If members(k).isPrivate And opt.inclPriv = 0 Then Continue For
        If CallerCount(k) > 0 Or CalleeCount(k) > 0 Then Continue For
        isolated = isolated + 1
        i = members(k).ownerPart
        Emit "  " & MemberFullName(k) & "   (" & PathBase(parts(i).filePath) & ":" & Str(members(k).lineNo) & ")"
    Next k
    If isolated = 0 Then Emit "  (" & Tr("none") & ")"
    Emit ""
    Emit Tr("Note: calls via delegates, dynamic dictionary access or")
    Emit Tr("generated Java are not detected.")
    Emit ""
    OutExternText()
End Sub
