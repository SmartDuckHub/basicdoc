'' ============================================================
'' msxbasicdoc - HTML- en Graphviz-uitvoer
'' ============================================================

Declare Sub WriteSvgGraph()

Function KindLabel(ByVal e As Integer) As String
    Select Case gEnKind(e)
    Case EN_MAIN
        KindLabel = "hoofdprogramma"
    Case EN_EVENT
        KindLabel = "event: ON " & gEnInfo(e)
    Case EN_ERROR
        KindLabel = "ON ERROR"
    Case Else
        KindLabel = "subroutine"
    End Select
End Function

Function KindClass(ByVal e As Integer) As String
    Select Case gEnKind(e)
    Case EN_MAIN
        KindClass = "k-main"
    Case EN_EVENT
        KindClass = "k-event"
    Case EN_ERROR
        KindClass = "k-error"
    Case Else
        KindClass = "k-sub"
    End Select
End Function

Function EntryHref(ByVal e As Integer) As String
    EntryHref = "#R" & NStr(gLnNum(gEnLine(e)))
End Function

Function EntryLink(ByVal e As Integer) As String
    EntryLink = "<a href=""" & EntryHref(e) & """><code>" & NStr(gLnNum(gEnLine(e))) & "</code> " & HtmlEsc(gEnName(e)) & "</a>"
End Function

'' Bronregel opmaken: sleutelwoorden, strings, commentaar en klikbare sprongdoelen
Function RenderLine(ByVal li As Integer) As String
    Dim s As String, u As String, r As String, kw As String, num As String, tgt As String
    Dim n As Integer, i As Integer, j As Integer, c As Integer, k As Integer, isLink As Integer

    s = gLnText(li) : u = UCase(s) : n = Len(s)
    tgt = "|"
    For k = gLnEd1(li) To gLnEd1(li) + gLnEdN(li) - 1
        If gEdTo(k) >= 0 Then tgt &= NStr(gEdNum(k)) & "|"
    Next
    r = "" : i = 1
    Do While i <= n
        c = Asc(u, i)
        If c = 34 Then
            j = InStr(i + 1, s, Chr(34))
            If j = 0 Then j = n
            r &= "<span class=str>" & HtmlEsc(Mid(s, i, j - i + 1)) & "</span>"
            i = j + 1
        ElseIf c = 39 Then
            r &= "<span class=rem>" & HtmlEsc(Mid(s, i)) & "</span>"
            i = n + 1
        ElseIf c >= 65 And c <= 90 Then
            kw = MatchKw(u, i)
            If kw = "REM" Then
                r &= "<span class=rem>" & HtmlEsc(Mid(s, i)) & "</span>"
                i = n + 1
            ElseIf kw = "DATA" Then
                j = DataEnd(s, i + 4)
                r &= "<span class=kw>" & HtmlEsc(Mid(s, i, 4)) & "</span><span class=dat>" & HtmlEsc(Mid(s, i + 4, j - i - 4)) & "</span>"
                i = j
            ElseIf Len(kw) > 0 Then
                r &= "<span class=kw>" & HtmlEsc(Mid(s, i, Len(kw))) & "</span>"
                i += Len(kw)
            Else
                j = i + 1
                Do While j <= n
                    If IsDigitC(Asc(u, j)) Then j += 1 Else Exit Do
                Loop
                r &= HtmlEsc(Mid(s, i, j - i))
                i = j
            End If
        ElseIf IsDigitC(c) Then
            j = i
            Do While j <= n
                If IsDigitC(Asc(u, j)) Then j += 1 Else Exit Do
            Loop
            num = Mid(s, i, j - i)
            isLink = 0
            If Len(num) <= 5 Then
                If InStr(tgt, "|" & NStr(CLng(Val(num))) & "|") > 0 Then isLink = 1
            End If
            If j <= n Then
                If Asc(u, j) = 46 Then isLink = 0
            End If
            If isLink Then
                r &= "<a href=""#L" & NStr(CLng(Val(num))) & """>" & num & "</a>"
            Else
                r &= num
            End If
            i = j
        Else
            r &= HtmlEsc(Mid(s, i, 1))
            i += 1
        End If
    Loop
    RenderLine = r
End Function

'' ---------------------------------------------------------------------
''  Opbouw in dezelfde stijl en indeling als egldoc (OutHtml):
''  header, sticky navigatiekolom met filter, dekking, aanroepstructuur
''  met slepen/zoomen, mogelijk ongebruikte code, routines als secties.
'' ---------------------------------------------------------------------

Sub Emit(ByRef s As String)
    Print #gOut, s
End Sub

