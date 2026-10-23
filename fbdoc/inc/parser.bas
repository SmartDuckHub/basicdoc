'' =====================================================================
''  fbdoc - Parser: declaraties, parameters, signaturen en sleutelwoorden
'' =====================================================================

Function SkipQual(ByVal i As Integer) As Integer
    '' verwacht een identifier, slaat a.b.c over
    If i > tokCount Then Return i
    If tokKind(i) <> TK_IDENT Then Return i
    i = i + 1
    While i < tokCount
        If tokText(i) = "." And tokKind(i + 1) = TK_IDENT Then
            i = i + 2
        Else
            Exit While
        End If
    Wend
    Return i
End Function

Function SkipBraces(ByVal i As Integer) As Integer
    Dim As Integer d
    If i > tokCount Then Return i
    If tokText(i) <> "{" Then Return i
    d = 0
    While i <= tokCount
        If tokText(i) = "{" Then d = d + 1
        If tokText(i) = "}" Then
            d = d - 1
            If d = 0 Then Return i + 1
        End If
        i = i + 1
    Wend
    Return i
End Function

Function SkipToSemi(ByVal i As Integer) As Integer
    Dim As Integer d
    Dim As String t
    d = 0
    While i <= tokCount
        t = tokText(i)
        If t = "(" Or t = "[" Or t = "{" Then d = d + 1
        If t = ")" Or t = "]" Or t = "}" Then d = d - 1
        If t = ";" And d <= 0 Then Return i + 1
        i = i + 1
    Wend
    Return i
End Function

Function NewPart(ByRef k As String, ByRef nm As String, ByRef fpath As String, ByVal ln As Integer, ByRef pkg As String) As Integer
    If partCount + 1 > partCap Then
        If partCap = 0 Then partCap = 64 Else partCap = partCap * 2
        ReDim Preserve parts(1 To partCap)
    End If
    partCount = partCount + 1
    parts(partCount).kind     = k
    parts(partCount).pname    = nm
    parts(partCount).stereo   = ""
    parts(partCount).pkg      = pkg
    parts(partCount).filePath = fpath
    parts(partCount).lineNo   = ln
    parts(partCount).brief    = ""
    parts(partCount).detail   = ""
    parts(partCount).isAuto   = 0
    parts(partCount).isDeprec = 0
    parts(partCount).isRef    = parsingRefs
    Return partCount
End Function

Function NewMember(ByRef k As String, ByRef nm As String, ByVal owner As Integer, ByVal ln As Integer) As Integer
    If memberCount + 1 > memberCap Then
        If memberCap = 0 Then memberCap = 256 Else memberCap = memberCap * 2
        ReDim Preserve members(1 To memberCap)
    End If
    memberCount = memberCount + 1
    members(memberCount).kind       = k
    members(memberCount).mname      = nm
    members(memberCount).sigTxt     = ""
    members(memberCount).retType    = ""
    members(memberCount).retDesc    = ""
    members(memberCount).brief      = ""
    members(memberCount).detail     = ""
    members(memberCount).throwsTxt  = ""
    members(memberCount).seeTxt     = ""
    members(memberCount).authorTxt  = ""
    members(memberCount).sinceTxt   = ""
    members(memberCount).isPrivate  = 0
    members(memberCount).isDeprec   = 0
    members(memberCount).isProto    = 0
    members(memberCount).isAuto     = 0
    members(memberCount).isBound    = 0
    members(memberCount).lineNo     = ln
    members(memberCount).ownerPart  = owner
    members(memberCount).paramFirst = 0
    members(memberCount).paramCnt   = 0
    Return memberCount
End Function

Sub AddParamTok(ByVal midx As Integer, ByVal a As Integer, ByVal b As Integer)
    Dim As String md, nm, tp
    Dim As Integer e

    If a > b Then Exit Sub
    e = b
    md = ""
    Select Case LC(tokText(e))
    Case "in", "out", "inout"
        md = LC(tokText(e))
        If md = "inout" Then md = "inOut"
        e = e - 1
    End Select
    If e < a Then Exit Sub

    nm = tokText(a)
    If a + 1 <= e Then tp = JoinTok(a + 1, e) Else tp = ""

    If paramCount + 1 > paramCap Then
        If paramCap = 0 Then paramCap = 512 Else paramCap = paramCap * 2
        ReDim Preserve paramList(1 To paramCap)
    End If
    paramCount = paramCount + 1
    paramList(paramCount).pname = nm
    paramList(paramCount).ptype = tp
    paramList(paramCount).pmode = md
    paramList(paramCount).pdesc = ""
    paramList(paramCount).pauto = 0

    If members(midx).paramCnt = 0 Then members(midx).paramFirst = paramCount
    members(midx).paramCnt = members(midx).paramCnt + 1
