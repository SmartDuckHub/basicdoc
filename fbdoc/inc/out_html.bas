'' =====================================================================
''  fbdoc - Uitvoer: html, als een pagina of gesplitst (--split)
'' =====================================================================

'' Bestandsnaamveilige variant van een partnaam.
Function SafeName(ByRef s As String) As String
    Dim As String t, c
    Dim As Integer i
    t = ""
    For i = 1 To Len(s)
        c = Mid(s, i, 1)
        If IsIdentCh(c) Then t = t & c Else t = t & "_"
    Next i
    If Len(t) = 0 Then t = "part"
    Return t
End Function

Function PartFile(ByVal pidx As Integer) As String
    If pidx < 1 Then Return ""
    Return "p" & Str(pidx) & "-" & SafeName(parts(pidx).pname) & ".html"
End Function

'' Verwijzing naar een part: los bestand of anker in dezelfde pagina.
Function PartHref(ByVal pidx As Integer) As String
    If pidx < 1 Then Return ""
    If parts(pidx).isRef Then Return ""
    If opt.splitOut Then Return PartFile(pidx)
    Return "#p" & Str(pidx)
End Function

'' Verwijzing naar een functie. Leeg wanneer er geen pagina voor bestaat,
'' zoals bij functies uit referentieprojecten.
Function MemberHref(ByVal midx As Integer) As String
    Dim As Integer p
    If midx < 1 Then Return ""
    p = members(midx).ownerPart
    If p < 1 Then Return ""
    If parts(p).isRef Then Return ""
    If opt.splitOut Then Return PartFile(p) & "#m" & Str(midx)
    Return "#m" & Str(midx)
End Function

Function GraphHref() As String
    If opt.splitOut Then Return "graph.html"
    Return "#graph"
End Function

Function DepsHref() As String
    If opt.splitOut Then Return "deps.html"
    Return "#deps"
End Function

Function DeadHref() As String
    If opt.splitOut Then Return "dead.html"
    Return "#dead"
End Function

