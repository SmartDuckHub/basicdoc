'' ============================================================
'' msxbasicdoc - grafische aanroepgraaf als inline SVG
''
'' Eigen gelaagde layout (geen Graphviz nodig):
''  1. terugwaartse aanroepen (recursie/cycli) opsporen via DFS
''  2. laag = langste pad vanaf het hoofdprogramma
''  3. volgorde binnen een laag via barycentrum-sweeps (minder kruisingen)
''  4. links-naar-rechts tekenen, klikbaar, met hover-markering
'' ============================================================

Const SV_W = 184        '' knoopbreedte
Const SV_H = 38         '' knoophoogte
Const SV_GX = 80        '' horizontale ruimte tussen lagen
Const SV_GY = 14        '' verticale ruimte tussen knopen
Const SV_PAD = 20

Dim Shared gSvLayer() As Integer
Dim Shared gSvPos() As Integer
Dim Shared gSvVis() As Integer
Dim Shared gSvBack() As UByte
Dim Shared gSvX() As Integer, gSvY() As Integer
Dim Shared gSvLayers As Integer

Sub SvDfs(ByVal e As Integer)
    Dim f As Integer
    gSvVis(e) = 1
    For f = 0 To gNEn - 1
        If gCall(CLng(e) * gNEn + f) <> 0 Then
            If gSvVis(f) = 1 Then
                gSvBack(CLng(e) * gNEn + f) = 1
            ElseIf gSvVis(f) = 0 Then
                SvDfs f
            End If
        End If
    Next
    gSvVis(e) = 2
End Sub

Function SvEdge(ByVal e As Integer, ByVal f As Integer) As Integer
    '' voorwaartse (niet-cyclische) aanroep?
    SvEdge = 0
    If gCall(CLng(e) * gNEn + f) <> 0 Then
        If gSvBack(CLng(e) * gNEn + f) = 0 Then SvEdge = 1
    End If
End Function

'' Sorteert de knopen van laag L op sleutel; schrijft rang naar gSvPos
Sub SvSortLayer(ByVal L As Integer, ByVal useSucc As Integer)
    Dim ids() As Integer, keys() As Double, n As Integer, e As Integer, f As Integer
    Dim i As Integer, j As Integer, sm As Double, cnt As Integer, ti As Integer, tk As Double
    ReDim ids(0 To gNEn), keys(0 To gNEn)
    n = 0
    For e = 0 To gNEn - 1
        If gSvLayer(e) = L Then
            sm = 0 : cnt = 0
            For f = 0 To gNEn - 1
                If useSucc Then
                    If SvEdge(e, f) And gSvLayer(f) > L Then
                        sm += gSvPos(f) : cnt += 1
                    End If
                Else
                    If SvEdge(f, e) And gSvLayer(f) < L Then
                        sm += gSvPos(f) : cnt += 1
                    End If
                End If
            Next
            ids(n) = e
            If cnt > 0 Then keys(n) = sm / cnt Else keys(n) = gSvPos(e)
            n += 1
        End If
    Next
    For i = 1 To n - 1
        ti = ids(i) : tk = keys(i) : j = i - 1
        Do While j >= 0
            If keys(j) <= tk Then Exit Do
            ids(j + 1) = ids(j) : keys(j + 1) = keys(j) : j -= 1
        Loop
        ids(j + 1) = ti : keys(j + 1) = tk
    Next
    For i = 0 To n - 1
        gSvPos(ids(i)) = i
    Next
End Sub