End Sub

'' =====================================================================
''  hoofdparser
'' =====================================================================
'' Containers waar leden in zitten.
Function IsPartKw(ByRef t As String) As Integer
    Select Case t
    Case "type", "union", "enum", "namespace", "class"
        Return -1
    End Select
    Return 0
End Function

'' Procedurevormen.
Function IsProcKw(ByRef t As String) As Integer
    Select Case t
    Case "sub", "function", "property", "constructor", "destructor", "operator"
        Return -1
    End Select
    Return 0
End Function

'' Modifiers die voor een declaratie mogen staan.
Function IsModifierKw(ByRef t As String) As Integer
    Select Case t
    Case "private", "public", "protected", "static", "shared", "overload", _
         "virtual", "abstract", "const", "cdecl", "stdcall", "pascal", "export"
        Return -1
    End Select
    Return 0
End Function

'' Sleutelwoorden die nooit een aanroep zijn, ook al staan ze voor een haakje.
'' Dit is de FreeBASIC-woordenlijst; zonder deze filter zou elke Print of
'' Mid als functieaanroep in de graaf terechtkomen.
Function IsCallExcluded(ByRef t As String) As Integer
    Select Case t
    Case "if", "then", "else", "elseif", "end", "endif", "while", "wend", _
         "do", "loop", "for", "next", "step", "to", "each", "select", "case", _
         "with", "scope", "exit", "continue", "goto", "gosub", "return", _
         "sub", "function", "property", "constructor", "destructor", "operator", _
         "declare", "dim", "redim", "preserve", "erase", "var", "const", _
         "shared", "static", "common", "extern", "private", "public", "protected", _
         "type", "union", "enum", "namespace", "class", "as", "is", "byref", "byval", _
         "any", "ptr", "pointer", "new", "delete", "using", "with", "let", _
         "and", "or", "xor", "not", "eqv", "imp", "mod", "shl", "shr", "andalso", "orelse", _
         "print", "write", "input", "line", "open", "close", "put", "get", "seek", _
         "lock", "unlock", "kill", "name", "mkdir", "rmdir", "chdir", "reset", _
         "sleep", "beep", "randomize", "swap", "rem", "data", "read", "restore", _
         "option", "on", "error", "resume", "stop", "run", "chain", "system", _
         "screen", "color", "locate", "cls", "draw", "circle", "paint", "pset", _
         "preset", "palette", "view", "window", "width", "pcopy", "point", _
         "abs", "sgn", "int", "fix", "frac", "sqr", "exp", "log", "sin", "cos", _
         "tan", "atn", "asin", "acos", "atan2", "rnd", "timer", "time", "date", _
         "len", "sizeof", "typeof", "offsetof", "iif", "cast", "cptr", "cint", _
         "clng", "clngint", "cshort", "cbyte", "cubyte", "cushort", "cuint", _
         "culng", "culngint", "csng", "cdbl", "cbool", "csign", "cunsg", _
         "str", "val", "valint", "vallng", "valuint", "valulng", "hex", "oct", _
         "bin", "chr", "asc", "wchr", "wstr", "wbin", "whex", "woct", _
         "left", "right", "mid", "instr", "instrrev", "ltrim", "rtrim", "trim", _
         "lcase", "ucase", "space", "string", "wspace", "wstring", "format", _
         "lbound", "ubound", "va_arg", "va_first", "va_next", "sadd", "strptr", _
         "procptr", "varptr", "clear", "allocate", "callocate", "reallocate", _
         "deallocate", "peek", "poke", "field", "threadcall", "assert", _
         "freefile", "eof", "lof", "loc", "environ", "command", "exec", "shell", _
         "dir", "curdir", "exepath", "fileexists", "filecopy", "filelen", _
         "inkey", "getkey", "multikey", "getmouse", "setmouse", "imagecreate", _
         "imagedestroy", "bload", "bsave", "flip", "screenres", "screenlock", _
         "screenunlock", "screeninfo", "screenptr", "windowtitle", "cvi", "cvl", _
         "cvs", "cvd", "mki", "mkl", "mks", "mkd", "csrlin", "pos", "tab", "spc"
        Return -1
    End Select
    Return 0