Sub EmitStyleBody()
    Emit ":root{--bg:#ffffff;--fg:#1b1f24;--mut:#5b6570;--line:#dfe3e8;--card:#f6f8fa;--acc:#0b5fa4;--link:#0b5fa4;--auto:#8a5a00;--autobg:#fff4d6;--dep:#a11;--kw:#7a2e8e;--str:#a1561b;--rem:#3c7a3c;--deadbg:#fbe9e9;--sharedbg:#fff4d6;--tgt:#d8e8fb}"
    Emit "@media (prefers-color-scheme:dark){:root{--bg:#12161a;--fg:#e6e9ec;--mut:#9aa4ae;--line:#2a3138;--card:#1a1f25;--acc:#5aa9f0;--link:#cdd6de;--auto:#e0b050;--autobg:#332a10;--dep:#f77;--kw:#d59be6;--str:#e2a36b;--rem:#86c286;--deadbg:#3a1f22;--sharedbg:#332a10;--tgt:#1d3550}}"
    Emit "*{box-sizing:border-box}"
    Emit "a,a:visited{color:var(--link);text-decoration:none}"
    Emit "a:hover{text-decoration:underline}"
    Emit "a:focus-visible{outline:2px solid var(--link);outline-offset:2px}"
    Emit "body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.55 -apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif}"
    Emit "code,pre,.sig,.mono{font-family:Consolas,'DejaVu Sans Mono',monospace}"
    Emit "header{padding:18px 24px;border-bottom:1px solid var(--line)}"
    Emit "header h1{margin:0;font-size:19px}"
    Emit "header .meta{color:var(--mut);font-size:13px;margin-top:4px}"
    Emit ".wrap{display:flex;align-items:flex-start}"
    Emit "nav{width:290px;flex:0 0 290px;border-right:1px solid var(--line);padding:14px;position:sticky;top:0;max-height:100vh;overflow:auto}"
    Emit "nav input{width:100%;padding:6px 8px;border:1px solid var(--line);border-radius:5px;background:var(--bg);color:var(--fg);margin-bottom:10px}"
    Emit "nav ul{list-style:none;margin:0;padding:0}"
    Emit "nav li{margin:2px 0;font-size:13px}"
    Emit "nav li.f{padding-left:14px;color:var(--mut)}"
    Emit "nav a,nav a:visited{color:var(--link)}"
    Emit "main{flex:1 1 auto;padding:18px 26px;min-width:0}"
    Emit "section.part{border-top:1px solid var(--line);padding-top:16px;margin-top:26px}"
    Emit "h2{font-size:20px;margin:0 0 4px}"
    Emit "h3{font-size:15px;margin:22px 0 6px}"
    Emit ".loc{color:var(--mut);font-size:12px}"
    Emit ".brief{margin:8px 0}"
    Emit ".detail{color:var(--fg);white-space:pre-wrap;margin:6px 0}"
    Emit "table{border-collapse:collapse;margin:8px 0;font-size:13px;width:100%}"
    Emit "th,td{border:1px solid var(--line);padding:4px 8px;text-align:left;vertical-align:top}"
    Emit "th{background:var(--card);font-weight:600}"
    Emit ".tag{display:inline-block;font-size:11px;padding:1px 6px;border-radius:9px;border:1px solid var(--line);color:var(--mut);margin-left:6px;font-weight:400}"
    Emit ".auto{background:var(--autobg);color:var(--auto);border-color:transparent}"
    Emit ".dep{color:var(--dep);border-color:var(--dep)}"
    Emit ".stat{background:var(--card);border:1px solid var(--line);border-radius:6px;padding:10px 14px;font-size:13px;display:inline-block;margin-right:8px}"
    Emit ".graphwrap{position:relative;overflow:hidden;border:1px solid var(--line);border-radius:6px;background:var(--card);height:78vh;min-height:220px;margin:10px 0}"
    Emit "svg#cg{width:100%;height:100%;display:block;cursor:grab;touch-action:none}"
    Emit "svg#cg.drag{cursor:grabbing}"
    Emit ".zoomctl{position:absolute;right:14px;bottom:14px;z-index:5;display:flex;flex-direction:column}"
    Emit ".zoomctl button{width:34px;height:34px;margin-top:5px;font:16px/1 -apple-system,Segoe UI,Roboto,sans-serif;border:1px solid var(--line);background:var(--bg);color:var(--fg);border-radius:7px;cursor:pointer;box-shadow:0 1px 4px rgba(0,0,0,.25)}"
    Emit ".zoomctl button:hover{background:var(--card)}"
    Emit ".zoomctl button:active{transform:translateY(1px)}"
    Emit "svg#cg text{font-family:Consolas,'DejaVu Sans Mono',monospace;font-size:11px;fill:var(--fg);pointer-events:none}"
    Emit "svg#cg tspan.nn{font-weight:700}svg#cg tspan.nk{fill:var(--mut);font-size:10px}"
    Emit "svg#cg g.n rect{stroke-width:1.2}"
    Emit "svg#cg g.rt rect{stroke-width:2.6}"
    Emit "svg#cg g.dd rect{stroke-dasharray:4 3}"
    Emit "svg#cg g.n{cursor:pointer}"
    Emit "svg#cg path.e{fill:none;stroke:#8a949e;stroke-width:1.3;marker-end:url(#ah)}"
    Emit "svg#cg path.e.b{stroke:#c0673a;stroke-dasharray:5 3;marker-end:url(#ahb)}"
    Emit "svg#cg path.e.cb{stroke:#3a7bbf;stroke-dasharray:2 3}"
    Emit "svg#cg .ahf{fill:#8a949e}"
    Emit "svg#cg .ahbf{fill:#c0673a}"
    Emit "svg#cg a{text-decoration:none}"
    Emit ".legend{font-size:12px;color:var(--mut);margin:6px 0 14px}"
    Emit ".legend span.sw{display:inline-block;width:11px;height:11px;border-radius:3px;border:1px solid var(--line);vertical-align:-1px;margin:0 4px 0 10px}"
    '' een tint per soort ingang, licht en donker (zelfde opbouw als de part-tinten in egldoc)
    Emit "svg#cg g.k-main rect{fill:hsl(210,62%,92%);stroke:hsl(210,45%,52%)}.sw-main{background:hsl(210,62%,92%)}"
    Emit "svg#cg g.k-sub rect{fill:hsl(140,62%,92%);stroke:hsl(140,45%,42%)}.sw-sub{background:hsl(140,62%,92%)}"
    Emit "svg#cg g.k-event rect{fill:hsl(42,62%,90%);stroke:hsl(42,55%,45%)}.sw-event{background:hsl(42,62%,90%)}"
    Emit "svg#cg g.k-error rect{fill:hsl(6,62%,92%);stroke:hsl(6,50%,52%)}.sw-error{background:hsl(6,62%,92%)}"
    Emit "@media (prefers-color-scheme:dark){"
    Emit "svg#cg g.k-main rect{fill:hsl(210,30%,24%);stroke:hsl(210,40%,58%)}.sw-main{background:hsl(210,30%,24%)}"
    Emit "svg#cg g.k-sub rect{fill:hsl(140,30%,22%);stroke:hsl(140,40%,55%)}.sw-sub{background:hsl(140,30%,22%)}"
    Emit "svg#cg g.k-event rect{fill:hsl(42,30%,22%);stroke:hsl(42,45%,55%)}.sw-event{background:hsl(42,30%,22%)}"
    Emit "svg#cg g.k-error rect{fill:hsl(6,30%,24%);stroke:hsl(6,45%,60%)}.sw-error{background:hsl(6,30%,24%)}"
    Emit "}"
    '' bronlisting
    Emit "table.src{font-size:13px;border:1px solid var(--line)}table.src td{border:0;padding:1px 8px;white-space:pre-wrap}"
    Emit "table.src td.own{white-space:nowrap;width:1%;font-size:11px;color:var(--mut)}"
    Emit "table.src td.ln{text-align:right;color:var(--mut);width:1%;user-select:none}"
    Emit "table.src tr.dead{background:var(--deadbg)}table.src tr.shared{background:var(--sharedbg)}table.src tr.entry td{border-top:1px solid var(--line)}"
    Emit "table.src tr:target{background:var(--tgt)}"
    Emit ".kw{color:var(--kw);font-weight:600}.str{color:var(--str)}.rem{color:var(--rem);font-style:italic}.dat{color:var(--str)}"
    Emit "ul.warn{padding-left:20px}ul.warn li{margin:3px 0}"
    Emit "ul.tree,ul.tree ul{list-style:none;padding-left:18px;margin:2px 0;font-size:13px}ul.tree{padding-left:0}"
    Emit "summary{cursor:pointer;margin:4px 0}"
    Emit ".legend span.bg{display:inline-block;padding:0 8px;margin-right:8px;border-radius:4px}"