Sub LayoutGraph()
    Dim e As Integer, f As Integer, it As Integer, changed As Integer, L As Integer
    Dim cnt() As Integer, maxCnt As Integer, offY As Integer

    ReDim gSvLayer(0 To gNEn), gSvPos(0 To gNEn), gSvVis(0 To gNEn)
    ReDim gSvX(0 To gNEn), gSvY(0 To gNEn)
    ReDim gSvBack(0 To CLng(gNEn) * gNEn)

    SvDfs 0
    For e = 1 To gNEn - 1
        If gSvVis(e) = 0 Then SvDfs e
    Next

    '' langste pad
    For it = 0 To gNEn
        changed = 0
        For e = 0 To gNEn - 1
            For f = 0 To gNEn - 1
                If SvEdge(e, f) Then
                    If gSvLayer(f) < gSvLayer(e) + 1 Then
                        gSvLayer(f) = gSvLayer(e) + 1 : changed = 1
                    End If
                End If
            Next
        Next
        If changed = 0 Then Exit For
    Next

    gSvLayers = 0
    For e = 0 To gNEn - 1
        If gSvLayer(e) + 1 > gSvLayers Then gSvLayers = gSvLayer(e) + 1
    Next

    '' beginvolgorde: regelvolgorde binnen de laag
    ReDim cnt(0 To gSvLayers)
    For e = 0 To gNEn - 1
        gSvPos(e) = cnt(gSvLayer(e))
        cnt(gSvLayer(e)) += 1
    Next

    '' barycentrum-sweeps heen en terug
    For it = 1 To 4
        For L = 1 To gSvLayers - 1
            SvSortLayer L, 0
        Next
        For L = gSvLayers - 2 To 0 Step -1
            SvSortLayer L, 1
        Next
    Next

    maxCnt = 0
    For L = 0 To gSvLayers - 1
        If cnt(L) > maxCnt Then maxCnt = cnt(L)
    Next
    For e = 0 To gNEn - 1
        L = gSvLayer(e)
        offY = ((maxCnt - cnt(L)) * (SV_H + SV_GY)) \ 2
        gSvX(e) = SV_PAD + L * (SV_W + SV_GX)
        gSvY(e) = SV_PAD + offY + gSvPos(e) * (SV_H + SV_GY)
    Next
End Sub

Function SvShort(ByRef s As String, ByVal maxLen As Integer) As String
    If Len(s) <= maxLen Then
        SvShort = HtmlEsc(s)
    Else
        SvShort = HtmlEsc(RTrim(Left(s, maxLen - 1))) & "&#8230;"
    End If
End Function