Sub EmitStyleBody()
    Dim As Integer i, j
    Dim As String q
    q = Chr(34)
    Emit ":root{--bg:#ffffff;--fg:#1b1f24;--mut:#5b6570;--line:#dfe3e8;--card:#f6f8fa;--acc:#0b5fa4;--link:#0b5fa4;--auto:#8a5a00;--autobg:#fff4d6;--dep:#a11;}"
    Emit "@media (prefers-color-scheme:dark){:root{--bg:#12161a;--fg:#e6e9ec;--mut:#9aa4ae;--line:#2a3138;--card:#1a1f25;--acc:#5aa9f0;--link:#cdd6de;--auto:#e0b050;--autobg:#332a10;--dep:#f77;}}"
    Emit "*{box-sizing:border-box}"
    Emit "a,a:visited{color:var(--link);text-decoration:none}"
    Emit "a:hover{text-decoration:underline}"
    Emit "a:focus-visible{outline:2px solid var(--link);outline-offset:2px}"
    Emit "body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.55 -apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif}"
    Emit "code,pre,.sig{font-family:Consolas,'DejaVu Sans Mono',monospace}"
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
    Emit "nav a:hover{text-decoration:underline}"
    Emit "main{flex:1 1 auto;padding:18px 26px;min-width:0}"
    Emit "section.part{border-top:1px solid var(--line);padding-top:16px;margin-top:26px}"
    Emit "h2{font-size:20px;margin:0 0 4px}"
    Emit "h3{font-size:15px;margin:22px 0 6px}"
    Emit ".loc{color:var(--mut);font-size:12px}"
    Emit ".sig{background:var(--card);border:1px solid var(--line);border-left:3px solid var(--acc);border-radius:4px;padding:8px 10px;font-size:13px;overflow-x:auto;white-space:pre-wrap}"
    Emit ".brief{margin:8px 0}"
    Emit ".detail{color:var(--fg);white-space:pre-wrap;margin:6px 0}"
    Emit "table{border-collapse:collapse;margin:8px 0;font-size:13px;width:100%}"
    Emit "th,td{border:1px solid var(--line);padding:4px 8px;text-align:left;vertical-align:top}"
    Emit "th{background:var(--card);font-weight:600}"
    Emit ".tag{display:inline-block;font-size:11px;padding:1px 6px;border-radius:9px;border:1px solid var(--line);color:var(--mut);margin-left:6px}"
    Emit ".auto{background:var(--autobg);color:var(--auto);border-color:transparent}"
    Emit ".dep{color:var(--dep);border-color:var(--dep)}"
    Emit ".stat{background:var(--card);border:1px solid var(--line);border-radius:6px;padding:10px 14px;font-size:13px;display:inline-block}"
    Emit ".graphwrap{position:relative;overflow:hidden;border:1px solid var(--line);border-radius:6px;background:var(--card);height:78vh;margin:10px 0}"
    Emit "svg#cg{width:100%;height:100%;display:block;cursor:grab;touch-action:none}"
    Emit "svg#cg.drag{cursor:grabbing}"
    Emit ".zoomctl{position:absolute;right:14px;bottom:14px;z-index:5;display:flex;flex-direction:column}"
    Emit ".zoomctl button{width:34px;height:34px;margin-top:5px;font:16px/1 -apple-system,Segoe UI,Roboto,sans-serif;border:1px solid var(--line);background:var(--bg);color:var(--fg);border-radius:7px;cursor:pointer;box-shadow:0 1px 4px rgba(0,0,0,.25)}"
    Emit ".zoomctl button:hover{background:var(--card)}"
    Emit ".zoomctl button:active{transform:translateY(1px)}"
    Emit "svg#cg text{font-family:Consolas,'DejaVu Sans Mono',monospace;font-size:11px;fill:var(--fg);pointer-events:none}"
    Emit "svg#cg g.n rect{stroke-width:1.2}"
    Emit "svg#cg g.rt rect{stroke-width:2.6}"
    Emit "svg#cg g.pv rect{stroke-dasharray:3 2}"
    Emit "svg#cg g.rf rect{fill:var(--card);stroke:#8a949e;stroke-dasharray:4 3;stroke-width:1}"
    Emit "svg#cg g.rf text{fill:var(--mut)}"
    Emit "table.deps code{font-size:12px}"
    Emit "svg#cg g.n{cursor:pointer}"
    Emit "svg#cg path.e{fill:none;stroke:#8a949e;stroke-width:1.3;marker-end:url(#ah)}"
    Emit "svg#cg path.e.b{stroke:#c0673a;stroke-dasharray:5 3;marker-end:url(#ahb)}"
    Emit "svg#cg path.e.cb{stroke:#3a7bbf;stroke-dasharray:2 3}"
    Emit "svg#cg .ahf{fill:#8a949e}"
    Emit "svg#cg .ahbf{fill:#c0673a}"
    Emit "svg#cg a{text-decoration:none}"
    Emit ".legend{font-size:12px;color:var(--mut);margin:6px 0 14px}"
    Emit ".legend span.sw{display:inline-block;width:11px;height:11px;border-radius:3px;border:1px solid var(--line);vertical-align:-1px;margin:0 4px 0 10px}"
    '' een tint per part, licht en donker
    For i = 1 To partCount
        j = (i * 47) Mod 360
        Emit "svg#cg g.p" & Str(i) & " rect{fill:hsl(" & Str(j) & ",62%,92%);stroke:hsl(" & Str(j) & ",45%,52%)}"
        Emit ".sw" & Str(i) & "{background:hsl(" & Str(j) & ",62%,92%)}"
    Next i
    Emit "@media (prefers-color-scheme:dark){"
    For i = 1 To partCount
        j = (i * 47) Mod 360
        Emit "svg#cg g.p" & Str(i) & " rect{fill:hsl(" & Str(j) & ",30%,24%);stroke:hsl(" & Str(j) & ",40%,58%)}"
        Emit ".sw" & Str(i) & "{background:hsl(" & Str(j) & ",30%,24%)}"
    Next i
    Emit "}"
End Sub

'' <head> met stylesheet: als los bestand (split) of inline (een pagina).
Sub EmitDocHead(ByRef titleTxt As String)
    Dim As String q
    q = Chr(34)
    Emit "<!DOCTYPE html>"
    Emit "<html lang=" & q & langCode & q & ">"
    Emit "<head>"
    Emit "<meta charset=" & q & "utf-8" & q & ">"
    Emit "<meta name=" & q & "viewport" & q & " content=" & q & "width=device-width,initial-scale=1" & q & ">"
    Emit "<title>" & HtmlEsc(titleTxt) & "</title>"
    If opt.splitOut Then
        Emit "<link rel=" & q & "stylesheet" & q & " href=" & q & "style.css" & q & ">"
    Else
        Emit "<style>"
        EmitStyleBody()
        Emit "</style>"
    End If
    Emit "</head><body>"
End Sub