End Sub

Sub EmitDocHead(ByRef titleTxt As String)
    Dim q As String
    q = Chr(34)
    Emit "<!DOCTYPE html>"
    Emit "<html lang=" & q & "nl" & q & ">"
    Emit "<head>"
    Emit "<meta charset=" & q & "utf-8" & q & ">"
    Emit "<meta name=" & q & "viewport" & q & " content=" & q & "width=device-width,initial-scale=1" & q & ">"
    Emit "<title>" & HtmlEsc(titleTxt) & "</title>"
    Emit "<style>"
    EmitStyleBody
    Emit "</style>"
    Emit "</head><body>"
End Sub

Sub EmitHeaderBar(ByRef title As String)
    Dim q As String
    q = Chr(34)
    Emit "<header><h1>MSX-BASIC documentatie &mdash; " & HtmlEsc(title) & "</h1><div class=" & q & "meta" & q & ">msxbasicdoc " & MBD_VERSION & _
        " &middot; " & TodayNL() & " " & Time & " &middot; " & HtmlEsc(gFile) & " &middot; " & NStr(gNL) & " regels &middot; " & _
        NStr(IIf(gNEn > 0, gNEn - 1, 0)) & " routines</div></header>"
End Sub

Sub EmitNavList()
    Dim e As Integer
    Dim q As String
    q = Chr(34)
    Emit "<input id=" & q & "q" & q & " placeholder=" & q & "Filter op naam of regel..." & q & ">"
    Emit "<ul>"
    Emit "<li><a href=" & q & "#graph" & q & "><b>Aanroepstructuur</b></a></li>"
    Emit "<li><a href=" & q & "#dead" & q & "><b>Mogelijk ongebruikt</b></a></li>"
    Emit "<li><a href=" & q & "#warn" & q & "><b>Waarschuwingen</b></a> (" & NStr(gNW) & ")</li>"
    Emit "<li><a href=" & q & "#vars" & q & "><b>Variabelen</b></a></li>"
    Emit "<li><a href=" & q & "#misc" & q & "><b>Functies, DATA en extern</b></a></li>"
    Emit "<li><a href=" & q & "#src" & q & "><b>Broncode</b></a></li>"
    Emit "<li><a href=" & q & "#overview" & q & ">Programma " & HtmlEsc(gFile) & "</a></li>"
    For e = 0 To gNEn - 1
        Emit "<li class=" & q & "f" & q & "><a href=" & q & EntryHref(e) & q & "><code>" & NStr(gLnNum(gEnLine(e))) & "</code> " & HtmlEsc(gEnName(e)) & "</a></li>"
    Next
    Emit "</ul>"
End Sub

Sub EmitCoverageBlock()
    Dim e As Integer, docd As Integer, nRem As Integer, x As Integer
    Dim q As String
    q = Chr(34)
    docd = 0
    For e = 0 To gNEn - 1
        If gEnDocd(e) Then docd += 1
    Next
    nRem = 0
    For x = 0 To gNL - 1
        If gLnRem(x) Then nRem += 1
    Next
    Emit "<div class=" & q & "stat" & q & ">Documentatiedekking: <b>" & NStr(docd) & "</b> van <b>" & NStr(gNEn) & _
        "</b> ingangen heeft echt broncommentaar (" & Pct1(docd, gNEn) & "%)</div>"
    Emit "<div class=" & q & "stat" & q & ">Commentaarregels: <b>" & NStr(nRem) & "</b> van <b>" & NStr(gNL) & "</b> (" & Pct1(nRem, gNL) & "%)</div>"
End Sub

Sub EmitTagsTable(ByRef tags As String)
    Dim p As Integer, r As Integer, ln As String, t As Integer
    If Len(tags) = 0 Then Exit Sub
    Emit "<table><tr><th>Tag</th><th>Waarde</th></tr>"
    p = 1
    Do While p <= Len(tags)
        r = InStr(p, tags, Chr(10))
        If r = 0 Then r = Len(tags) + 1
        ln = Mid(tags, p, r - p)
        t = InStr(ln, Chr(9))
        If t > 0 Then Emit "<tr><td><code>@" & HtmlEsc(Left(ln, t - 1)) & "</code></td><td>" & HtmlEsc(Mid(ln, t + 1)) & "</td></tr>"
        p = r + 1
    Loop
    Emit "</table>"
End Sub

'' Eerste regel als brief, de rest als detail (zoals egldoc)
Sub EmitBriefDetail(ByRef d As String, ByVal isAuto As Integer)
    Dim p As Integer, br As String, dt As String, q As String
    q = Chr(34)
    p = InStr(d, Chr(10))
    If p > 0 Then
        br = Left(d, p - 1) : dt = Mid(d, p + 1)
    Else
        br = d : dt = ""
    End If
    Do While Right(dt, 1) = Chr(10)
        dt = Left(dt, Len(dt) - 1)
    Loop
    If isAuto Then
        Emit "<div class=" & q & "brief" & q & ">" & HtmlEsc(br) & "<span class=" & q & "tag auto" & q & ">auto</span></div>"
    ElseIf Len(br) > 0 Then
        Emit "<div class=" & q & "brief" & q & ">" & HtmlEsc(br) & "</div>"
    End If
    If Len(dt) > 0 Then Emit "<div class=" & q & "detail" & q & ">" & HtmlEsc(dt) & "</div>"