Sub WriteSvgGraph()
    Dim e As Integer, f As Integer, w As Integer, h As Integer, c As Integer
    Dim x1 As Integer, y1 As Integer, x2 As Integer, y2 As Integer, dx As Integer
    Dim d As String, cl As String, maxY As Integer, nLines As Integer, x As Integer
    Dim tip As String, p As Integer, nm As String, q As String

    If gNEn = 0 Then Exit Sub
    q = Chr(34)
    LayoutGraph

    maxY = 0
    For e = 0 To gNEn - 1
        If gSvY(e) + SV_H > maxY Then maxY = gSvY(e) + SV_H
    Next
    w = SV_PAD * 2 + gSvLayers * SV_W + (gSvLayers - 1) * SV_GX + 40
    h = maxY + SV_PAD + 50

    '' container nooit hoger dan nodig, zodat kleine grafen niet worden opgeblazen
    Print #gOut, "<div class=graphwrap style=" & q & "height:min(78vh," & NStr(h + 10) & "px)" & q & ">"
    Print #gOut, "<div class=zoomctl><button id=zin title=Inzoomen>+</button><button id=zout title=Uitzoomen>&minus;</button>" & _
        "<button id=zfit title=" & q & "Alles tonen" & q & ">&#8634;</button></div>"
    Print #gOut, "<svg id=cg xmlns=" & q & "http://www.w3.org/2000/svg" & q & " viewBox=" & q & "0 0 " & NStr(w) & " " & NStr(h) & q & _
        " preserveAspectRatio=" & q & "xMidYMin meet" & q & " role=img aria-label=" & q & "Aanroepstructuur" & q & ">"
    Print #gOut, "<defs><marker id=ah viewBox=" & q & "0 0 10 10" & q & " refX=10 refY=5 markerWidth=7 markerHeight=7 orient=auto>" & _
        "<path class=ahf d=" & q & "M0,0 L10,5 L0,10 z" & q & "/></marker>" & _
        "<marker id=ahb viewBox=" & q & "0 0 10 10" & q & " refX=10 refY=5 markerWidth=7 markerHeight=7 orient=auto>" & _
        "<path class=ahbf d=" & q & "M0,0 L10,5 L0,10 z" & q & "/></marker></defs>"
    Print #gOut, "<g id=vp>"

    '' verbindingen
    For e = 0 To gNEn - 1
        For f = 0 To gNEn - 1
            c = gCall(CLng(e) * gNEn + f)
            If c <> 0 Then
                If e = f Then
                    x1 = gSvX(e) + SV_W : y1 = gSvY(e) + SV_H \ 2
                    d = "M" & NStr(x1) & "," & NStr(y1 - 8) & " C" & NStr(x1 + 34) & "," & NStr(y1 - 24) & " " & _
                        NStr(x1 + 34) & "," & NStr(y1 + 24) & " " & NStr(x1) & "," & NStr(y1 + 8)
                ElseIf gSvLayer(f) > gSvLayer(e) Then
                    x1 = gSvX(e) + SV_W : y1 = gSvY(e) + SV_H \ 2
                    x2 = gSvX(f) : y2 = gSvY(f) + SV_H \ 2
                    dx = (x2 - x1) \ 2
                    d = "M" & NStr(x1) & "," & NStr(y1) & " C" & NStr(x1 + dx) & "," & NStr(y1) & " " & _
                        NStr(x2 - dx) & "," & NStr(y2) & " " & NStr(x2) & "," & NStr(y2)
                Else
                    x1 = gSvX(e) + SV_W \ 2 : y1 = gSvY(e) + SV_H
                    x2 = gSvX(f) + SV_W \ 2 : y2 = gSvY(f) + SV_H
                    d = "M" & NStr(x1) & "," & NStr(y1) & " C" & NStr(x1) & "," & NStr(y1 + 50) & " " & _
                        NStr(x2) & "," & NStr(y2 + 50) & " " & NStr(x2) & "," & NStr(y2)
                End If
                cl = "e"
                If gSvBack(CLng(e) * gNEn + f) Or e = f Then
                    cl &= " b"
                ElseIf c = 2 Then
                    cl &= " cb"
                End If
                Print #gOut, "<path class=" & q & cl & q & " data-from=" & q & NStr(e) & q & " data-to=" & q & NStr(f) & q & " d=" & q & d & q & "/>"
            End If
        Next
    Next

    '' knopen
    For e = 0 To gNEn - 1
        nm = gEnName(e)
        If gEnKind(e) = EN_MAIN And Len(gProgTitle) > 0 Then nm = gProgTitle
        nLines = 0
        For x = 0 To gNL - 1
            If IsMember(e, x) Then nLines += 1
        Next
        tip = NStr(gLnNum(gEnLine(e))) & " " & gEnName(e) & " (" & KindLabel(e) & ", " & NStr(nLines) & " regels)"
        If Len(gEnDesc(e)) > 0 Then
            p = InStr(gEnDesc(e), Chr(10))
            If p > 0 Then tip &= Chr(10) & Left(gEnDesc(e), p - 1) Else tip &= Chr(10) & gEnDesc(e)
        End If
        cl = "n " & KindClass(e)
        If gEnHasCaller(e) = 0 Then cl &= " rt"
        If gEnReach(e) = 0 Then cl &= " dd"
        Print #gOut, "<a href=" & q & "#R" & NStr(gLnNum(gEnLine(e))) & q & "><g class=" & q & cl & q & " data-id=" & q & NStr(e) & q & ">" & _
            "<title>" & HtmlEsc(tip) & "</title>" & _
            "<rect x=" & q & NStr(gSvX(e)) & q & " y=" & q & NStr(gSvY(e)) & q & " width=" & q & NStr(SV_W) & q & " height=" & q & NStr(SV_H) & q & " rx=" & q & "5" & q & "/>" & _
            "<text x=" & q & NStr(gSvX(e) + 9) & q & " y=" & q & NStr(gSvY(e) + 15) & q & "><tspan class=nn>" & NStr(gLnNum(gEnLine(e))) & "</tspan>" & _
            "<tspan class=nk dx=" & q & "6" & q & ">" & SvShort(KindLabel(e), 20) & "</tspan></text>" & _
            "<text x=" & q & NStr(gSvX(e) + 9) & q & " y=" & q & NStr(gSvY(e) + 30) & q & ">" & SvShort(nm, 24) & "</text></g></a>"
    Next
    Print #gOut, "</g></svg></div>"
End Sub