End Function

'' In FreeBASIC bestaat het onderscheid systeembibliotheek/eigen code niet
'' zoals in EGL; FreeBASIC-runtimefuncties vallen al onder IsCallExcluded.
Function IsSysLibName(ByRef t As String) As Integer
    Return 0
End Function

Function IsBuiltinMethod(ByRef t As String) As Integer
    Return 0
End Function

'' Blokken die met een eigen End of eindwoord sluiten; alleen nodig om
'' binnen een procedure niet in de war te raken.
Function IsBlockKw(ByRef t As String) As Integer
    Return 0
End Function

Function KindLabel(ByRef k As String) As String
    Select Case LC(k)
    Case "module"
        Return Tr("Module")
    Case "type"
        Return Tr("Type")
    Case "union"
        Return Tr("Union")
    Case "enum"
        Return Tr("Enumeration")
    Case "namespace"
        Return Tr("Namespace")
    Case "class"
        Return Tr("Class")
    Case "file"
        Return Tr("File")
    End Select
    Return k
End Function

Sub ParseTokens(ByRef fpath As String)
    Dim As Integer i, atStart, stmtDoc, isPriv, isProto, curFunc
    Dim As Integer stkPart(1 To 32), stkTop, curPart, modPart
    Dim As Integer midx, pidx, d2, segStart, closeI, k2, jj
    Dim As String t, nm, k, tp, ns, callNm, qualNm

    i = 1
    atStart = -1
    stmtDoc = -1
    stkTop = 0
    isPriv = 0
    curFunc = -1
    modPart = -1
    ns = ""
    impCount = 0

    While i <= tokCount
        If tokKind(i) = TK_EOL Then
            i = i + 1
            atStart = -1
            stmtDoc = -1
            isPriv = 0
            Continue While
        End If

        t = LC(tokText(i))

        If atStart Then
            If tokDoc(i) >= 0 Then stmtDoc = tokDoc(i)
        End If

        If stkTop > 0 Then curPart = stkPart(stkTop) Else curPart = -1

        '' ---------- binnen een procedure: alleen aanroepen verzamelen ----------
        If curFunc > 0 Then
            If atStart And t = "end" Then
                If i < tokCount Then
                    If IsProcKw(LC(tokText(i + 1))) Then
                        curFunc = -1
                        i = i + 2
                        atStart = 0
                        Continue While
                    End If
                End If
            End If

            '' verwijzing naar een procedure: p = @mijnSub
            If tokText(i) = "@" And i < tokCount Then
                If tokKind(i + 1) = TK_IDENT Then
                    callNm = QualNameStr(i + 1)
                    If Len(callNm) > 0 Then AddCall(curFunc, callNm, tokLine(i + 1), 3)
                End If
                i = i + 1
                atStart = 0
                Continue While
            End If

            If tokKind(i) = TK_IDENT Then
                If IsCallExcluded(t) = 0 Then
                    k2 = CallTargetAt(i, callNm)
                    If k2 > 0 Then
                        '' naam gevolgd door een haakje
                        AddCall(curFunc, callNm, tokLine(i), 0)
                        i = k2
                        atStart = 0
                        Continue While
                    ElseIf atStart Then
                        '' aanroep zonder haakjes: MijnSub arg1, arg2
                        callNm = QualNameStr(i)
                        If Len(callNm) > 0 Then AddCall(curFunc, callNm, tokLine(i), 0)
                    End If
                End If
            End If

            i = i + 1
            atStart = 0
            Continue While
        End If

        '' ---------- buiten een procedure: declaraties ----------
        If atStart = 0 Then
            i = i + 1
            Continue While
        End If

        '' modifiers overslaan, private onthouden
        While i <= tokCount
            t = LC(tokText(i))
            If IsModifierKw(t) = 0 Then Exit While
            If t = "private" Then isPriv = -1
            If t = "const" Then Exit While
            i = i + 1
        Wend
        If i > tokCount Then Exit While
        t = LC(tokText(i))

        isProto = 0
        If t = "declare" Then
            isProto = -1
            i = i + 1
            If i > tokCount Then Exit While
            t = LC(tokText(i))
        End If

        Select Case t

        Case "namespace"
            i = i + 1
            nm = QualNameStr(i)
            pidx = NewPart("namespace", nm, fpath, tokLine(i), ns)
            If stmtDoc >= 0 Then ApplyDoc(stmtDoc, pidx, -1)
            stmtDoc = -1
            If stkTop < 32 Then
                stkTop = stkTop + 1
                stkPart(stkTop) = pidx
            End If
            If Len(ns) > 0 Then ns = ns & "." & nm Else ns = nm
            i = SkipQual(i)
            atStart = 0

        Case "type", "union", "enum", "class"
            '' Type MijnType As Integer  is een alias, geen container
            If i + 2 <= tokCount And LC(tokText(i + 2)) = "as" Then
                nm = tokText(i + 1)
                midx = NewMember("typealias", nm, curPart, tokLine(i))
                If curPart < 0 Then
                    If modPart < 0 Then modPart = NewPart("module", PathBase(fpath), fpath, 1, ns)
                    members(midx).ownerPart = modPart
                End If
                members(midx).retType = JoinTok(i + 3, i + 3)
                members(midx).sigTxt = nm & " As " & members(midx).retType
                If stmtDoc >= 0 Then ApplyDoc(stmtDoc, -1, midx)
                stmtDoc = -1
                i = i + 3
                atStart = 0
            Else
                nm = ""
                If i < tokCount Then nm = tokText(i + 1)
                If Len(nm) = 0 Or tokKind(i + 1) <> TK_IDENT Then
                    i = i + 1
                    atStart = 0
                Else
                    pidx = NewPart(t, nm, fpath, tokLine(i), ns)
                    If stmtDoc >= 0 Then ApplyDoc(stmtDoc, pidx, -1)
                    stmtDoc = -1
                    '' extends Basis
                    i = i + 2
                    If i <= tokCount Then
                        If LC(tokText(i)) = "extends" Then
                            parts(pidx).stereo = tokText(i + 1)
                            i = i + 2
                        End If
                    End If
                    If stkTop < 32 Then
                        stkTop = stkTop + 1
                        stkPart(stkTop) = pidx
                    End If
                    atStart = 0
                End If
            End If

        Case "end"
            k = ""
            If i < tokCount Then k = LC(tokText(i + 1))
            Select Case k
            Case "type", "union", "enum", "namespace", "class"
                If stkTop > 0 Then
                    If k = "namespace" Then
                        d2 = 0
                        For k2 = Len(ns) To 1 Step -1
                            If Mid(ns, k2, 1) = "." Then
                                d2 = k2
                                Exit For
                            End If
                        Next k2
                        If d2 > 0 Then ns = Left(ns, d2 - 1) Else ns = ""
                    End If
                    stkTop = stkTop - 1
                End If
                i = i + 2
            Case Else
                i = i + 1
            End Select
            atStart = 0

        Case "sub", "function", "property", "constructor", "destructor", "operator"
            k = t
            i = i + 1
            nm = ""
            qualNm = ""
            If i <= tokCount Then
                If tokKind(i) = TK_IDENT Then
                    nm = tokText(i)
                    '' methode-implementatie: Function MijnType.doeIets(...)
                    If i + 1 <= tokCount Then
                        If tokText(i + 1) = "." And i + 2 <= tokCount Then
                            If tokKind(i + 2) = TK_IDENT Then
                                qualNm = nm
                                nm = tokText(i + 2)
                                i = i + 2
                            End If
                        End If
                    End If
                    i = i + 1
                ElseIf k = "operator" Then
                    '' operatoren hebben een teken als naam
                    nm = tokText(i)
                    i = i + 1
                    While i <= tokCount
                        If tokText(i) = "(" Then Exit While
                        If tokKind(i) = TK_EOL Then Exit While
                        nm = nm & tokText(i)
                        i = i + 1
                    Wend
                End If
            End If
            If Len(nm) = 0 Then nm = k

            pidx = curPart
            If Len(qualNm) > 0 Then
                d2 = FindPartByName(qualNm)
                If d2 > 0 Then pidx = d2
            End If
            If pidx < 0 Then
                If modPart < 0 Then modPart = NewPart("module", PathBase(fpath), fpath, 1, ns)
                pidx = modPart
            End If

            midx = NewMember("function", nm, pidx, tokLine(i - 1))
            members(midx).isPrivate = isPriv
            isPriv = 0
            If k <> "sub" And k <> "function" Then members(midx).kind = "function"

            '' parameterlijst
            If i <= tokCount Then
                If tokText(i) = "(" Then
                    i = i + 1
                    d2 = 0
                    segStart = i
                    While i <= tokCount
                        t = tokText(i)
                        If tokKind(i) = TK_EOL Then Exit While
                        If t = "(" Or t = "[" Then d2 = d2 + 1
                        If t = ")" Or t = "]" Then
                            If d2 = 0 And t = ")" Then Exit While
                            d2 = d2 - 1
                        End If
                        If t = "," And d2 = 0 Then
                            AddParamTok(midx, segStart, i - 1)
                            segStart = i + 1
                        End If
                        i = i + 1
                    Wend
                    If i > segStart Then AddParamTok(midx, segStart, i - 1)
                    i = i + 1
                End If
            End If

            '' returntype
            If i <= tokCount Then
                If LC(tokText(i)) = "as" Then
                    i = i + 1
                    segStart = i
                    While i <= tokCount
                        If tokKind(i) = TK_EOL Then Exit While
                        i = i + 1
                    Wend
                    members(midx).retType = JoinTok(segStart, i - 1)
                End If
            End If

            members(midx).isProto = isProto
            members(midx).sigTxt = MemberSig(midx)
            If k = "sub" Then members(midx).retType = ""
            If stmtDoc >= 0 Then ApplyDoc(stmtDoc, -1, midx)
            stmtDoc = -1
            If isProto = 0 Then curFunc = midx
            atStart = 0

        Case "const"
            i = i + 1
            If i <= tokCount Then
                If LC(tokText(i)) = "as" Then
                    i = i + 1
                    i = SkipQual(i)
                End If
            End If
            If i <= tokCount Then
                If tokKind(i) = TK_IDENT Then
                    nm = tokText(i)
                    pidx = curPart
                    If pidx < 0 Then
                        If modPart < 0 Then modPart = NewPart("module", PathBase(fpath), fpath, 1, ns)
                        pidx = modPart
                    End If
                    midx = NewMember("constant", nm, pidx, tokLine(i))
                    members(midx).isPrivate = isPriv
                    members(midx).sigTxt = nm
                    If stmtDoc >= 0 Then ApplyDoc(stmtDoc, -1, midx)
                    stmtDoc = -1
                End If
            End If
            isPriv = 0
            atStart = 0

        Case "dim", "common", "extern", "redim"
            i = i + 1
            While i <= tokCount
                k = LC(tokText(i))
                If k <> "shared" And k <> "preserve" And k <> "static" Then Exit While
                i = i + 1
            Wend
            '' Dim As Integer a, b   of   Dim a As Integer
            tp = ""
            If i <= tokCount Then
                If LC(tokText(i)) = "as" Then
                    i = i + 1
                    segStart = i
                    While i <= tokCount
                        If tokKind(i) = TK_EOL Then Exit While
                        If tokKind(i) = TK_IDENT And LC(tokText(i)) <> "ptr" And LC(tokText(i)) <> "const" Then
                            If i > segStart Then Exit While
                        End If
                        i = i + 1
                    Wend
                    tp = JoinTok(segStart, i - 1)
                End If
            End If
            pidx = curPart
            If pidx < 0 Then
                If modPart < 0 Then modPart = NewPart("module", PathBase(fpath), fpath, 1, ns)
                pidx = modPart
            End If
            If i <= tokCount Then
                If tokKind(i) = TK_IDENT Then
                    nm = tokText(i)
                    midx = NewMember("variable", nm, pidx, tokLine(i))
                    members(midx).isPrivate = isPriv
                    If Len(tp) = 0 Then
                        k2 = i
                        While k2 <= tokCount
                            If tokKind(k2) = TK_EOL Then Exit While
                            If LC(tokText(k2)) = "as" Then
                                tp = JoinTok(k2 + 1, k2 + 2)
                                Exit While
                            End If
                            k2 = k2 + 1
                        Wend
                    End If
                    members(midx).retType = tp
                    members(midx).sigTxt = nm
                    If Len(tp) > 0 Then members(midx).sigTxt = nm & " As " & tp
                    If stmtDoc >= 0 Then ApplyDoc(stmtDoc, -1, midx)
                    stmtDoc = -1
                End If
            End If
            isPriv = 0
            atStart = 0

        Case "#"
            i = i + 1
            If i > tokCount Then Exit While
            k = LC(tokText(i))
            If k = "include" Then
                i = i + 1
                If i <= tokCount Then
                    If LC(tokText(i)) = "once" Then i = i + 1
                End If
                If i <= tokCount Then
                    If tokKind(i) = TK_STR Then
                        nm = tokText(i)
                        If Len(nm) > 2 Then nm = Mid(nm, 2, Len(nm) - 2)
                        impCount = impCount + 1
                        ReDim Preserve impShort(1 To impCount)
                        ReDim Preserve impFull(1 To impCount)
                        impShort(impCount) = PathBase(nm)
                        impFull(impCount) = nm
                        AddInclude(fpath, nm)
                    End If
                End If
            ElseIf k = "define" Or k = "macro" Then
                i = i + 1
                If i <= tokCount Then
                    If tokKind(i) = TK_IDENT Then
                        nm = tokText(i)
                        pidx = curPart
                        If pidx < 0 Then
                            If modPart < 0 Then modPart = NewPart("module", PathBase(fpath), fpath, 1, ns)
                            pidx = modPart
                        End If
                        midx = NewMember("macro", nm, pidx, tokLine(i))
                        members(midx).sigTxt = nm
                        If i + 1 <= tokCount Then
                            If tokText(i + 1) = "(" Then
                                k2 = i + 1
                                d2 = 0
                                While k2 <= tokCount
                                    If tokText(k2) = "(" Then d2 = d2 + 1
                                    If tokText(k2) = ")" Then
                                        d2 = d2 - 1
                                        If d2 = 0 Then Exit While
                                    End If
                                    If tokKind(k2) = TK_EOL Then Exit While
                                    k2 = k2 + 1
                                Wend
                                members(midx).sigTxt = nm & JoinTok(i + 1, k2)
                            End If
                        End If
                        If stmtDoc >= 0 Then ApplyDoc(stmtDoc, -1, midx)
                        stmtDoc = -1
                    End If
                End If
            End If
            atStart = 0

        Case Else
            '' binnen een Type of Enum: veld of enumwaarde
            If curPart >= 1 And tokKind(i) = TK_IDENT Then
                If LC(parts(curPart).kind) = "enum" Then
                    midx = NewMember("enum", tokText(i), curPart, tokLine(i))
                    members(midx).sigTxt = tokText(i)
                    If stmtDoc >= 0 Then ApplyDoc(stmtDoc, -1, midx)
                    stmtDoc = -1
                    i = i + 1
                    While i <= tokCount
                        If tokKind(i) = TK_EOL Then Exit While
                        If tokText(i) = "," Then
                            i = i + 1
                            atStart = -1
                            Exit While
                        End If
                        i = i + 1
                    Wend
                    Continue While
                ElseIf LC(parts(curPart).kind) = "type" Or LC(parts(curPart).kind) = "union" Or LC(parts(curPart).kind) = "class" Then
                    '' veld:  naam As type   of   As type naam
                    nm = tokText(i)
                    midx = NewMember("variable", nm, curPart, tokLine(i))
                    k2 = i
                    tp = ""
                    While k2 <= tokCount
                        If tokKind(k2) = TK_EOL Then Exit While
                        If LC(tokText(k2)) = "as" Then
                            segStart = k2 + 1
                            While k2 <= tokCount
                                If tokKind(k2) = TK_EOL Then Exit While
                                k2 = k2 + 1
                            Wend
                            tp = JoinTok(segStart, k2 - 1)
                            Exit While
                        End If
                        k2 = k2 + 1
                    Wend
                    members(midx).retType = tp
                    members(midx).sigTxt = nm
                    If Len(tp) > 0 Then members(midx).sigTxt = nm & " As " & tp
                    If stmtDoc >= 0 Then ApplyDoc(stmtDoc, -1, midx)
                    stmtDoc = -1
                End If
            End If
            i = i + 1
            atStart = 0
        End Select
    Wend
End Sub

Function MemberSig(ByVal midx As Integer) As String
    Dim As String s, pt
    Dim As Integer k, pf, pc
    s = members(midx).mname & "("
    pf = members(midx).paramFirst
    pc = members(midx).paramCnt
    For k = pf To pf + pc - 1
        If k < 1 Or k > paramCount Then Continue For
        If k > pf Then s = s & ", "
        pt = paramList(k).pname
        If Len(paramList(k).ptype) > 0 Then pt = pt & " " & paramList(k).ptype
        If Len(paramList(k).pmode) > 0 Then pt = pt & " " & paramList(k).pmode
        s = s & pt
    Next k
    s = s & ")"
    If Len(members(midx).retType) > 0 Then s = s & " returns(" & members(midx).retType & ")"
    Return s
End Function