Sub EmitHeaderBar()
    Dim As String q
    q = Chr(34)
    Emit "<header><h1>" & Tr("FreeBASIC documentation")
    If Len(opt.projName) > 0 Then Emit " &mdash; " & HtmlEsc(opt.projName)
    Emit "</h1><div class=" & q & "meta" & q & ">" & APP_NAME & " " & APP_VERSION & " (build " & APP_BUILD & ") &middot; " & Date & " " & Time & " &middot; " & Tr1("%1 parts", Str(partCount)) & " &middot; " & Tr1("%1 members", Str(memberCount)) & "</div></header>"
End Sub

Sub EmitCoverageBlock()
    Dim As Integer i, docd, tot
    Dim As String q
    q = Chr(34)
    docd = 0
    tot = 0
    For i = 1 To partCount
        If parts(i).isRef Then Continue For
        tot = tot + 1
        If parts(i).isAuto = 0 Then docd = docd + 1
    Next i
    For i = 1 To memberCount
        If members(i).ownerPart >= 1 Then
            If parts(members(i).ownerPart).isRef Then Continue For
        End If
        tot = tot + 1
        If members(i).isAuto = 0 Then docd = docd + 1
    Next i
    Emit "<div class=" & q & "stat" & q & ">" & Tr2("Documentation coverage: <b>%1</b> of <b>%2</b> elements have real source comments", Str(docd), Str(tot))
    If tot > 0 Then Emit " (" & Fmt1(docd * 100 / tot) & "%)"
    Emit "</div>"
End Sub

Sub EmitNavList(ByVal frames As Integer)
    Dim As Integer i, k
    Dim As String q, anch, tgt
    q = Chr(34)
    tgt = ""
    If frames Then tgt = " target=" & q & "content" & q
    Emit "<input id=" & q & "q" & q & " placeholder=" & q & Tr("Filter by name...") & q & ">"
    Emit "<ul>"
    Emit "<li><a href=" & q & GraphHref() & q & tgt & "><b>" & Tr("Call structure") & "</b></a></li>"
    Emit "<li><a href=" & q & DepsHref() & q & tgt & "><b>" & Tr("Unresolved calls") & "</b></a></li>"
    Emit "<li><a href=" & q & DeadHref() & q & tgt & "><b>" & Tr("Possibly unused") & "</b></a></li>"
    For i = 1 To partCount
        If parts(i).isRef Then Continue For
        anch = "p" & Str(i)
        Emit "<li><a href=" & q & PartHref(i) & q & tgt & ">" & HtmlEsc(KindLabel(parts(i).kind) & " " & parts(i).pname) & "</a></li>"
        For k = 1 To memberCount
            If members(k).ownerPart <> i Then Continue For
            If members(k).kind <> "function" Then Continue For
            If members(k).isPrivate And opt.inclPriv = 0 Then Continue For
            Emit "<li class=" & q & "f" & q & "><a href=" & q & MemberHref(k) & q & tgt & ">" & HtmlEsc(members(k).mname) & "</a></li>"
        Next k
    Next i
    Emit "</ul>"
End Sub

Sub EmitGraphSection()
    Dim As Integer i, k
    Dim As String q, s
    q = Chr(34)
    '' ---------------- aanroepstructuur ----------------
    BuildGraph()
    Emit "<h2 id=" & q & "graph" & q & ">" & Tr("Call structure") & "</h2>"
    If gCount > 0 And gCount <= 1200 Then
        Emit "<div class=" & q & "legend" & q & ">"
        Emit Tr2("%1 functions, %2 relations. From left to right: caller before callee. Click a block to jump to its documentation; hover over it to see only its own relations. Drag to pan, use the scroll wheel or the buttons at the bottom right to zoom.", Str(gCount), Str(edgeCount))
        Emit "<br>" & Tr("Thick border = no caller within the scanned code (entry point or dead code). Dashed border = private. Grey dashed block = reference project. Orange dashed arrow = feedback or recursion. Blue finely dotted arrow = callback or onException of a service call.")
        Emit "<br>Parts:"
        For i = 1 To partCount
            For k = 1 To gCount
                If members(gNode(k)).ownerPart = i Then
                    Emit "<span class=" & q & "sw sw" & Str(i) & q & "></span>" & HtmlEsc(parts(i).pname)
                    Exit For
                End If
            Next k
        Next i
        Emit "</div>"
    End If
    EmitGraphSvg()
End Sub