End Sub

Sub EmitOverview(ByRef title As String)
    Dim q As String
    q = Chr(34)
    Emit "<section class=" & q & "part" & q & " id=" & q & "overview" & q & ">"
    Emit "<h2>Programma " & HtmlEsc(title) & "</h2>"
    Emit "<div class=" & q & "loc" & q & ">" & HtmlEsc(gFile) & "</div>"
    EmitBriefDetail gProgDesc, 0
    EmitTagsTable gProgTags
    Emit "</section>"
End Sub


Function HasKids(ByVal e As Integer) As Integer
    Dim f As Integer
    HasKids = 0
    For f = 0 To gNEn - 1
        If gCall(CLng(e) * gNEn + f) <> 0 Then
            HasKids = 1 : Exit Function
        End If
    Next
End Function

Sub TreeNode(ByVal e As Integer, ByVal how As Integer)
    Dim f As Integer, open_ As Integer
    Print #gOut, "<li>";
    If how = 2 Then Print #gOut, "<span class=tag>registreert</span> ";
    Print #gOut, EntryLink(e);
    If gTreeOnPath(e) Then
        Print #gOut, " <span class=loc>(recursief)</span></li>"
        Exit Sub
    End If
    If gTreeShown(e) <> 0 And HasKids(e) <> 0 Then
        Print #gOut, " <span class=loc>(zie hierboven)</span></li>"
        Exit Sub
    End If
    gTreeShown(e) = 1 : gTreeOnPath(e) = 1
    open_ = 0
    For f = 0 To gNEn - 1
        If gCall(CLng(e) * gNEn + f) <> 0 Then
            If open_ = 0 Then
                Print #gOut, "<ul>" : open_ = 1
            End If
            TreeNode f, gCall(CLng(e) * gNEn + f)
        End If
    Next
    If open_ Then Print #gOut, "</ul>"
    gTreeOnPath(e) = 0
    Print #gOut, "</li>"
End Sub

Sub EmitGraphSection()
    Dim q As String, nEdges As Integer, i As Integer
    q = Chr(34)
    nEdges = 0
    For i = 0 To CLng(gNEn) * gNEn - 1
        If gCall(i) <> 0 Then nEdges += 1
    Next
    Emit "<h2 id=" & q & "graph" & q & " style=" & q & "margin-top:26px" & q & ">Aanroepstructuur</h2>"
    Emit "<div class=" & q & "legend" & q & ">"
    Emit NStr(gNEn) & " ingangen, " & NStr(nEdges) & " relaties. Van links naar rechts: aanroeper voor aangeroepene. Klik een blok om naar de documentatie te springen; beweeg erover om alleen de eigen relaties te zien. Sleep om te verschuiven, scrollwiel of de knoppen rechtsonder om te zoomen."
    Emit "<br>Dikke rand = geen aanroeper binnen bereikbare code (hoofdprogramma, of alleen aangeroepen vanuit dode code). Gestippelde rand = niet bereikbaar vanuit het hoofdprogramma. Oranje gestippelde pijl = terugkoppeling of recursie. Blauwe fijngestippelde pijl = registreert handler (ON INTERVAL/KEY/SPRITE/STRIG/STOP GOSUB, ON ERROR GOTO)."
    Emit "<br>Soorten:<span class=" & q & "sw sw-main" & q & "></span>hoofdprogramma<span class=" & q & "sw sw-sub" & q & "></span>subroutine" & _
        "<span class=" & q & "sw sw-event" & q & "></span>event-handler<span class=" & q & "sw sw-error" & q & "></span>foutafhandeling"
    Emit "</div>"
    WriteSvgGraph
    If gNEn > 0 Then
        Emit "<details><summary class=" & q & "loc" & q & ">Als boomstructuur</summary>"
        ReDim gTreeShown(0 To gNEn), gTreeOnPath(0 To gNEn)
        Emit "<ul class=" & q & "tree" & q & ">"
        TreeNode 0, 0
        For i = 1 To gNEn - 1
            If gTreeShown(i) = 0 Then TreeNode i, 0
        Next
        Emit "</ul></details>"
    End If
End Sub

'' Reeksen onbereikbare regels; schrijft tabelrijen, geeft aantal reeksen
Function EmitDeadRanges() As Integer
    Dim x As Integer, s As Integer, n As Integer, cnt As Integer, q As String, y As Integer
    q = Chr(34)
    n = 0 : x = 0
    Do While x < gNL
        If gLnOwners(x) = 0 And gLnRem(x) = 0 And gLnData(x) = 0 Then
            s = x
            Do While x + 1 < gNL
                If gLnOwners(x + 1) <> 0 Then Exit Do
                x += 1
            Loop
            '' commentaar/DATA aan het eind van de reeks niet meetellen
            Do While x > s
                If gLnRem(x) = 0 And gLnData(x) = 0 Then Exit Do
                x -= 1
            Loop
            cnt = 0
            For y = s To x
                If gLnRem(y) = 0 And gLnData(y) = 0 Then cnt += 1
            Next
            If n = 0 Then Emit "<table><tr><th>Regels</th><th>Code-regels</th><th>Begint met</th></tr>"
            Emit "<tr><td>" & LineLink(s) & IIf(s <> x, "&ndash;" & LineLink(x), "") & "</td><td>" & NStr(cnt) & "</td><td><code>" & _
                HtmlEsc(Left(gLnText(s), 60)) & "</code></td></tr>"
            n += 1
        End If
        x += 1
    Loop
    If n > 0 Then Emit "</table>"
    EmitDeadRanges = n
End Function

