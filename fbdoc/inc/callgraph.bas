'' =====================================================================
''  fbdoc - Aanroepgraaf: aanroepen verzamelen, oplossen en tellen
'' =====================================================================

'' Herkent  naam(  en  a.b.naam(  en geeft de index van '(' terug (0 = geen).
Function CallTargetAt(ByVal i As Integer, ByRef nameOut As String) As Integer
    Dim As Integer j
    Dim As String nm
    If i > tokCount Then Return 0
    If tokKind(i) <> TK_IDENT Then Return 0
    nm = tokText(i)
    j = i + 1
    While j < tokCount
        If tokText(j) = "." And tokKind(j + 1) = TK_IDENT Then
            nm = nm & "." & tokText(j + 1)
            j = j + 2
        Else
            Exit While
        End If
    Wend
    If j > tokCount Then Return 0
    If tokText(j) <> "(" Then Return 0
    nameOut = nm
    Return j
End Function

'' Geeft a.b.c terug vanaf tokenpositie i.
Function QualNameStr(ByVal i As Integer) As String
    Dim As String nm
    If i > tokCount Then Return ""
    If tokKind(i) <> TK_IDENT Then Return ""
    nm = tokText(i)
    While i < tokCount
        If tokText(i + 1) = "." And i + 2 <= tokCount Then
            If tokKind(i + 2) = TK_IDENT Then
                nm = nm & "." & tokText(i + 2)
                i = i + 2
            Else
                Exit While
            End If
        Else
            Exit While
        End If
    Wend
    Return nm
End Function

Sub AddCall(ByVal fromM As Integer, ByRef nm As String, ByVal ln As Integer, ByVal kindC As Integer)
    Dim As Integer k, dotP
    Dim As String qual, fn, pkg

    If fromM < 1 Then Exit Sub

    '' qualifier en functienaam scheiden
    qual = ""
    fn = nm
    dotP = 0
    For k = Len(nm) To 1 Step -1
        If Mid(nm, k, 1) = "." Then
            dotP = k
            Exit For
        End If
    Next k
    If dotP > 0 Then
        qual = Left(nm, dotP - 1)
        fn = Mid(nm, dotP + 1)
    End If

    '' ingebouwde collectie- en stringmethodes zijn geen aanroep
    If Len(qual) > 0 Then
        If IsBuiltinMethod(LC(fn)) Then Exit Sub
    End If

    '' package opzoeken in de imports van dit bestand
    pkg = ""
    If Len(qual) > 0 Then
        For k = 1 To impCount
            If LC(impShort(k)) = LC(qual) Then
                pkg = impFull(k)
                Exit For
            End If
        Next k
    End If

    '' dubbele aanroepen samenvoegen (achterwaarts, edges staan gegroepeerd)
    For k = edgeCount To 1 Step -1
        If edges(k).fromM <> fromM Then Exit For
        If LC(edges(k).toNm) = LC(nm) And edges(k).kindC = kindC Then
            edges(k).cnt = edges(k).cnt + 1
            Exit Sub
        End If
    Next k

    If edgeCount + 1 > edgeCap Then
        If edgeCap = 0 Then edgeCap = 512 Else edgeCap = edgeCap * 2
        ReDim Preserve edges(1 To edgeCap)
    End If
    edgeCount = edgeCount + 1
    edges(edgeCount).fromM  = fromM
    edges(edgeCount).toM    = -1
    edges(edgeCount).toNm   = nm
    edges(edgeCount).toQual = qual
    edges(edgeCount).toPkg  = pkg
    edges(edgeCount).lineNo = ln
    edges(edgeCount).cnt    = 1
    edges(edgeCount).isExt  = 0
    edges(edgeCount).isAmbig = 0
    edges(edgeCount).kindC  = kindC
    edges(edgeCount).isSys  = 0
End Sub

Function FindPartByName(ByRef nm As String) As Integer
    Dim As Integer i
    For i = 1 To partCount
        If LC(parts(i).pname) = LC(nm) Then Return i
    Next i
    Return -1
End Function

Function FindFuncInPart(ByVal pidx As Integer, ByRef nm As String) As Integer
    Dim As Integer i
    If pidx < 1 Then Return -1
    For i = 1 To memberCount
        If members(i).ownerPart = pidx Then
            If members(i).kind = "function" Then
                If LC(members(i).mname) = LC(nm) Then Return i
            End If
        End If
    Next i
    Return -1
End Function

Sub ResolveCalls()
    Dim As Integer e, p, dotP, target, ownerP, i, hits
    Dim As String qual, fn

    For e = 1 To edgeCount
        qual = ""
        fn = edges(e).toNm
        dotP = 0
        For i = Len(fn) To 1 Step -1
            If Mid(fn, i, 1) = "." Then
                dotP = i
                Exit For
            End If
        Next i
        If dotP > 0 Then
            qual = Left(fn, dotP - 1)
            fn = Mid(fn, dotP + 1)
        End If

        ownerP = members(edges(e).fromM).ownerPart

        If Len(qual) > 0 Then
            If IsSysLibName(LC(qual)) Then
                edges(e).isExt = -1
                edges(e).isSys = -1
                edges(e).toM = -1
                Continue For
            End If
            p = FindPartByName(qual)
            target = FindFuncInPart(p, fn)
            If target > 0 Then
                edges(e).toM = target
            Else
                '' methode-aanroep op een variabele: zoek de methode in elk Type
                hits = 0
                For i = 1 To memberCount
                    If members(i).kind = "function" Then
                        If LC(members(i).mname) = LC(fn) Then
                            hits = hits + 1
                            target = i
                        End If
                    End If
                Next i
                If hits = 1 Then
                    edges(e).toM = target
                Else
                    edges(e).toM = -1
                    edges(e).isExt = -1
                    If p < 1 Then edges(e).isSys = -1
                    If hits > 1 Then edges(e).isAmbig = hits
                End If
            End If
        Else
            '' eerst in het eigen part zoeken
            target = FindFuncInPart(ownerP, fn)
            If target < 1 Then
                '' daarna in alle parts, maar alleen bij een eenduidige treffer
                hits = 0
                For i = 1 To memberCount
                    If members(i).kind = "function" Then
                        If LC(members(i).mname) = LC(fn) Then
                            hits = hits + 1
                            target = i
                        End If
                    End If
                Next i
                If hits = 0 Then
                    '' In FreeBASIC is een naam met haakjes vaak een array of
                    '' een lokale variabele. Wat nergens als procedure bekend
                    '' is, is dus geen aanroep en verdwijnt uit de graaf.
                    target = -1
                    edges(e).isExt = -1
                    edges(e).isSys = -1
                ElseIf hits > 1 Then
                    '' naam komt in meerdere parts voor: niet raden
                    target = -1
                    edges(e).isAmbig = hits
                End If
            End If
            edges(e).toM = target
        End If
    Next e
End Sub

'' Zoekt in een tokenbereik naar koppelingen als  onClick = doeIets  of
'' onConstructionFunction = start. Zulke functies worden nergens expliciet
'' aangeroepen maar zijn wel degelijk in gebruik; zonder deze scan komen ze
'' onterecht in het overzicht van mogelijk dode code terecht.
Sub ScanBindings(ByVal a As Integer, ByVal b As Integer, ByVal ownerPart As Integer, ByVal ownerFunc As Integer)
    Dim As Integer k
    Dim As String nm
    If a < 1 Then Exit Sub
    If b > tokCount Then b = tokCount
    For k = a To b - 1
        If tokText(k) <> "=" Then Continue For
        If k + 1 > tokCount Then Exit For
        If tokKind(k + 1) <> TK_IDENT Then Continue For
        If k + 2 <= tokCount Then
            If tokText(k + 2) = "(" Then Continue For
        End If
        nm = QualNameStr(k + 1)
        If Len(nm) = 0 Then Continue For
        If ownerFunc > 0 Then
            AddCall(ownerFunc, nm, tokLine(k + 1), 3)
        ElseIf ownerPart >= 1 Then
            bindN = bindN + 1
            ReDim Preserve bindNm(1 To bindN)
            ReDim Preserve bindPart(1 To bindN)
            bindNm(bindN) = nm
            bindPart(bindN) = ownerPart
        End If
    Next k
End Sub

Sub ResolveBindings()
    Dim As Integer i, t2
    For i = 1 To bindN
        t2 = FindFuncInPart(bindPart(i), bindNm(i))
        If t2 > 0 Then members(t2).isBound = -1
    Next i
End Sub

'' Waarom heeft deze functie geen aanroeper?
''   0 = wel aangeroepen
''   1 = mogelijk ongebruikt
''   2 = ingang van een service, dus van buiten aangeroepen
''   3 = gekoppeld via een property (event handler, onConstructionFunction)
Function DeadKind(ByVal midx As Integer) As Integer
    Dim As Integer p
    If midx < 1 Then Return 0
    If members(midx).kind <> "function" Then Return 0
    p = members(midx).ownerPart
    If p >= 1 Then
        If parts(p).isRef Then Return 0
    End If
    If CallerCount(midx) > 0 Then Return 0
    If members(midx).isBound Then Return 3
    If p >= 1 Then
        Select Case LC(parts(p).kind)
        Case "service", "interface", "externaltype", "program", "basicprogram", "textprogram"
            Return 2
        End Select
    End If
    If members(midx).isProto Then Return 2
    Return 1
End Function

'' Korte aanduiding van het soort relatie.
Function EdgeKindLabel(ByVal kindC As Integer) As String
    If kindC = 1 Then Return "callback"
    If kindC = 2 Then Return "onException"
    If kindC = 3 Then Return "binding"
    Return ""
End Function

Function CalleeCount(ByVal midx As Integer) As Integer
    Dim As Integer e, n
    n = 0
    For e = 1 To edgeCount
        If edges(e).fromM = midx Then
            If opt.inclExtern = 0 And edges(e).isSys Then Continue For
            n = n + 1
        End If
    Next e
    Return n
End Function

Function CallerCount(ByVal midx As Integer) As Integer
    Dim As Integer e, n
    n = 0
    For e = 1 To edgeCount
        If edges(e).toM = midx Then n = n + 1
    Next e
    Return n
End Function

Function MemberFullName(ByVal midx As Integer) As String
    Dim As Integer p
    If midx < 1 Then Return "?"
    p = members(midx).ownerPart
    If p >= 1 Then Return parts(p).pname & "." & members(midx).mname
    Return members(midx).mname
End Function

'' Verzamelt de niet-opgeloste aanroepen per qualifier: dat zijn precies de
'' bibliotheken uit andere projecten waarvan deze code afhankelijk is.
Sub CollectExterns()
    Dim As Integer e, k, found
    extN = 0
    For e = 1 To edgeCount
        If edges(e).isExt = 0 Then Continue For
        If edges(e).toM > 0 Then Continue For
        If Len(edges(e).toQual) = 0 Then Continue For
        If IsSysLibName(LC(edges(e).toQual)) Then Continue For

        found = 0
        For k = 1 To extN
            If LC(extQual(k)) = LC(edges(e).toQual) Then
                found = k
                Exit For
            End If
        Next k
        If found > 0 Then
            extCnt(found) = extCnt(found) + edges(e).cnt
            If InStr(extFn(found), "|" & edges(e).toNm & "|") = 0 Then
                extFn(found) = extFn(found) & edges(e).toNm & "|"
            End If
        Else
            extN = extN + 1
            ReDim Preserve extQual(1 To extN)
            ReDim Preserve extPkg(1 To extN)
            ReDim Preserve extCnt(1 To extN)
            ReDim Preserve extFn(1 To extN)
            extQual(extN) = edges(e).toQual
            extPkg(extN)  = edges(e).toPkg
            extCnt(extN)  = edges(e).cnt
            extFn(extN)   = "|" & edges(e).toNm & "|"
        End If
    Next e
End Sub

Sub CollectAmbig()
    Dim As Integer e, k, found
    ambN = 0
    For e = 1 To edgeCount
        If edges(e).isAmbig <= 0 Then Continue For
        found = 0
        For k = 1 To ambN
            If LC(ambNm(k)) = LC(edges(e).toNm) Then
                found = k
                Exit For
            End If
        Next k
        If found > 0 Then
            ambCnt(found) = ambCnt(found) + edges(e).cnt
        Else
            ambN = ambN + 1
            ReDim Preserve ambNm(1 To ambN)
            ReDim Preserve ambCnt(1 To ambN)
            ambNm(ambN) = edges(e).toNm
            ambCnt(ambN) = edges(e).cnt
        End If
    Next e
End Sub

'' Hoe ver staat een referentiefunctie van de gedocumenteerde code af?
''
'' --follow trekt hele projecten naar binnen. Voor de graaf wil je alleen
'' de grens zien: welke functies roept jouw code aan, en eventueel een
'' paar stappen daarachter. Alles wat verder weg ligt valt buiten beeld,
'' anders krijg je een diagram met tienduizenden knopen.
Sub ComputeRefDist()
    Dim As Integer i, e, iter, changed, a, b, p

    If memberCount < 1 Then Exit Sub
    ReDim memDist(1 To memberCount)
    For i = 1 To memberCount
        p = members(i).ownerPart
        If p >= 1 Then
            If parts(p).isRef Then memDist(i) = 9999 Else memDist(i) = 0
        Else
            memDist(i) = 0
        End If
    Next i

    For iter = 1 To 32
        changed = 0
        For e = 1 To edgeCount
            a = edges(e).fromM
            b = edges(e).toM
            If a < 1 Or b < 1 Then Continue For
            If memDist(a) + 1 < memDist(b) Then
                memDist(b) = memDist(a) + 1
                changed = -1
            End If
        Next e
        If changed = 0 Then Exit For
    Next iter
End Sub

'' Hoort deze functie in de graaf?
Function GraphVisible(ByVal midx As Integer) As Integer
    Dim As Integer p
    If midx < 1 Then Return 0
    If members(midx).kind <> "function" Then Return 0
    If members(midx).isPrivate And opt.inclPriv = 0 Then Return 0
    p = members(midx).ownerPart
    If p >= 1 Then
        If parts(p).isRef Then
            If memDist(midx) > opt.refDepth Then Return 0
        End If
    End If
    Return -1
End Function