Sub EmitDepsSection()
    Dim As Integer i
    Dim As String q, s
    q = Chr(34)
    '' ---------------- externe afhankelijkheden ----------------
    CollectExterns()
    If extN > 0 Then
        Emit "<h2 id=" & q & "deps" & q & ">" & Tr("Unresolved calls") & "</h2>"
        Emit "<div class=" & q & "legend" & q & ">" & Tr("Calls to libraries that are not in the scanned code. Scan the project concerned as well with --refs to resolve them in the diagram.") & "</div>"
        Emit "<table class=" & q & "deps" & q & "><tr><th>" & Tr("Library") & "</th><th>Package</th><th>" & Tr("Call count") & "</th><th>" & Tr("Functions") & "</th></tr>"
        For i = 1 To extN
            s = "<tr><td><code>" & HtmlEsc(extQual(i)) & "</code></td><td><code>"
            If Len(extPkg(i)) > 0 Then s = s & HtmlEsc(extPkg(i)) Else s = s & "?"
            s = s & "</code></td><td>" & Str(extCnt(i)) & "</td><td>"
            s = s & HtmlEsc(ReplaceAll(Mid(extFn(i), 2), "|", " "))
            s = s & "</td></tr>"
            Emit s
        Next i
        Emit "</table>"
    End If
End Sub

Sub EmitDeadSection()
    Dim As Integer k, dk, n1, n2, n3, p
    Dim As String q, s
    q = Chr(34)

    n1 = 0
    n2 = 0
    n3 = 0
    For k = 1 To memberCount
        dk = DeadKind(k)
        If dk = 1 Then n1 = n1 + 1
        If dk = 2 Then n2 = n2 + 1
        If dk = 3 Then n3 = n3 + 1
    Next k

    Emit "<h2 id=" & q & "dead" & q & ">" & Tr("Possibly unused code") & "</h2>"
    Emit "<div class=" & q & "legend" & q & ">" & Tr3("%1 function(s) without a caller within the scanned code, %2 entry point(s) and %3 function(s) bound via a property.", Str(n1), Str(n2), Str(n3))
    Emit "<br>" & Tr("This is a hint, not proof: calls via delegates, dynamic dictionary access, generated Java or from code outside the scan are not seen. Scan as much as possible with --follow or --refs before you throw anything away.")
    Emit "</div>"

    If n1 = 0 Then
        Emit "<p>" & Tr("No functions without a caller found.") & "</p>"
    Else
        Emit "<h3>" & Tr("Without a caller") & "</h3>"
        Emit "<table><tr><th>" & Tr("Function") & "</th><th>Part</th><th>" & Tr("File") & "</th><th>" & Tr("Calls out") & "</th></tr>"
        For k = 1 To memberCount
            If DeadKind(k) <> 1 Then Continue For
            p = members(k).ownerPart
            s = "<tr><td>"
            If Len(MemberHref(k)) > 0 Then
                s = s & "<a href=" & q & MemberHref(k) & q & "><code>" & HtmlEsc(members(k).mname) & "</code></a>"
            Else
                s = s & "<code>" & HtmlEsc(members(k).mname) & "</code>"
            End If
            If members(k).isPrivate Then s = s & " <span class=" & q & "tag" & q & ">private</span>"
            s = s & "</td><td>" & HtmlEsc(parts(p).pname) & "</td><td class=" & q & "loc" & q & ">" & HtmlEsc(PathBase(parts(p).filePath)) & ":" & Str(members(k).lineNo) & "</td><td>" & Str(CalleeCount(k)) & "</td></tr>"
            Emit s
        Next k
        Emit "</table>"
        Emit "<p class=" & q & "loc" & q & ">" & Tr("A function that calls nothing itself and is called by nobody is the most suspicious category. If it does call other code, a whole branch of unused code may hang below it.") & "</p>"
    End If

    If n3 > 0 Then
        Emit "<h3>" & Tr("Bound via a property") & "</h3>"
        Emit "<div class=" & q & "legend" & q & ">" & Tr("No direct caller, but bound in a property block, for example as an event handler.") & "</div>"
        Emit "<table><tr><th>" & Tr("Function") & "</th><th>Part</th><th>" & Tr("File") & "</th></tr>"
        For k = 1 To memberCount
            If DeadKind(k) <> 3 Then Continue For
            p = members(k).ownerPart
            s = "<tr><td>"
            If Len(MemberHref(k)) > 0 Then
                s = s & "<a href=" & q & MemberHref(k) & q & "><code>" & HtmlEsc(members(k).mname) & "</code></a>"
            Else
                s = s & "<code>" & HtmlEsc(members(k).mname) & "</code>"
            End If
            s = s & "</td><td>" & HtmlEsc(parts(p).pname) & "</td><td class=" & q & "loc" & q & ">" & HtmlEsc(PathBase(parts(p).filePath)) & ":" & Str(members(k).lineNo) & "</td></tr>"
            Emit s
        Next k
        Emit "</table>"
    End If

    If n2 > 0 Then
        Emit "<h3>" & Tr("Entry points") & "</h3>"
        Emit "<div class=" & q & "legend" & q & ">" & Tr("Functions in a service, interface or program: these are by definition called from outside.") & "</div>"
        Emit "<table><tr><th>" & Tr("Function") & "</th><th>Part</th></tr>"
        For k = 1 To memberCount
            If DeadKind(k) <> 2 Then Continue For
            p = members(k).ownerPart
            s = "<tr><td>"
            If Len(MemberHref(k)) > 0 Then
                s = s & "<a href=" & q & MemberHref(k) & q & "><code>" & HtmlEsc(members(k).mname) & "</code></a>"
            Else
                s = s & "<code>" & HtmlEsc(members(k).mname) & "</code>"
            End If
            s = s & "</td><td>" & HtmlEsc(KindLabel(parts(p).kind) & " " & parts(p).pname) & "</td></tr>"
            Emit s
        Next k
        Emit "</table>"
    End If