Sub EmitDeadSection()
    Dim e As Integer, n As Integer, k As Integer, s As String, q As String
    q = Chr(34)
    Emit "<h2 id=" & q & "dead" & q & " style=" & q & "margin-top:26px" & q & ">Mogelijk ongebruikte code</h2>"
    Emit "<div class=" & q & "legend" & q & ">In MSX-BASIC zijn sprongdoelen altijd vaste regelnummers, dus de analyse is binnen het programma volledig."
    Emit "<br>Niet gezien worden: binnenkomst via <code>RUN regel</code> of <code>GOTO</code> in direct mode, via een ander programma (<code>RUN ""X"",R</code>, <code>MERGE</code>) of via machinetaal. Controleer dat voordat je iets weggooit.</div>"

    Emit "<h3>Onbereikbare regels</h3>"
    If EmitDeadRanges() = 0 Then Emit "<p>Geen onbereikbare code gevonden.</p>"

    n = 0
    For e = 1 To gNEn - 1
        If gEnReach(e) = 0 Then
            If n = 0 Then
                Emit "<h3>Routines die niet vanuit het hoofdprogramma bereikt worden</h3>"
                Emit "<table><tr><th>Routine</th><th>Soort</th><th>Aangeroepen vanaf</th></tr>"
            End If
            s = ""
            For k = 0 To gNE - 1
                If gEdTo(k) = gEnLine(e) Then
                    Select Case gEdKind(k)
                    Case ED_GOSUB, ED_ONGOSUB, ED_ONEVENT, ED_ONERROR
                        If Len(s) > 0 Then s &= ", "
                        s &= LineLink(gEdFrom(k))
                        If gLnOwners(gEdFrom(k)) = 0 Then s &= " <span class=" & q & "tag dep" & q & ">dood</span>"
                    End Select
                End If
            Next
            Emit "<tr><td>" & EntryLink(e) & "</td><td>" & HtmlEsc(KindLabel(e)) & "</td><td>" & s & "</td></tr>"
            n += 1
        End If
    Next
    If n > 0 Then Emit "</table>"
End Sub

Sub EmitWarnSection()
    Dim k As Integer, q As String
    q = Chr(34)
    Emit "<h2 id=" & q & "warn" & q & " style=" & q & "margin-top:26px" & q & ">Waarschuwingen</h2>"
    If gNW = 0 Then
        Emit "<p>Geen waarschuwingen.</p>"
        Exit Sub
    End If
    Emit "<ul class=" & q & "warn" & q & ">"
    For k = 0 To gNW - 1
        If gWLine(k) >= 0 Then
            Emit "<li>" & HtmlEsc(gWText(k)) & " <a href=" & q & "#L" & NStr(gLnNum(gWLine(k))) & q & ">&rarr;</a></li>"
        Else
            Emit "<li>" & HtmlEsc(gWText(k)) & "</li>"
        End If
    Next
    Emit "</ul>"
End Sub

Sub EmitRoutineSection(ByVal e As Integer)
    Dim x As Integer, k As Integer, f As Integer, v As Integer, u As Integer, n As Integer
    Dim s As String, s2 As String, q As String, seen As String
    Dim rd() As Integer, wr() As Integer, dm() As Integer
    q = Chr(34)

    Emit "<section class=" & q & "part" & q & " id=" & q & "R" & NStr(gLnNum(gEnLine(e))) & q & ">"
    s = "<h2>" & NStr(gLnNum(gEnLine(e))) & " &middot; " & HtmlEsc(gEnName(e)) & "<span class=" & q & "tag" & q & ">" & HtmlEsc(KindLabel(e)) & "</span>"
    If gEnReach(e) = 0 Then s &= "<span class=" & q & "tag dep" & q & ">onbereikbaar</span>"
    Emit s & "</h2>"
    n = 0
    For x = 0 To gNL - 1
        If IsMember(e, x) Then n += 1
    Next
    Emit "<div class=" & q & "loc" & q & ">" & HtmlEsc(gFile) & ":" & NStr(gLnNum(gEnLine(e))) & " &middot; " & NStr(n) & " regels: " & RangesHtml(e) & "</div>"

    If gEnKind(e) = EN_MAIN Then
        EmitBriefDetail "Begin van het programma en alles wat daar zonder GOSUB uit volgt.", 0
    ElseIf gEnDocd(e) = 0 Then
        EmitBriefDetail "Geen broncommentaar; naam afgeleid.", 1
    Else
        EmitBriefDetail gEnDesc(e), 0
    End If
    EmitTagsTable gEnTags(e)

    '' roept aan / registreert
    s = "" : s2 = ""
    For f = 0 To gNEn - 1
        If gCall(CLng(e) * gNEn + f) = 1 Then
            If Len(s) > 0 Then s &= ", "
            s &= EntryLink(f)
        ElseIf gCall(CLng(e) * gNEn + f) = 2 Then
            If Len(s2) > 0 Then s2 &= ", "
            s2 &= EntryLink(f) & " <span class=" & q & "tag" & q & ">" & HtmlEsc(KindLabel(f)) & "</span>"
        End If
    Next
    If s <> "" Then Emit "<div><b>Roept aan</b> " & s & "</div>"
    If s2 <> "" Then Emit "<div><b>Registreert</b> " & s2 & "</div>"

    '' aangeroepen door
    If gEnKind(e) <> EN_MAIN Then
        s = "" : seen = "|"
        For k = 0 To gNE - 1
            If gEdTo(k) = gEnLine(e) Then
                Select Case gEdKind(k)
                Case ED_GOSUB, ED_ONGOSUB, ED_ONEVENT, ED_ONERROR
                    If InStr(seen, "|" & NStr(gEdFrom(k)) & "|") = 0 Then
                        seen &= NStr(gEdFrom(k)) & "|"
                        If Len(s) > 0 Then s &= ", "
                        s &= LineLink(gEdFrom(k))
                        s2 = ""
                        For f = 0 To gNEn - 1
                            If IsMember(f, gEdFrom(k)) Then
                                If Len(s2) > 0 Then s2 &= ", "
                                s2 &= "<a href=" & q & EntryHref(f) & q & ">" & HtmlEsc(gEnName(f)) & "</a>"
                            End If
                        Next
                        If s2 = "" Then s2 = "<span class=" & q & "tag dep" & q & ">dode code</span>"
                        s &= " (" & s2 & ")"
                    End If
                End Select
            End If
        Next
        If s = "" Then
            Emit "<div class=" & q & "loc" & q & ">geen aanroepers binnen het programma</div>"
        ElseIf gEnKind(e) = EN_EVENT Or gEnKind(e) = EN_ERROR Then
            Emit "<div><b>Geregistreerd in</b> regel " & s & "</div>"
        Else
            Emit "<div><b>Aangeroepen door</b> regel " & s & "</div>"
        End If
    End If

    '' uitgangen
    s = ""
    For x = 0 To gNL - 1
        If IsMember(e, x) Then
            If gLnRet(x) Then
                If Len(s) > 0 Then s &= ", "
                s &= "<code>RETURN</code> " & LineLink(x)
            End If
            If gLnEnd(x) Then
                If Len(s) > 0 Then s &= ", "
                s &= "<code>END/STOP</code> " & LineLink(x)
            End If
            For k = gLnEd1(x) To gLnEd1(x) + gLnEdN(x) - 1
                Select Case gEdKind(k)
                Case ED_RESUME, ED_RUN, ED_RETURNTO
                    If Len(s) > 0 Then s &= ", "
                    s &= "<code>" & EdgeKindName(gEdKind(k)) & " " & NStr(gEdNum(k)) & "</code> " & LineLink(x)
                End Select
            Next
        End If
    Next
    If s <> "" Then Emit "<div><b>Eindigt via</b> " & s & "</div>"

    '' variabelen
    ReDim rd(0 To gNV + 1), wr(0 To gNV + 1), dm(0 To gNV + 1)
    For u = 0 To gNU - 1
        If IsMember(e, gUsLine(u)) Then
            Select Case gUsMode(u)
            Case 0
                rd(gUsVar(u)) = 1
            Case 1
                wr(gUsVar(u)) = 1
            Case Else
                dm(gUsVar(u)) = 1
            End Select
        End If
    Next
    n = 0
    For v = 0 To gNV - 1
        If rd(v) Or wr(v) Or dm(v) Then
            If n = 0 Then Emit "<table><tr><th>Variabele</th><th>Type</th><th>Gebruik</th></tr>"
            s = ""
            If dm(v) Then s = "DIM"
            If wr(v) Then
                If Len(s) > 0 Then s &= ", "
                s &= "schrijft"
            End If
            If rd(v) Then
                If Len(s) > 0 Then s &= ", "
                s &= "leest"
            End If
            s2 = HtmlEsc(Spellings(gVarNames(v)))
            If gVarArr(v) Then s2 &= "()"
            Emit "<tr><td><a href=" & q & "#V" & NStr(v) & q & "><code>" & s2 & "</code></a></td><td><code>" & TypeName(gVarType(v)) & _
                IIf(gVarArr(v), " array", "") & "</code></td><td>" & s & "</td></tr>"
            n += 1
        End If
    Next
    If n > 0 Then Emit "</table>"
    Emit "</section>"
