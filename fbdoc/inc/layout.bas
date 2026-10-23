'' =====================================================================
''  fbdoc - Layout van de aanroepgraaf (SVG)
''
''  Gelaagd van links naar rechts: de laag van een knoop is de lengte van
''  het langste pad ernaartoe (afgekapt op 24 om cycli op te vangen).
''  Binnen een laag worden knopen eerst op part+naam gesorteerd en daarna
''  met twee barycenter-passes verschoven, wat het aantal kruisende
''  lijnen flink terugbrengt zonder een volledige Sugiyama-implementatie.
'' =====================================================================

Function NodeLabelW(ByVal midx As Integer) As Integer
    Dim As Integer w
    w = Len(members(midx).mname) * 7 + 20
    If w < 74 Then w = 74
    If w > 260 Then w = 260
    Return w
End Function

Sub BuildGraph()
    Dim As Integer i, e, k, l, n, iter, changed, pass, a, b, cnt
    Dim As Integer inGraph(), lst(), lstN, tmpI
    Dim As Double bc(), tmpD
    Dim As String ka, kb
    Dim As Integer layW(), layX(), rowH, nh, gapX, marg, sumPos, nPos

    gCount = 0
    gLayerMax = 0
    If memberCount < 1 Then Exit Sub

    ReDim inGraph(1 To memberCount)
    ReDim gIndex(1 To memberCount)
    For i = 1 To memberCount
        inGraph(i) = 0
        gIndex(i) = 0
    Next i

    '' knopen: functies die aan minstens een zichtbare, opgeloste kant meedoen
    For e = 1 To edgeCount
        If edges(e).toM < 1 Then Continue For
        i = edges(e).fromM
        k = edges(e).toM
        If GraphVisible(i) = 0 Then Continue For
        If GraphVisible(k) = 0 Then Continue For
        inGraph(i) = -1
        inGraph(k) = -1
    Next e

    n = 0
    For i = 1 To memberCount
        If inGraph(i) Then n = n + 1
    Next i
    If n = 0 Then Exit Sub

    ReDim gNode(1 To n)
    ReDim gLayer(1 To n)
    ReDim gPos(1 To n)
    ReDim gX(1 To n)
    ReDim gY(1 To n)
    ReDim gW(1 To n)
    ReDim bc(1 To n)
    ReDim lst(1 To n)

    For i = 1 To memberCount
        If inGraph(i) Then
            gCount = gCount + 1
            gNode(gCount) = i
            gIndex(i) = gCount
            gLayer(gCount) = 0
        End If
    Next i

    '' laagtoekenning: langste pad, afgekapt
    For iter = 1 To 64
        changed = 0
        For e = 1 To edgeCount
            If edges(e).toM < 1 Then Continue For
            a = gIndex(edges(e).fromM)
            b = gIndex(edges(e).toM)
            If a < 1 Or b < 1 Then Continue For
            If a = b Then Continue For
            If gLayer(b) <= gLayer(a) Then
                If gLayer(a) + 1 <= 24 Then
                    gLayer(b) = gLayer(a) + 1
                    changed = -1
                End If
            End If
        Next e
        If changed = 0 Then Exit For
    Next iter

    gLayerMax = 0
    For i = 1 To gCount
        If gLayer(i) > gLayerMax Then gLayerMax = gLayer(i)
    Next i

    '' beginordening binnen elke laag: op part en dan naam
    For l = 0 To gLayerMax
        lstN = 0
        For i = 1 To gCount
            If gLayer(i) = l Then
                lstN = lstN + 1
                lst(lstN) = i
            End If
        Next i
        '' insertion sort op sorteersleutel
        For a = 2 To lstN
            tmpI = lst(a)
            ka = Str(members(gNode(tmpI)).ownerPart + 1000) & LC(members(gNode(tmpI)).mname)
            b = a - 1
            While b >= 1
                kb = Str(members(gNode(lst(b))).ownerPart + 1000) & LC(members(gNode(lst(b))).mname)
                If kb > ka Then
                    lst(b + 1) = lst(b)
                    b = b - 1
                Else
                    Exit While
                End If
            Wend
            lst(b + 1) = tmpI
        Next a
        For a = 1 To lstN
            gPos(lst(a)) = a - 1
        Next a
    Next l

    '' barycenter-passes: heen op voorgangers, terug op opvolgers
    For pass = 1 To 2
        For l = 0 To gLayerMax
            lstN = 0
            For i = 1 To gCount
                If gLayer(i) = l Then
                    lstN = lstN + 1
                    lst(lstN) = i
                End If
            Next i

            For a = 1 To lstN
                sumPos = 0
                nPos = 0
                For e = 1 To edgeCount
                    If edges(e).toM < 1 Then Continue For
                    b = gIndex(edges(e).fromM)
                    k = gIndex(edges(e).toM)
                    If b < 1 Or k < 1 Then Continue For
                    If pass = 1 Then
                        If k = lst(a) And b <> k Then
                            sumPos = sumPos + gPos(b)
                            nPos = nPos + 1
                        End If
                    Else
                        If b = lst(a) And b <> k Then
                            sumPos = sumPos + gPos(k)
                            nPos = nPos + 1
                        End If
                    End If
                Next e
                If nPos > 0 Then
                    bc(lst(a)) = sumPos / nPos
                Else
                    bc(lst(a)) = gPos(lst(a))
                End If
            Next a

            For a = 2 To lstN
                tmpI = lst(a)
                tmpD = bc(tmpI)
                b = a - 1
                While b >= 1
                    If bc(lst(b)) > tmpD Then
                        lst(b + 1) = lst(b)
                        b = b - 1
                    Else
                        Exit While
                    End If
                Wend
                lst(b + 1) = tmpI
            Next a
            For a = 1 To lstN
                gPos(lst(a)) = a - 1
            Next a
        Next l
    Next pass

    '' coordinaten
    rowH = 34
    nh = 24
    gapX = 62
    marg = 14

    ReDim layW(0 To gLayerMax + 1)
    ReDim layX(0 To gLayerMax + 1)
    For l = 0 To gLayerMax
        layW(l) = 0
    Next l
    For i = 1 To gCount
        gW(i) = NodeLabelW(gNode(i))
        If gW(i) > layW(gLayer(i)) Then layW(gLayer(i)) = gW(i)
    Next i
    layX(0) = marg
    For l = 1 To gLayerMax
        layX(l) = layX(l - 1) + layW(l - 1) + gapX
    Next l
    For i = 1 To gCount
        gX(i) = layX(gLayer(i))
        gY(i) = marg + gPos(i) * rowH
    Next i