End Sub

Sub EmitPartSection(ByVal i As Integer)
    Dim As Integer k, j, pf, pc, hasAny
    Dim As String q, s, hrefTxt
    q = Chr(34)
        Emit "<section class=" & q & "part" & q & " id=" & q & "p" & Str(i) & q & ">"
        s = "<h2>" & HtmlEsc(KindLabel(parts(i).kind) & " " & parts(i).pname) & "</h2>"
        Emit s
        s = "<div class=" & q & "loc" & q & ">" & HtmlEsc(NormSep(parts(i).filePath)) & ":" & Str(parts(i).lineNo)
        If Len(parts(i).pkg) > 0 Then s = s & " &middot; package " & HtmlEsc(parts(i).pkg)
        If Len(parts(i).stereo) > 0 Then s = s & " &middot; type " & HtmlEsc(parts(i).stereo)
        s = s & "</div>"
        Emit s
        s = "<div class=" & q & "brief" & q & ">" & HtmlEsc(parts(i).brief)
        If parts(i).isAuto Then s = s & "<span class=" & q & "tag auto" & q & ">auto</span>"
        If parts(i).isDeprec Then s = s & "<span class=" & q & "tag dep" & q & ">deprecated</span>"
        s = s & "</div>"
        Emit s
        If Len(parts(i).detail) > 0 Then
            Emit "<div class=" & q & "detail" & q & ">" & HtmlEsc(parts(i).detail) & "</div>"
        End If
        If Len(parts(i).authorTxt) > 0 Then
            Emit "<div class=" & q & "loc" & q & ">" & Tr1("author: %1", HtmlEsc(parts(i).authorTxt)) & "</div>"
        End If

        For k = 1 To memberCount
            If members(k).ownerPart <> i Then Continue For
            If members(k).kind <> "function" Then Continue For
            If members(k).isPrivate And opt.inclPriv = 0 Then Continue For

            s = "<h3 id=" & q & "m" & Str(k) & q & ">" & HtmlEsc(members(k).mname)
            If members(k).isPrivate Then s = s & "<span class=" & q & "tag" & q & ">private</span>"
            If members(k).isProto Then s = s & "<span class=" & q & "tag" & q & ">prototype</span>"
            If members(k).isDeprec Then s = s & "<span class=" & q & "tag dep" & q & ">deprecated</span>"
            If members(k).isAuto Then s = s & "<span class=" & q & "tag auto" & q & ">auto</span>"
            s = s & "</h3>"
            Emit s
            s = ""
            If members(k).isPrivate Then s = "private "
            Emit "<div class=" & q & "sig" & q & ">" & HtmlEsc(s & "function " & members(k).sigTxt) & "</div>"
            Emit "<div class=" & q & "brief" & q & ">" & HtmlEsc(members(k).brief) & "</div>"
            If Len(members(k).detail) > 0 Then
                Emit "<div class=" & q & "detail" & q & ">" & HtmlEsc(members(k).detail) & "</div>"
            End If
            pf = members(k).paramFirst
            pc = members(k).paramCnt
            If pc > 0 Then
                Emit "<table><tr><th>" & Tr("Parameter") & "</th><th>" & Tr("Type") & "</th><th>" & Tr("Direction") & "</th><th>" & Tr("Description") & "</th></tr>"
                For j = pf To pf + pc - 1
                    If j < 1 Or j > paramCount Then Continue For
                    s = "<tr><td><code>" & HtmlEsc(paramList(j).pname) & "</code></td><td><code>" & HtmlEsc(paramList(j).ptype) & "</code></td><td>" & HtmlEsc(paramList(j).pmode) & "</td><td>" & HtmlEsc(paramList(j).pdesc)
                    If paramList(j).pauto Then s = s & "<span class=" & q & "tag auto" & q & ">auto</span>"
                    s = s & "</td></tr>"
                    Emit s
                Next j
                Emit "</table>"
            End If
            If Len(members(k).retType) > 0 Then
                Emit "<div><b>" & Tr("Returns") & "</b> <code>" & HtmlEsc(members(k).retType) & "</code> &mdash; " & HtmlEsc(members(k).retDesc) & "</div>"
            End If
            If Len(members(k).throwsTxt) > 0 Then
                Emit "<div><b>" & Tr("Exceptions") & "</b> " & HtmlEsc(ReplaceAll(members(k).throwsTxt, Chr(10), "; ")) & "</div>"
            End If
            If Len(members(k).seeTxt) > 0 Then
                Emit "<div><b>" & Tr("See also") & "</b> " & HtmlEsc(ReplaceAll(members(k).seeTxt, Chr(10), ", ")) & "</div>"
            End If

            '' aanroepstructuur
            s = ""
            For j = 1 To edgeCount
                If edges(j).fromM <> k Then Continue For
                If edges(j).toM < 1 And edges(j).isSys And opt.inclExtern = 0 Then Continue For
                If Len(s) > 0 Then s = s & ", "
                If edges(j).toM > 0 Then
                    hrefTxt = MemberHref(edges(j).toM)
                    If Len(hrefTxt) > 0 Then
                        s = s & "<a href=" & q & hrefTxt & q & "><code>" & HtmlEsc(MemberFullName(edges(j).toM)) & "</code></a>"
                    Else
                        s = s & "<code>" & HtmlEsc(MemberFullName(edges(j).toM)) & "</code>"
                    End If
                Else
                    s = s & "<code>" & HtmlEsc(edges(j).toNm) & "</code>"
                End If
                If edges(j).cnt > 1 Then s = s & " (" & Str(edges(j).cnt) & "x)"
                If edges(j).kindC > 0 Then s = s & " <span class=" & q & "tag" & q & ">" & EdgeKindLabel(edges(j).kindC) & "</span>"
            Next j
            If Len(s) > 0 Then Emit "<div><b>" & Tr("Calls") & "</b> " & s & "</div>"

            s = ""
            For j = 1 To edgeCount
                If edges(j).toM <> k Then Continue For
                If Len(s) > 0 Then s = s & ", "
                hrefTxt = MemberHref(edges(j).fromM)
                If Len(hrefTxt) > 0 Then
                    s = s & "<a href=" & q & hrefTxt & q & "><code>" & HtmlEsc(MemberFullName(edges(j).fromM)) & "</code></a>"
                Else
                    s = s & "<code>" & HtmlEsc(MemberFullName(edges(j).fromM)) & "</code>"
                End If
            Next j
            If Len(s) > 0 Then
                Emit "<div><b>" & Tr("Called by") & "</b> " & s & "</div>"
            Else
                Emit "<div class=" & q & "loc" & q & ">" & Tr("no callers within the scanned code") & "</div>"
            End If
            Emit "<div class=" & q & "loc" & q & ">" & HtmlEsc(PathBase(parts(i).filePath)) & ":" & Str(members(k).lineNo) & "</div>"
        Next k

        hasAny = 0
        For k = 1 To memberCount
            If members(k).ownerPart <> i Then Continue For
            If members(k).kind = "function" Then Continue For
            If hasAny = 0 Then
                Emit "<h3>" & Tr("Fields, constants and values") & "</h3>"
                Emit "<table><tr><th>" & Tr("Name") & "</th><th>" & Tr("Type") & "</th><th>" & Tr("Kind") & "</th><th>" & Tr("Description") & "</th></tr>"
                hasAny = -1
            End If
            s = "<tr><td><code>" & HtmlEsc(members(k).mname) & "</code></td><td><code>" & HtmlEsc(members(k).retType) & "</code></td><td>" & members(k).kind & "</td><td>" & HtmlEsc(members(k).brief)
            If members(k).isAuto Then s = s & "<span class=" & q & "tag auto" & q & ">auto</span>"
            s = s & "</td></tr>"
            Emit s
        Next k
        If hasAny Then Emit "</table>"
        Emit "</section>"