End Sub

Sub EmitVarSection()
    Dim i As Integer, j As Integer, v As Integer, u As Integer, tmp As Integer, lastLine As Integer
    Dim s As String, s2 As String, q As String
    Dim ord() As Integer
    q = Chr(34)
    Emit "<section class=" & q & "part" & q & " id=" & q & "vars" & q & ">"
    Emit "<h2>Variabelen</h2>"
    Emit "<div class=" & q & "legend" & q & ">MSX-BASIC onderscheidt variabelen alleen op de eerste twee tekens en het type. Zonder suffix of DEFxxx is het type double.</div>"
    If gNV = 0 Then
        Emit "<p>Geen variabelen.</p></section>"
        Exit Sub
    End If
    ReDim ord(0 To gNV - 1)
    For v = 0 To gNV - 1
        ord(v) = v
    Next
    For i = 1 To gNV - 1
        tmp = ord(i) : j = i - 1
        Do While j >= 0
            If gVarKey(ord(j)) <= gVarKey(tmp) Then Exit Do
            ord(j + 1) = ord(j) : j -= 1
        Loop
        ord(j + 1) = tmp
    Next
    Emit "<table><tr><th>Naam</th><th>Type</th><th>Geschreven / DIM</th><th>Gelezen</th></tr>"
    For i = 0 To gNV - 1
        v = ord(i)
        s = "" : s2 = "" : lastLine = -1
        For u = 0 To gNU - 1
            If gUsVar(u) = v And gUsMode(u) <> 0 Then
                If InStr(s & ",", ">" & NStr(gLnNum(gUsLine(u))) & "</a>,") = 0 Then
                    If Len(s) > 0 Then s &= ", "
                    s &= LineLink(gUsLine(u))
                End If
            End If
        Next
        For u = 0 To gNU - 1
            If gUsVar(u) = v And gUsMode(u) = 0 Then
                If gUsLine(u) <> lastLine Then
                    If Len(s2) > 0 Then s2 &= ", "
                    s2 &= LineLink(gUsLine(u))
                    lastLine = gUsLine(u)
                End If
            End If
        Next
        If s = "" Then s = "<span class=" & q & "tag dep" & q & ">nooit</span>"
        If s2 = "" Then s2 = "<span class=" & q & "tag" & q & ">nooit</span>"
        Emit "<tr id=" & q & "V" & NStr(v) & q & "><td><code>" & HtmlEsc(Spellings(gVarNames(v))) & IIf(gVarArr(v), "()", "") & _
            "</code></td><td><code>" & TypeName(gVarType(v)) & IIf(gVarArr(v), " array", "") & "</code></td><td>" & s & "</td><td>" & s2 & "</td></tr>"
    Next
    Emit "</table></section>"
End Sub