End Sub

Sub EmitGraphSvg()
    Dim As Integer i, e, a, b, totW, totH, nh, x1, y1, x2, y2, dx, isBack, p
    Dim As String q, s, nm

    q = Chr(34)
    nh = 24

    If gCount < 1 Then
        Emit "<p class=" & q & "loc" & q & ">Geen aanroeprelaties herkend, dus geen diagram.</p>"
        Exit Sub
    End If
    If gCount > 1200 Then
        Emit "<p class=" & q & "loc" & q & ">Diagram overgeslagen: " & Str(gCount) & " knopen is ook met zoomen niet meer te volgen. Gebruik -f dot voor een Graphviz-versie of scan een kleiner deel.</p>"
        Exit Sub
    End If

    totW = 0
    totH = 0
    For i = 1 To gCount
        If gX(i) + gW(i) > totW Then totW = gX(i) + gW(i)
        If gY(i) + nh > totH Then totH = gY(i) + nh
    Next i
    totW = totW + 70
    totH = totH + 40

    Emit "<div class=" & q & "graphwrap" & q & ">"
    Emit "<div class=" & q & "zoomctl" & q & ">"
    Emit "<button type=" & q & "button" & q & " id=" & q & "zin" & q & " title=" & q & "Inzoomen" & q & ">+</button>"
    Emit "<button type=" & q & "button" & q & " id=" & q & "zout" & q & " title=" & q & "Uitzoomen" & q & ">&minus;</button>"
    Emit "<button type=" & q & "button" & q & " id=" & q & "zfit" & q & " title=" & q & "Alles passend maken" & q & ">&#9635;</button>"
    Emit "</div>"
    Emit "<svg id=" & q & "cg" & q & " viewBox=" & q & "0 0 " & Str(totW) & " " & Str(totH) & q & _
         " preserveAspectRatio=" & q & "xMidYMid meet" & q & " xmlns=" & q & "http://www.w3.org/2000/svg" & q & ">"
    Emit "<defs>"
    Emit "<marker id=" & q & "ah" & q & " markerWidth=" & q & "9" & q & " markerHeight=" & q & "7" & q & _
         " refX=" & q & "8" & q & " refY=" & q & "3.5" & q & " orient=" & q & "auto" & q & ">"
    Emit "<path d=" & q & "M0,0 L8,3.5 L0,7 z" & q & " class=" & q & "ahf" & q & "/></marker>"
    Emit "<marker id=" & q & "ahb" & q & " markerWidth=" & q & "9" & q & " markerHeight=" & q & "7" & q & _
         " refX=" & q & "8" & q & " refY=" & q & "3.5" & q & " orient=" & q & "auto" & q & ">"
    Emit "<path d=" & q & "M0,0 L8,3.5 L0,7 z" & q & " class=" & q & "ahbf" & q & "/></marker>"
    Emit "</defs>"
    Emit "<g id=" & q & "vp" & q & ">"

    '' eerst de kanten, zodat de knopen erbovenop komen
    For e = 1 To edgeCount
        If edges(e).toM < 1 Then Continue For
        a = gIndex(edges(e).fromM)
        b = gIndex(edges(e).toM)
        If a < 1 Or b < 1 Then Continue For

        y1 = gY(a) + nh \ 2
        y2 = gY(b) + nh \ 2

        If a = b Then
            '' recursie: lusje aan de rechterkant
            x1 = gX(a) + gW(a)
            s = "M " & Str(x1) & " " & Str(y1 - 5) & " C " & Str(x1 + 42) & " " & Str(y1 - 26) & _
                ", " & Str(x1 + 42) & " " & Str(y1 + 26) & ", " & Str(x1) & " " & Str(y1 + 5)
            Emit "<path class=" & q & "e b" & q & " data-from=" & q & Str(a) & q & " data-to=" & q & Str(b) & q & _
                 " d=" & q & s & q & "><title>recursief</title></path>"
            Continue For
        End If

        If gLayer(b) > gLayer(a) Then
            x1 = gX(a) + gW(a)
            x2 = gX(b)
            dx = (x2 - x1) \ 2
            If dx < 26 Then dx = 26
            s = "M " & Str(x1) & " " & Str(y1) & " C " & Str(x1 + dx) & " " & Str(y1) & _
                ", " & Str(x2 - dx) & " " & Str(y2) & ", " & Str(x2) & " " & Str(y2)
            isBack = 0
        Else
            '' terugkoppeling (cyclus): rechterrand naar rechterrand
            x1 = gX(a) + gW(a)
            x2 = gX(b) + gW(b)
            s = "M " & Str(x1) & " " & Str(y1) & " C " & Str(x1 + 50) & " " & Str(y1 - 34) & _
                ", " & Str(x2 + 50) & " " & Str(y2 - 34) & ", " & Str(x2) & " " & Str(y2)
            isBack = 1
        End If

        nm = "e"
        If isBack = 1 Then nm = "e b"
        If edges(e).kindC > 0 Then nm = nm & " cb"
        s = "<path class=" & q & nm & q & " data-from=" & q & Str(a) & q & " data-to=" & q & Str(b) & q & _
            " d=" & q & s & q & "><title>" & HtmlEsc(members(gNode(a)).mname & " -> " & members(gNode(b)).mname)
        If edges(e).cnt > 1 Then s = s & " (" & Str(edges(e).cnt) & "x)"
        If isBack = 1 Then s = s & " [terugkoppeling]"
        If edges(e).kindC > 0 Then s = s & " [" & EdgeKindLabel(edges(e).kindC) & "]"
        s = s & "</title></path>"
        Emit s
    Next e

    '' knopen
    For i = 1 To gCount
        p = members(gNode(i)).ownerPart
        nm = "n p" & Str(p)
        If CallerCount(gNode(i)) = 0 Then nm = nm & " rt"
        If members(gNode(i)).isPrivate Then nm = nm & " pv"

        If parts(p).isRef Then
            '' referentie: geen documentatiesectie, dus geen link
            Emit "<g class=" & q & "n rf" & q & " data-id=" & q & Str(i) & q & ">"
            Emit "<title>" & HtmlEsc(MemberFullName(gNode(i)) & "  (referentie: " & PathBase(parts(p).filePath) & ":" & Str(members(gNode(i)).lineNo) & ")") & "</title>"
            Emit "<rect x=" & q & Str(gX(i)) & q & " y=" & q & Str(gY(i)) & q & " width=" & q & Str(gW(i)) & q & _
                 " height=" & q & Str(nh) & q & " rx=" & q & "5" & q & "/>"
            Emit "<text x=" & q & Str(gX(i) + 9) & q & " y=" & q & Str(gY(i) + 16) & q & ">" & HtmlEsc(members(gNode(i)).mname) & "</text>"
            Emit "</g>"
        Else
            Emit "<a href=" & q & MemberHref(gNode(i)) & q & ">"
            Emit "<g class=" & q & nm & q & " data-id=" & q & Str(i) & q & ">"
            Emit "<title>" & HtmlEsc(MemberFullName(gNode(i)) & "  (" & PathBase(parts(p).filePath) & ":" & Str(members(gNode(i)).lineNo) & ")") & "</title>"
            Emit "<rect x=" & q & Str(gX(i)) & q & " y=" & q & Str(gY(i)) & q & " width=" & q & Str(gW(i)) & q & _
                 " height=" & q & Str(nh) & q & " rx=" & q & "5" & q & "/>"
            Emit "<text x=" & q & Str(gX(i) + 9) & q & " y=" & q & Str(gY(i) + 16) & q & ">" & HtmlEsc(members(gNode(i)).mname) & "</text>"
            Emit "</g></a>"
        End If
    Next i

    Emit "</g>"
    Emit "</svg>"
    Emit "</div>"
End Sub