End Sub

'' Filterveld in de navigatiekolom. Met een null-check, want in de
'' gesplitste uitvoer staat dit veld op een andere pagina dan het diagram.
Sub EmitFilterScript()
    Emit "<script>"
    Emit "(function(){var qi=document.getElementById('q');if(!qi)return;"
    Emit "qi.addEventListener('input',function(){var v=this.value.toLowerCase();"
    Emit "var li=document.querySelectorAll('#side li');"
    Emit "for(var i=0;i<li.length;i++){li[i].style.display=li[i].textContent.toLowerCase().indexOf(v)>-1?'':'none';}});})();"
    Emit "</script>"
End Sub

Sub EmitGraphScript()
    Emit "<script>"
    '' diagram: relaties van de knoop onder de cursor uitlichten
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

    '' pan en zoom zoals bij een kaart: sleep om te verschuiven, scrollwiel
    '' zoomt rond de muispositie, plus knoppen rechtsonder.
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
    '' na slepen geen link volgen
    Emit "svg.addEventListener('dragstart',function(e){e.preventDefault();},false);"
    Emit "svg.addEventListener('click',function(e){if(moved){e.preventDefault();e.stopPropagation();moved=false;}},true);"
    Emit "var zi=document.getElementById('zin'),zo=document.getElementById('zout'),zf=document.getElementById('zfit');"
    Emit "if(zi)zi.onclick=function(){var c=center();if(c)zoomAt(c.x,c.y,1.3);};"
    Emit "if(zo)zo.onclick=function(){var c=center();if(c)zoomAt(c.x,c.y,1/1.3);};"
    Emit "if(zf)zf.onclick=function(){k=1;tx=0;ty=0;apply();};"
    Emit "})();"
    Emit "</script>"