Sub EmitMiscSection()
    Dim f As Integer, u As Integer, k As Integer, j As Integer, x As Integer
    Dim s As String, s2 As String, seen As String, q As String
    q = Chr(34)
    Emit "<section class=" & q & "part" & q & " id=" & q & "misc" & q & ">"
    Emit "<h2>Functies, DATA en externe verwijzingen</h2>"

    Emit "<h3>DEF FN</h3>"
    If gNF = 0 Then
        Emit "<p class=" & q & "loc" & q & ">Geen.</p>"
    Else
        Emit "<table><tr><th>Functie</th><th>Gedefinieerd</th><th>Gebruikt in</th></tr>"
        For f = 0 To gNF - 1
            s = ""
            For u = 0 To gNFU - 1
                If Left(gFuName(u), 2) = Left(gFnName(f), 2) And Right(gFuName(u), 1) = Right(gFnName(f), 1) Then
                    If InStr(s & ",", ">" & NStr(gLnNum(gFuLine(u))) & "</a>,") = 0 Then
                        If Len(s) > 0 Then s &= ", "
                        s &= LineLink(gFuLine(u))
                    End If
                End If
            Next
            If s = "" Then s = "<span class=" & q & "tag dep" & q & ">nergens</span>"
            Emit "<tr><td><code>FN" & HtmlEsc(gFnName(f)) & "</code></td><td>" & LineLink(gFnLine(f)) & "</td><td>" & s & "</td></tr>"
        Next
        Emit "</table>"
    End If

    s = "" : x = 0
    Do While x < gNL
        If gLnData(x) Then
            k = x
            Do While x + 1 < gNL
                If gLnData(x + 1) = 0 Then Exit Do
                x += 1
            Loop
            If Len(s) > 0 Then s &= ", "
            If k = x Then s &= LineLink(k) Else s &= LineLink(k) & "&ndash;" & LineLink(x)
        End If
        x += 1
    Loop
    s2 = ""
    For k = 0 To gNE - 1
        If gEdKind(k) = ED_RESTORE Then
            If Len(s2) > 0 Then s2 &= ", "
            s2 &= LineLink(gEdFrom(k)) & " &rarr; "
            If gEdTo(k) >= 0 Then s2 &= LineLink(gEdTo(k)) Else s2 &= NStr(gEdNum(k))
        End If
    Next
    Emit "<h3>DATA</h3>"
    If s = "" And s2 = "" Then
        Emit "<p class=" & q & "loc" & q & ">Geen.</p>"
    Else
        If s <> "" Then Emit "<div><b>DATA-regels</b> " & s & "</div>"
        If s2 <> "" Then Emit "<div><b>RESTORE</b> " & s2 & "</div>"
    End If

    Emit "<h3>Externe verwijzingen</h3>"
    If gNX = 0 Then
        Emit "<p class=" & q & "loc" & q & ">Geen.</p>"
    Else
        Emit "<table><tr><th>Soort</th><th>Naam</th><th>Regels</th></tr>"
        seen = Chr(1)
        For k = 0 To gNX - 1
            If InStr(seen, Chr(1) & gExKind(k) & Chr(2) & gExName(k) & Chr(1)) = 0 Then
                seen &= gExKind(k) & Chr(2) & gExName(k) & Chr(1)
                s = ""
                For j = k To gNX - 1
                    If gExKind(j) = gExKind(k) And gExName(j) = gExName(k) Then
                        If Len(s) > 0 Then s &= ", "
                        s &= LineLink(gExLine(j))
                    End If
                Next
                Emit "<tr><td>" & HtmlEsc(gExKind(k)) & "</td><td><code>" & HtmlEsc(gExName(k)) & "</code></td><td>" & s & "</td></tr>"
            End If
        Next
        Emit "</table>"
    End If
    Emit "</section>"
End Sub

Sub EmitSourceSection()
    Dim x As Integer, e As Integer, rowCls As String, own As String, q As String
    q = Chr(34)
    Emit "<section class=" & q & "part" & q & " id=" & q & "src" & q & ">"
    Emit "<h2>Broncode</h2>"
    Emit "<div class=" & q & "legend" & q & "><span class=" & q & "bg" & q & " style=" & q & "background:var(--deadbg)" & q & ">onbereikbaar</span>" & _
        "<span class=" & q & "bg" & q & " style=" & q & "background:var(--sharedbg)" & q & ">gedeeld door meerdere routines</span>" & _
        "Linkerkolom: routines waartoe de regel hoort (H = hoofdprogramma). Sprongdoelen zijn klikbaar.</div>"
    Emit "<table class=" & q & "src" & q & ">"
    For x = 0 To gNL - 1
        rowCls = ""
        If gLnOwners(x) = 0 And gLnRem(x) = 0 And gLnData(x) = 0 Then rowCls = "dead"
        If gLnOwners(x) > 1 Then rowCls = "shared"
        If gLnEntry(x) >= 0 Then rowCls &= " entry"
        own = ""
        For e = 0 To gNEn - 1
            If IsMember(e, x) Then
                If Len(own) > 0 Then own &= " "
                If gEnKind(e) = EN_MAIN Then
                    own &= "<a href=" & q & EntryHref(e) & q & ">H</a>"
                Else
                    own &= "<a href=" & q & EntryHref(e) & q & ">" & NStr(gLnNum(gEnLine(e))) & "</a>"
                End If
            End If
        Next
        Emit "<tr id=" & q & "L" & NStr(gLnNum(x)) & q & " class=" & q & Trim(rowCls) & q & "><td class=own>" & own & _
            "</td><td class=ln>" & NStr(gLnNum(x)) & "</td><td class=" & q & "code mono" & q & ">" & RenderLine(x) & "</td></tr>"
    Next
    Emit "</table></section>"
End Sub

Sub EmitFilterScript()
    Emit "<script>"
    Emit "(function(){var qi=document.getElementById('q');if(!qi)return;"
    Emit "qi.addEventListener('input',function(){var v=this.value.toLowerCase();"
    Emit "var li=document.querySelectorAll('#side li');"
    Emit "for(var i=0;i<li.length;i++){li[i].style.display=li[i].textContent.toLowerCase().indexOf(v)>-1?'':'none';}});})();"
    Emit "</script>"
End Sub