End Sub

'' Alles in een pagina.
Sub OutHtml()
    Dim As Integer i
    Dim As String q
    q = Chr(34)
    If opt.splitOut Then
        OutHtmlSplit()
        Exit Sub
    End If
    EmitDocHead(Tr("FreeBASIC documentation"))
    EmitHeaderBar()
    Emit "<div class=" & q & "wrap" & q & ">"
    Emit "<nav id=" & q & "side" & q & ">"
    EmitNavList(0)
    Emit "</nav>"
    Emit "<main>"
    EmitCoverageBlock()
    EmitGraphSection()
    EmitDepsSection()
    EmitDeadSection()
    For i = 1 To partCount
        If parts(i).isRef Then Continue For
        EmitPartSection(i)
    Next i
    Emit "</main></div>"
    EmitFilterScript()
    EmitGraphScript()
    Emit "</body></html>"
End Sub

'' Alles verdeeld over een map met losse pagina's, met een navigatiekolom
'' in een iframe. Geen <frameset>: die is uit de HTML-standaard verwijderd,
'' maar de indeling en werking zijn hetzelfde.
Sub OutHtmlSplit()
    Dim As Integer i, n, j2
    Dim As String q, d, fn
    q = Chr(34)

    d = opt.outFile
    If Len(d) = 0 Then d = "fbdoc-html"
    If Len(d) > 1 Then
        If Right(d, 1) = PSEP Then d = Left(d, Len(d) - 1)
    End If
    If MkDir(d) <> 0 Then
        '' bestaat waarschijnlijk al; het schrijven zelf geeft anders een fout
    End If
    outDir = d

    BuildGraph()
    CollectExterns()

    '' ---- stylesheet ----
    OpenOut(d & PSEP & "style.css")
    EmitStyleBody()
    Emit "html,body{height:auto}"
    Emit "nav#side{width:auto;flex:none;border:0;position:static;max-height:none;padding:12px}"
    Emit "main{padding:16px 22px}"
    Emit "section.part{border-top:0;margin-top:0;padding-top:0}"
    Emit ".crumb{font-size:12px;color:var(--mut);margin-bottom:10px}"
    CloseOut()

    '' ---- container met de twee frames ----
    OpenOut(d & PSEP & "index.html")
    Emit "<!DOCTYPE html>"
    Emit "<html lang=" & q & langCode & q & ">"
    Emit "<head><meta charset=" & q & "utf-8" & q & ">"
    Emit "<title>" & Tr("FreeBASIC documentation")
    If Len(opt.projName) > 0 Then Emit " &mdash; " & HtmlEsc(opt.projName)
    Emit "</title>"
    Emit "<style>"
    Emit "html,body{margin:0;height:100%;overflow:hidden}"
    Emit ".fwrap{display:flex;height:100vh;width:100%}"
    Emit "iframe{border:0}"
    Emit "#navf{width:310px;flex:0 0 310px;border-right:1px solid #dfe3e8}"
    Emit "#mainf{flex:1 1 auto}"
    Emit "@media (prefers-color-scheme:dark){#navf{border-right-color:#2a3138}}"
    Emit "</style></head>"
    Emit "<body><div class=" & q & "fwrap" & q & ">"
    Emit "<iframe id=" & q & "navf" & q & " name=" & q & "nav" & q & " src=" & q & "nav.html" & q & " title=" & q & Tr("Navigation") & q & "></iframe>"
    Emit "<iframe id=" & q & "mainf" & q & " name=" & q & "content" & q & " src=" & q & "overview.html" & q & " title=" & q & Tr("Content") & q & "></iframe>"
    Emit "</div></body></html>"
    CloseOut()

    '' ---- navigatiekolom ----
    OpenOut(d & PSEP & "nav.html")
    EmitDocHead(Tr("Navigation"))
    Emit "<nav id=" & q & "side" & q & ">"
    Emit "<div class=" & q & "crumb" & q & "><a href=" & q & "overview.html" & q & " target=" & q & "content" & q & "><b>" & Tr("Overview") & "</b></a></div>"
    EmitNavList(-1)
    Emit "</nav>"
    EmitFilterScript()
    Emit "</body></html>"
    CloseOut()

    '' ---- overzichtspagina ----
    OpenOut(d & PSEP & "overview.html")
    EmitDocHead(Tr("Overview"))
    EmitHeaderBar()
    Emit "<main>"
    EmitCoverageBlock()
    Emit "<h2>" & Tr("Contents") & "</h2>"
    Emit "<table><tr><th>Part</th><th>Package</th><th>" & Tr("Functions") & "</th><th>" & Tr("Description") & "</th></tr>"
    For i = 1 To partCount
        If parts(i).isRef Then Continue For
        n = 0
        For j2 = 1 To memberCount
            If members(j2).ownerPart = i Then
                If members(j2).kind = "function" Then n = n + 1
            End If
        Next j2
        Emit "<tr><td><a href=" & q & PartFile(i) & q & ">" & HtmlEsc(KindLabel(parts(i).kind) & " " & parts(i).pname) & "</a></td><td><code>" & HtmlEsc(parts(i).pkg) & "</code></td><td>" & Str(n) & "</td><td>" & HtmlEsc(parts(i).brief) & "</td></tr>"
    Next i
    Emit "</table>"
    Emit "<p><a href=" & q & "graph.html" & q & ">" & Tr("Call structure") & "</a> &middot; <a href=" & q & "deps.html" & q & ">" & Tr("Unresolved calls") & "</a> &middot; <a href=" & q & "dead.html" & q & ">" & Tr("Possibly unused") & "</a></p>"
    Emit "</main></body></html>"
    CloseOut()

    '' ---- diagram ----
    OpenOut(d & PSEP & "graph.html")
    EmitDocHead(Tr("Call structure"))
    Emit "<main>"
    EmitGraphSection()
    Emit "</main>"
    EmitGraphScript()
    Emit "</body></html>"
    CloseOut()

    '' ---- externe afhankelijkheden ----
    OpenOut(d & PSEP & "deps.html")
    EmitDocHead(Tr("Unresolved calls"))
    Emit "<main>"
    EmitDepsSection()
    If extN = 0 Then Emit "<p>" & Tr("All calls were resolved within the scanned code.") & "</p>"
    Emit "</main></body></html>"
    CloseOut()

    '' ---- mogelijk ongebruikte code ----
    OpenOut(d & PSEP & "dead.html")
    EmitDocHead(Tr("Possibly unused code"))
    Emit "<main>"
    EmitDeadSection()
    Emit "</main></body></html>"
    CloseOut()

    '' ---- een pagina per part ----
    n = 0
    For i = 1 To partCount
        If parts(i).isRef Then Continue For
        fn = d & PSEP & PartFile(i)
        OpenOut(fn)
        EmitDocHead(KindLabel(parts(i).kind) & " " & parts(i).pname)
        Emit "<main>"
        Emit "<div class=" & q & "crumb" & q & "><a href=" & q & "overview.html" & q & ">" & Tr("Overview") & "</a> &rsaquo; " & HtmlEsc(parts(i).pname) & "</div>"
        EmitPartSection(i)
        Emit "</main></body></html>"
        CloseOut()
        n = n + 1
    Next i

    If opt.quiet = 0 Then
        Say "  " & Tr2("%1 file(s) written to %2", Str(n + 6), d)
    End If
End Sub