'' Overgenomen uit egldoc: hover-focus en pan/zoom
Sub EmitGraphScript()
    Emit "<script>"
    Emit "(function(){var svg=document.getElementById('cg');if(!svg)return;"
    Emit "var eds=svg.getElementsByTagName('path'),nds=svg.getElementsByTagName('g');"
    Emit "function reset(){for(var i=0;i<eds.length;i++){eds[i].style.opacity='';eds[i].style.strokeWidth='';}"
    Emit "for(var j=0;j<nds.length;j++){nds[j].style.opacity='';}}"
    Emit "function focusOn(id){for(var i=0;i<eds.length;i++){var p=eds[i];"
    Emit "var f=p.getAttribute('data-from'),t=p.getAttribute('data-to');"
    Emit "if(f===null){continue;}"
    Emit "if(f===id||t===id){p.style.opacity='1';p.style.strokeWidth='2.4';}else{p.style.opacity='0.10';}}"
    Emit "for(var j=0;j<nds.length;j++){var g=nds[j],gi=g.getAttribute('data-id');if(gi===null)continue;"
    Emit "var keep=(gi===id);"
    Emit "if(!keep){for(var k=0;k<eds.length;k++){var f2=eds[k].getAttribute('data-from'),t2=eds[k].getAttribute('data-to');"
    Emit "if((f2===id&&t2===gi)||(t2===id&&f2===gi)){keep=true;break;}}}"
    Emit "g.style.opacity=keep?'1':'0.25';}}"
    Emit "for(var n=0;n<nds.length;n++){(function(g){if(g.getAttribute('data-id')===null)return;"
    Emit "g.onmouseover=function(){focusOn(g.getAttribute('data-id'));};g.onmouseout=reset;})(nds[n]);}"
    Emit "})();"
    Emit "(function(){var svg=document.getElementById('cg');if(!svg)return;"
    Emit "var vp=document.getElementById('vp');if(!vp)return;"
    Emit "var k=1,tx=0,ty=0,drag=false,moved=false,px=0,py=0;"
    Emit "function apply(){vp.setAttribute('transform','translate('+tx+','+ty+') scale('+k+')');}"
    Emit "function pt(e){var p=svg.createSVGPoint();p.x=e.clientX;p.y=e.clientY;"
    Emit "var m=svg.getScreenCTM();if(!m)return null;return p.matrixTransform(m.inverse());}"
    Emit "function zoomAt(x,y,f){var n=k*f;if(n<0.08)n=0.08;if(n>8)n=8;"
    Emit "tx=x-(x-tx)*(n/k);ty=y-(y-ty)*(n/k);k=n;apply();}"
    Emit "function center(){var r=svg.getBoundingClientRect();"
    Emit "return pt({clientX:r.left+r.width/2,clientY:r.top+r.height/2});}"
    Emit "svg.addEventListener('wheel',function(e){var p=pt(e);if(!p)return;e.preventDefault();"
    Emit "zoomAt(p.x,p.y,e.deltaY<0?1.15:1/1.15);},false);"
    Emit "svg.addEventListener('mousedown',function(e){if(e.button!==0)return;"
    Emit "var p=pt(e);if(!p)return;drag=true;moved=false;px=p.x;py=p.y;"
    Emit "svg.setAttribute('class','drag');},false);"
    Emit "window.addEventListener('mousemove',function(e){if(!drag)return;var p=pt(e);if(!p)return;"
    Emit "var dx=p.x-px,dy=p.y-py;if(Math.abs(dx)+Math.abs(dy)>1)moved=true;"
    Emit "tx+=dx;ty+=dy;apply();px=p.x;py=p.y;},false);"
    Emit "window.addEventListener('mouseup',function(){if(!drag)return;drag=false;"
    Emit "svg.setAttribute('class','');},false);"
    Emit "svg.addEventListener('dragstart',function(e){e.preventDefault();},false);"
    Emit "svg.addEventListener('click',function(e){if(moved){e.preventDefault();e.stopPropagation();moved=false;}},true);"
    Emit "var zi=document.getElementById('zin'),zo=document.getElementById('zout'),zf=document.getElementById('zfit');"
    Emit "if(zi)zi.onclick=function(){var c=center();if(c)zoomAt(c.x,c.y,1.3);};"
    Emit "if(zo)zo.onclick=function(){var c=center();if(c)zoomAt(c.x,c.y,1/1.3);};"
    Emit "if(zf)zf.onclick=function(){k=1;tx=0;ty=0;apply();};"
    Emit "})();"
    Emit "</script>"
End Sub

Sub WriteHtml(ByRef outName As String)
    Dim e As Integer, title As String, q As String
    q = Chr(34)
    gOut = FreeFile
    If Open(outName For Output As #gOut) <> 0 Then
        Print "Fout: kan " & outName & " niet schrijven"
        Exit Sub
    End If
    title = gProgTitle
    If title = "" Then title = gFile

    EmitDocHead "MSX-BASIC documentatie - " & title
    EmitHeaderBar title
    Emit "<div class=" & q & "wrap" & q & ">"
    Emit "<nav id=" & q & "side" & q & ">"
    EmitNavList
    Emit "</nav>"
    Emit "<main>"
    EmitCoverageBlock
    EmitGraphSection
    EmitDeadSection
    EmitWarnSection
    EmitOverview title
    For e = 0 To gNEn - 1
        EmitRoutineSection e
    Next
    EmitVarSection
    EmitMiscSection
    EmitSourceSection
    Emit "</main></div>"
    EmitFilterScript
    EmitGraphScript
    Emit "</body></html>"
    Close #gOut
End Sub

Function DotEsc(ByRef s As String) As String
    DotEsc = ReplaceAll(ReplaceAll(s, "\", "\\"), """", "\""")
End Function

Sub WriteDot(ByRef outName As String)
    Dim h As Integer, e As Integer, f As Integer, c As Integer, shp As String
    h = FreeFile
    If Open(outName For Output As #h) <> 0 Then
        Print "Fout: kan " & outName & " niet schrijven"
        Exit Sub
    End If
    Print #h, "digraph msxbasic {"
    Print #h, "  rankdir=LR;"
    Print #h, "  node [shape=box, style=rounded, fontname=""Helvetica"", fontsize=10];"
    For e = 0 To gNEn - 1
        Select Case gEnKind(e)
        Case EN_MAIN
            shp = ", style=""rounded,bold"""
        Case EN_EVENT
            shp = ", style=""rounded,dashed"""
        Case EN_ERROR
            shp = ", color=""#a8321d"""
        Case Else
            shp = ""
        End Select
        Print #h, "  R" & NStr(gLnNum(gEnLine(e))) & " [label=""" & NStr(gLnNum(gEnLine(e))) & "\n" & DotEsc(gEnName(e)) & """" & shp & "];"
    Next
    For e = 0 To gNEn - 1
        For f = 0 To gNEn - 1
            c = gCall(CLng(e) * gNEn + f)
            If c = 1 Then
                Print #h, "  R" & NStr(gLnNum(gEnLine(e))) & " -> R" & NStr(gLnNum(gEnLine(f))) & ";"
            ElseIf c = 2 Then
                Print #h, "  R" & NStr(gLnNum(gEnLine(e))) & " -> R" & NStr(gLnNum(gEnLine(f))) & " [style=dashed];"
            End If
        Next
    Next
    Print #h, "}"
    Close #h
End Sub
