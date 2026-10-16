#lang "fblite"

'' =====================================================================
''  fbdoc 1.0.0 -- documentatiegenerator voor FreeBASIC
''
''  Een soort van javadoc, maar dan voor .bas en .bi bestanden:
''  - Scant recursief en leest het commentaar boven een declaratie
''    (regels met een apostrof, of een /' ... '/ blok)
''  - Ondersteunt tags: @param @return @returns @throws @author @since
''                      @see @deprecated @brief @note
''  - Ontbreekt commentaar, dan wordt een beschrijving afgeleid uit de
''    procedurenaam, de parameters en het returntype
''  - Aanroepgraaf, inclusief aanroepen zonder haakjes (MijnSub a, b)
''    en verwijzingen via @proc (procedure pointers)
''  - Uitvoer: text | md | html | json | dot | mermaid | tree
''
''  Compileren:
''      fbc -lang fblite -s console fbdoc.bas
'' =====================================================================
Const APP_NAME    = "fbdoc"
Const APP_VERSION = "1.0.0"
'' Compileerdatum van deze binary, zodat je kunt zien of je een verse
'' build draait. __DATE_ISO__ en __TIME__ vult de compiler in.
#define APP_BUILD (__DATE_ISO__ & " " & __TIME__)

#ifdef __FB_WIN32__
    Const PSEP = "\"
#else
    Const PSEP = "/"
#endif

'' file attributes (zelf gedefinieerd, geen dir.bi nodig)
Const ATTR_RDONLY = &h01
Const ATTR_HIDDEN = &h02
Const ATTR_SYSTEM = &h04
Const ATTR_DIR    = &h10
Const ATTR_ARCH   = &h20
'' Windows zet op vrijwel elk bestand de archive-bit en RBD/RTC-workspaces
'' zetten read-only op broncode. Zonder die bits in het masker filtert
'' Dir() ze weg en vind je niets.
Const ATTR_ALL = &h01 Or &h02 Or &h04 Or &h10 Or &h20

'' token soorten
Const TK_IDENT = 1
Const TK_NUM   = 2
Const TK_STR   = 3
Const TK_PUNCT = 4
Const TK_EOL   = 5

'' ---------------------------------------------------------------------
''  datastructuren
'' ---------------------------------------------------------------------
Type ParamInfo
    pname   As String
    ptype   As String
    pmode   As String
    pdesc   As String
    pauto   As Integer
End Type

Type MemberInfo
    kind       As String      '' function | variable | constant | enum
    mname      As String
    sigTxt     As String
    retType    As String
    retDesc    As String
    brief      As String
    detail     As String
    throwsTxt  As String
    seeTxt     As String
    authorTxt  As String
    sinceTxt   As String
    isPrivate  As Integer
    isDeprec   As Integer
    isProto    As Integer
    isAuto     As Integer
    isBound    As Integer    '' gekoppeld via een property, bijv. onClick = fn
    lineNo     As Integer
    ownerPart  As Integer
    paramFirst As Integer
    paramCnt   As Integer
End Type

Type PartInfo
    kind      As String
    pname     As String
    stereo    As String
    pkg       As String
    filePath  As String
    lineNo    As Integer
    brief     As String
    detail    As String
    authorTxt As String
    sinceTxt  As String
    seeTxt    As String
    isDeprec  As Integer
    isAuto    As Integer
    isRef     As Integer    '' alleen gescand voor naamresolutie, niet gedocumenteerd
End Type

Type CallEdge
    fromM  As Integer     '' index in members()
    toM    As Integer     '' index in members(), -1 = extern/onbekend
    toNm   As String      '' naam zoals in de broncode, incl. qualifier
    toQual As String      '' alleen het deel voor de laatste punt
    toPkg  As String      '' volledige package uit de import, indien bekend
    lineNo As Integer
    cnt    As Integer
    isExt  As Integer
    isAmbig As Integer    '' > 0 = naam komt zo vaak voor, dus niet opgelost
    kindC  As Integer     '' 0 = gewone aanroep, 1 = returning to, 2 = onException, 3 = binding
    isSys  As Integer     '' runtimefunctie (ruis), i.t.t. een echte afhankelijkheid
End Type

Type OptSet
    outFile   As String
    fmtTxt    As String
    langTxt   As String
    recurse   As Integer
    inclPriv  As Integer
    doGen     As Integer
    onlyUndoc As Integer
    showCov   As Integer
    failUnder As Double
    quiet     As Integer
    verbose   As Integer
    debugOn   As Integer
    inclExtern As Integer
    maxDepth  As Integer
    followRef As Integer
    followDep As Integer
    refDepth  As Integer
    splitOut  As Integer
    extList   As String
    exclList  As String
    projName  As String
End Type

'' ---------------------------------------------------------------------
''  globale opslag
'' ---------------------------------------------------------------------
Dim Shared opt As OptSet

Dim Shared parts() As PartInfo
Dim Shared partCount As Integer, partCap As Integer

Dim Shared members() As MemberInfo
Dim Shared memberCount As Integer, memberCap As Integer

Dim Shared paramList() As ParamInfo
Dim Shared paramCount As Integer, paramCap As Integer

Dim Shared fileList() As String
Dim Shared fileCount As Integer, fileCap As Integer

'' tokens van het huidige bestand
Dim Shared tokText() As String
Dim Shared tokLine() As Integer
Dim Shared tokKind() As Integer
Dim Shared tokDoc()  As Integer
Dim Shared tokCount As Integer, tokCap As Integer

'' commentaarblokken van het huidige bestand
Dim Shared cmtText() As String
Dim Shared cmtStart() As Integer
Dim Shared cmtEnd() As Integer
Dim Shared cmtInline() As Integer
Dim Shared cmtIsDoc() As Integer
Dim Shared cmtCount As Integer, cmtCap As Integer

Dim Shared pendingCmt As Integer
Dim Shared outH As Integer
Dim Shared logH As Integer
Dim Shared skippedFiles As Integer

Dim Shared edges() As CallEdge
Dim Shared edgeCount As Integer, edgeCap As Integer
Dim Shared onPath() As Integer
Dim Shared expandedM() As Integer

'' layout van de aanroepgraaf (gelaagd, links naar rechts)
Dim Shared gNode() As Integer     '' gNode(n)  = index in members()
Dim Shared gIndex() As Integer    '' gIndex(m) = knoopnummer, 0 = niet in graaf
Dim Shared gLayer() As Integer
Dim Shared gPos() As Integer
Dim Shared gX() As Integer, gY() As Integer, gW() As Integer
Dim Shared gCount As Integer, gLayerMax As Integer

'' imports van het huidige bestand: korte naam -> volledige package
Dim Shared impShort() As String
Dim Shared impFull() As String
Dim Shared impCount As Integer

'' referentiepaden: wel scannen voor resolutie, niet documenteren
Dim Shared refList() As String
Dim Shared refCount As Integer, refCap As Integer
Dim Shared parsingRefs As Integer
Dim Shared collectingRefs As Integer

'' includes en referenties
Dim Shared visProj() As String
Dim Shared visN As Integer
Dim Shared bindNm() As String
Dim Shared bindPart() As Integer
Dim Shared bindN As Integer
Dim Shared outDir As String
Dim Shared memDist() As Integer
Dim Shared ambNm() As String
Dim Shared ambCnt() As Integer
Dim Shared ambN As Integer
Dim Shared incFrom() As String
Dim Shared incWhat() As String
Dim Shared incCount As Integer
Dim Shared incPaths As String
Dim Shared refDone() As Integer

'' overzicht externe afhankelijkheden
Dim Shared extQual() As String
Dim Shared extPkg() As String
Dim Shared extCnt() As Integer
Dim Shared extFn() As String
Dim Shared extN As Integer

'' ---------------------------------------------------------------------
''  declaraties
'' ---------------------------------------------------------------------
Declare Function LC(ByRef s As String) As String
Declare Sub Say(ByRef s As String)
Declare Sub OpenLogEarly()
Declare Function Fmt1(ByVal d As Double) As String
Declare Function Pick(ByRef a As String, ByRef b As String, ByVal nl As Integer) As String
Declare Function IsIdentCh(ByRef c As String) As Integer
Declare Function IsDigitCh(ByRef c As String) As Integer
Declare Function ReplaceAll(ByRef s As String, ByRef f As String, ByRef r As String) As String
Declare Function HtmlEsc(ByRef s As String) As String
Declare Function JsonEsc(ByRef s As String) As String
Declare Function NormSep(ByRef s As String) As String
Declare Function PathBase(ByRef s As String) As String
Declare Function PathExtOf(ByRef s As String) As String
Declare Function ExtWanted(ByRef fn As String) As Integer
Declare Function IsExcluded(ByRef p As String) As Integer
Declare Function IsDirPath(ByRef p As String) As Integer
Declare Function PathParent(ByRef s As String) As String
Declare Function FileExists2(ByRef p As String) As Integer
Declare Function AlreadyVisited(ByRef p As String) As Integer
Declare Sub AddInclude(ByRef fromFile As String, ByRef incName As String)
Declare Function ResolveInclude(ByRef fromFile As String, ByRef incName As String) As String
Declare Sub FollowIncludes(ByVal depth As Integer)
Declare Sub AddFileToList(ByRef p As String)
Declare Sub ScanDirRec(ByRef dirPath As String)
Declare Sub SortFileList()
Declare Sub AddCmt(ByRef txt As String, ByVal ls As Integer, ByVal le As Integer, ByVal inl As Integer, ByVal isDoc As Integer)
Declare Sub AddTok(ByRef t As String, ByVal ln As Integer, ByVal k As Integer)
Declare Function JoinTok(ByVal a As Integer, ByVal b As Integer) As String
Declare Sub TokenizeFile(ByRef fpath As String)
Declare Function SkipQual(ByVal i As Integer) As Integer
Declare Function SkipBraces(ByVal i As Integer) As Integer
Declare Function SkipToSemi(ByVal i As Integer) As Integer
Declare Function IsPartKw(ByRef t As String) As Integer
Declare Function IsProcKw(ByRef t As String) As Integer
Declare Function IsModifierKw(ByRef t As String) As Integer
Declare Function IsBlockKw(ByRef t As String) As Integer
Declare Sub ParseTokens(ByRef fpath As String)
Declare Function NewPart(ByRef k As String, ByRef nm As String, ByRef fpath As String, ByVal ln As Integer, ByRef pkg As String) As Integer
Declare Function NewMember(ByRef k As String, ByRef nm As String, ByVal owner As Integer, ByVal ln As Integer) As Integer
Declare Sub AddParamTok(ByVal midx As Integer, ByVal a As Integer, ByVal b As Integer)
Declare Function NextDocLine(ByRef src As String, ByRef idx As Integer) As String
Declare Sub ApplyDoc(ByVal cidx As Integer, ByVal pidx As Integer, ByVal midx As Integer)
Declare Function Humanize(ByRef s As String) As String
Declare Function GenMemberBrief(ByVal midx As Integer) As String
Declare Function GenPartBrief(ByVal pidx As Integer) As String
Declare Sub GenerateMissing()
Declare Function KindLabel(ByRef k As String) As String
Declare Function MemberSig(ByVal midx As Integer) As String
Declare Sub Emit(ByRef s As String)
Declare Sub OutText()
Declare Sub OutMd()
Declare Sub OutHtml()
Declare Sub OutJson()
Declare Sub OutUndoc()
Declare Function IsCallExcluded(ByRef t As String) As Integer
Declare Function IsBuiltinMethod(ByRef t As String) As Integer
Declare Sub CollectExterns()
Declare Sub OutExternText()
Declare Function IsSysLibName(ByRef t As String) As Integer
Declare Function CallTargetAt(ByVal i As Integer, ByRef nameOut As String) As Integer
Declare Function DeadKind(ByVal midx As Integer) As Integer
Declare Sub ScanBindings(ByVal a As Integer, ByVal b As Integer, ByVal ownerPart As Integer, ByVal ownerFunc As Integer)
Declare Sub ResolveBindings()
Declare Function EdgeKindLabel(ByVal kindC As Integer) As String
Declare Function QualNameStr(ByVal i As Integer) As String
Declare Sub AddCall(ByVal fromM As Integer, ByRef nm As String, ByVal ln As Integer, ByVal kindC As Integer)
Declare Function FindPartByName(ByRef nm As String) As Integer
Declare Function FindFuncInPart(ByVal pidx As Integer, ByRef nm As String) As Integer
Declare Sub ResolveCalls()
Declare Function CalleeCount(ByVal midx As Integer) As Integer
Declare Function CallerCount(ByVal midx As Integer) As Integer
Declare Function MemberFullName(ByVal midx As Integer) As String
Declare Sub BuildGraph()
Declare Sub EmitGraphSvg()
Declare Function NodeLabelW(ByVal midx As Integer) As Integer
Declare Sub OpenOut(ByRef p As String)
Declare Sub CloseOut()
Declare Function SafeName(ByRef s As String) As String
Declare Function PartFile(ByVal pidx As Integer) As String
Declare Function PartHref(ByVal pidx As Integer) As String
Declare Function MemberHref(ByVal midx As Integer) As String
Declare Function GraphHref() As String
Declare Function DepsHref() As String
Declare Function DeadHref() As String
Declare Sub EmitStyleBody()
Declare Sub EmitDocHead(ByRef titleTxt As String)
Declare Sub EmitHeaderBar()
Declare Sub EmitCoverageBlock()
Declare Sub EmitNavList(ByVal frames As Integer)
Declare Sub EmitGraphSection()
Declare Sub EmitDepsSection()
Declare Sub EmitDeadSection()
Declare Sub EmitPartSection(ByVal i As Integer)
Declare Sub EmitFilterScript()
Declare Sub EmitGraphScript()
Declare Sub OutHtmlSplit()
Declare Sub ComputeRefDist()
Declare Function GraphVisible(ByVal midx As Integer) As Integer
Declare Sub CollectAmbig()
Declare Function DotEsc(ByRef s As String) As String
Declare Sub OutDot()
Declare Sub OutMermaid()
Declare Sub OutTree()
Declare Sub TreeBranch(ByVal midx As Integer, ByVal lvl As Integer, ByRef pfx As String)
Declare Sub ShowHelp()

'' =====================================================================
''  algemene helpers
'' =====================================================================
Function LC(ByRef s As String) As String
    LC = LCase(s)
End Function

'' Alle meldingen lopen via Say: naar de console en, als er een logbestand
'' is geopend, ook daarheen. Zo blijft diagnose mogelijk wanneer de console
'' onbruikbaar is (bijv. GUI-subsystem of een IDE die uitvoer opslokt).
Sub Say(ByRef s As String)
    Print s
    If logH > 0 Then
        Print #logH, s
    End If
End Sub

'' Zoekt --log/-L in de argumenten voordat de rest wordt verwerkt, zodat
'' ook de eerste meldingen in het logbestand terechtkomen.
Sub OpenLogEarly()
    Dim As Integer a
    Dim As String t, v
    a = 1
    Do
        t = Command(a)
        If Len(t) = 0 Then Exit Do
        If LCase(t) = "--log" Then
            v = Command(a + 1)
            If Len(v) > 0 Then
                logH = FreeFile
                If Open(v For Output As #logH) <> 0 Then
                    logH = 0
                End If
            End If
            Exit Do
        End If
        a = a + 1
    Loop
End Sub

'' eenvoudige vervanging voor Format() zodat vbcompat.bi niet nodig is
Function Fmt1(ByVal d As Double) As String
    Dim As Integer whole, dec1
    Dim As String sg
    sg = ""
    If d < 0 Then
        sg = "-"
        d = -d
    End If
    whole = Int(d)
    dec1 = Int((d - whole) * 10 + 0.5)
    If dec1 >= 10 Then
        whole = whole + 1
        dec1 = 0
    End If
    Return sg & Str(whole) & "." & Str(dec1)
End Function

Function Pick(ByRef a As String, ByRef b As String, ByVal nl As Integer) As String
    If nl Then Return a
    Return b
End Function

Function IsIdentCh(ByRef c As String) As Integer
    Dim As Integer a
    a = Asc(c)
    If (a >= 65 And a <= 90) Or (a >= 97 And a <= 122) Then Return -1
    If a >= 48 And a <= 57 Then Return -1
    If c = "_" Then Return -1
    Return 0
End Function

Function IsDigitCh(ByRef c As String) As Integer
    Dim As Integer a
    a = Asc(c)
    If a >= 48 And a <= 57 Then Return -1
    Return 0
End Function

Function ReplaceAll(ByRef s As String, ByRef f As String, ByRef r As String) As String
    Dim As String res
    Dim As Integer p, q, lf
    lf = Len(f)
    If lf = 0 Then Return s
    res = ""
    q = 1
    Do
        p = InStr(q, s, f)
        If p = 0 Then Exit Do
        res = res & Mid(s, q, p - q) & r
        q = p + lf
    Loop
    res = res & Mid(s, q)
    Return res
End Function

Function HtmlEsc(ByRef s As String) As String
    Dim As String t
    t = ReplaceAll(s, "&", "&amp;")
    t = ReplaceAll(t, "<", "&lt;")
    t = ReplaceAll(t, ">", "&gt;")
    t = ReplaceAll(t, Chr(34), "&quot;")
    Return t
End Function

Function JsonEsc(ByRef s As String) As String
    Dim As String t
    t = ReplaceAll(s, "\", "\\")
    t = ReplaceAll(t, Chr(34), "\" & Chr(34))
    t = ReplaceAll(t, Chr(13), "")
    t = ReplaceAll(t, Chr(10), "\n")
    t = ReplaceAll(t, Chr(9), "\t")
    Return t
End Function

Function NormSep(ByRef s As String) As String
    Return ReplaceAll(s, "\", "/")
End Function

Function PathBase(ByRef s As String) As String
    Dim As String t
    Dim As Integer i
    t = NormSep(s)
    For i = Len(t) To 1 Step -1
        If Mid(t, i, 1) = "/" Then Return Mid(t, i + 1)
    Next i
    Return t
End Function

Function PathExtOf(ByRef s As String) As String
    Dim As String b
    Dim As Integer i
    b = PathBase(s)
    For i = Len(b) To 1 Step -1
        If Mid(b, i, 1) = "." Then Return LC(Mid(b, i))
    Next i
    Return ""
End Function

Function ExtWanted(ByRef fn As String) As Integer
    Dim As String e
    e = PathExtOf(fn)
    If Len(e) = 0 Then Return 0
    If InStr(opt.extList, ";" & e & ";") > 0 Then Return -1
    Return 0
End Function

Function IsExcluded(ByRef p As String) As Integer
    Dim As String t, pat
    Dim As Integer q, r
    t = LC(NormSep(p))
    q = 1
    Do
        r = InStr(q + 1, opt.exclList, ";")
        If r = 0 Then Exit Do
        pat = Mid(opt.exclList, q + 1, r - q - 1)
        If Len(pat) > 0 Then
            If InStr(t, LC(pat)) > 0 Then Return -1
        End If
        q = r
    Loop
    Return 0
End Function

Function IsDirPath(ByRef p As String) As Integer
    Dim As Long oa, m
    Dim As String f, t
    t = p
    If Len(t) > 1 And Right(t, 1) = PSEP Then t = Left(t, Len(t) - 1)
    If Len(t) > 1 And Right(t, 1) = "/" Then t = Left(t, Len(t) - 1)
    m = ATTR_ALL
    oa = 0
    f = Dir(t, m, oa)
    If opt.debugOn Then
        Say "  [dbg] Dir(" & t & ") -> " & Chr(34) & f & Chr(34) & " attr=&h" & Hex(oa)
    End If
    If Len(f) > 0 Then
        If (oa And ATTR_DIR) <> 0 Then Return -1
    End If
    '' terugvalcontrole: bestaat er iets binnen dit pad?
    oa = 0
    f = Dir(t & PSEP & "*", m, oa)
    If opt.debugOn Then
        Say "  [dbg] Dir(" & t & PSEP & "*) -> " & Chr(34) & f & Chr(34) & " attr=&h" & Hex(oa)
    End If
    If Len(f) > 0 Then Return -1
    Return 0
End Function

'' =====================================================================
''  #include verwerken
''
''  Het FreeBASIC-equivalent van projectverwijzingen: elk bestand vertelt
''  zelf welke .bi bestanden het nodig heeft. Met --follow worden die
''  meegelezen als referentie, zodat aanroepen naar die code oplossen.
'' =====================================================================
Function PathParent(ByRef s As String) As String
    Dim As String t
    Dim As Integer i
    t = s
    If Len(t) > 1 Then
        If Right(t, 1) = PSEP Or Right(t, 1) = "/" Then t = Left(t, Len(t) - 1)
    End If
    For i = Len(t) To 1 Step -1
        If Mid(t, i, 1) = PSEP Or Mid(t, i, 1) = "/" Then
            If i = 1 Then Return PSEP
            Return Left(t, i - 1)
        End If
    Next i
    Return ""
End Function

Function FileExists2(ByRef p As String) As Integer
    Dim As Integer fh
    fh = FreeFile
    If Open(p For Input As #fh) <> 0 Then Return 0
    Close #fh
    Return -1
End Function

Function AlreadyVisited(ByRef p As String) As Integer
    Dim As Integer i
    For i = 1 To visN
        If LC(NormSep(visProj(i))) = LC(NormSep(p)) Then Return -1
    Next i
    visN = visN + 1
    ReDim Preserve visProj(1 To visN)
    visProj(visN) = p
    Return 0
End Function

'' Legt vast welk bestand welk bestand insluit; vormt het overzicht van
'' afhankelijkheden tussen bestanden.
Sub AddInclude(ByRef fromFile As String, ByRef incName As String)
    incCount = incCount + 1
    ReDim Preserve incFrom(1 To incCount)
    ReDim Preserve incWhat(1 To incCount)
    incFrom(incCount) = fromFile
    incWhat(incCount) = incName
End Sub

'' Zoekt een ingesloten bestand: eerst naast het insluitende bestand,
'' daarna in de mappen die met -I zijn opgegeven.
Function ResolveInclude(ByRef fromFile As String, ByRef incName As String) As String
    Dim As String basePath, cand, dirPart
    Dim As Integer k, p2, q2

    basePath = ReplaceAll(incName, "/", PSEP)
    dirPart = PathParent(fromFile)
    If Len(dirPart) > 0 Then
        cand = dirPart & PSEP & basePath
        If FileExists2(cand) Then Return cand
    End If
    If FileExists2(basePath) Then Return basePath

    p2 = 1
    Do
        q2 = InStr(p2 + 1, incPaths, ";")
        If q2 = 0 Then Exit Do
        cand = Mid(incPaths, p2 + 1, q2 - p2 - 1)
        If Len(cand) > 0 Then
            cand = cand & PSEP & basePath
            If FileExists2(cand) Then Return cand
        End If
        p2 = q2
    Loop
    Return ""
End Function

'' Volgt de includes van de al ingelezen bestanden en voegt ze toe als
'' referentie. Werkt in rondes, zodat ook includes van includes meekomen.
Sub FollowIncludes(ByVal depth As Integer)
    Dim As Integer i, ronde, added, startIdx
    Dim As String full

    For ronde = 1 To depth
        added = 0
        startIdx = incCount
        For i = 1 To startIdx
            full = ResolveInclude(incFrom(i), incWhat(i))
            If Len(full) = 0 Then
                If opt.debugOn Then Say "  [dbg] include niet gevonden: " & incWhat(i)
                Continue For
            End If
            If AlreadyVisited(full) Then Continue For
            If ExtWanted(PathBase(full)) = 0 Then Continue For
            If opt.quiet = 0 Then Say "  include: " & PathBase(full)
            collectingRefs = -1
            AddFileToList(full)
            collectingRefs = 0
            added = added + 1
        Next i
        If added = 0 Then Exit For
        '' de nieuw toegevoegde bestanden zijn nog niet geparseerd; hun
        '' eigen includes komen in de volgende ronde aan bod
        parsingRefs = -1
        For i = 1 To refCount
            If refDone(i) Then Continue For
            refDone(i) = -1
            TokenizeFile(refList(i))
            ParseTokens(refList(i))
        Next i
        parsingRefs = 0
    Next ronde
End Sub

Sub AddFileToList(ByRef p As String)
    If collectingRefs Then
        If refCount + 1 > refCap Then
            If refCap = 0 Then refCap = 128 Else refCap = refCap * 2
            ReDim Preserve refList(1 To refCap)
        End If
        refCount = refCount + 1
        refList(refCount) = p
        Exit Sub
    End If
    If fileCount + 1 > fileCap Then
        If fileCap = 0 Then fileCap = 128 Else fileCap = fileCap * 2
        ReDim Preserve fileList(1 To fileCap)
    End If
    fileCount = fileCount + 1
    fileList(fileCount) = p
End Sub

Sub ScanDirRec(ByRef dirPath As String)
    Dim As String names(), f, full
    Dim As Integer isDir(), attrs(), n, i
    Dim As Long oa, m

    n = 0
    m = ATTR_ALL
    oa = 0
    f = Dir(dirPath & PSEP & "*", m, oa)
    While Len(f) > 0
        If f <> "." And f <> ".." Then
            n = n + 1
            ReDim Preserve names(1 To n)
            ReDim Preserve isDir(1 To n)
            ReDim Preserve attrs(1 To n)
            names(n) = f
            attrs(n) = oa
            If (oa And ATTR_DIR) <> 0 Then isDir(n) = -1 Else isDir(n) = 0
        End If
        oa = 0
        f = Dir(oa)
    Wend

    If opt.debugOn Then
        Say "  [dbg] map " & dirPath & " : " & Str(n) & " entries"
    End If

    For i = 1 To n
        full = dirPath & PSEP & names(i)
        If IsExcluded(full) Then
            If opt.debugOn Then Say "  [dbg]   uitgesloten: " & names(i)
        ElseIf isDir(i) Then
            If opt.debugOn Then Say "  [dbg]   <DIR> " & names(i)
            If opt.recurse Then ScanDirRec(full)
        ElseIf ExtWanted(names(i)) = 0 Then
            If opt.debugOn Then Say "  [dbg]   extensie niet gewenst: " & names(i) & " (" & PathExtOf(names(i)) & ") attr=&h" & Hex(attrs(i))
        Else
            If opt.debugOn Then Say "  [dbg]   + " & names(i) & " attr=&h" & Hex(attrs(i))
            AddFileToList(full)
        End If
    Next i
End Sub

Sub SortFileList()
    Dim As Integer i, j
    Dim As String tmp
    For i = 2 To fileCount
        tmp = fileList(i)
        j = i - 1
        While j >= 1
            If LC(fileList(j)) > LC(tmp) Then
                fileList(j + 1) = fileList(j)
                j = j - 1
            Else
                Exit While
            End If
        Wend
        fileList(j + 1) = tmp
    Next i
End Sub

'' =====================================================================
''  tokenizer
'' =====================================================================
Sub AddCmt(ByRef txt As String, ByVal ls As Integer, ByVal le As Integer, ByVal inl As Integer, ByVal isDoc As Integer)
    If cmtCount + 1 > cmtCap Then
        If cmtCap = 0 Then cmtCap = 64 Else cmtCap = cmtCap * 2
        ReDim Preserve cmtText(1 To cmtCap)
        ReDim Preserve cmtStart(1 To cmtCap)
        ReDim Preserve cmtEnd(1 To cmtCap)
        ReDim Preserve cmtInline(1 To cmtCap)
        ReDim Preserve cmtIsDoc(1 To cmtCap)
    End If
    cmtCount = cmtCount + 1
    cmtText(cmtCount)   = txt
    cmtStart(cmtCount)  = ls
    cmtEnd(cmtCount)    = le
    cmtInline(cmtCount) = inl
    cmtIsDoc(cmtCount)  = isDoc
End Sub

Sub AddTok(ByRef t As String, ByVal ln As Integer, ByVal k As Integer)
    If tokCount + 1 > tokCap Then
        If tokCap = 0 Then tokCap = 1024 Else tokCap = tokCap * 2
        ReDim Preserve tokText(1 To tokCap)
        ReDim Preserve tokLine(1 To tokCap)
        ReDim Preserve tokKind(1 To tokCap)
        ReDim Preserve tokDoc(1 To tokCap)
    End If
    tokCount = tokCount + 1
    tokText(tokCount) = t
    tokLine(tokCount) = ln
    tokKind(tokCount) = k
    tokDoc(tokCount)  = pendingCmt
    pendingCmt = -1
End Sub

Function JoinTok(ByVal a As Integer, ByVal b As Integer) As String
    Dim As String s, t, pv
    Dim As Integer k
    s = ""
    If a < 1 Then Return ""
    If b > tokCount Then b = tokCount
    For k = a To b
        t = tokText(k)
        If Len(s) > 0 Then
            pv = Right(s, 1)
            If t = "," Or t = ")" Or t = "]" Or t = ";" Or t = "(" Or t = "[" Or t = "?" Or t = "." Then
                '' geen spatie
            ElseIf pv = "(" Or pv = "[" Or pv = "." Then
                '' geen spatie
            Else
                s = s & " "
            End If
        End If
        s = s & t
    Next k
    Return s
End Function

Sub TokenizeFile(ByRef fpath As String)
    Dim As Integer fh, lineNo, i, blockLvl, hadCode, blkStart, blkInline
    Dim As Integer p, lastLineCmt, lastCmtEnd, contLine
    Dim As String ln, ch, nx, buf, blkBuf, q, trimmed

    tokCount = 0
    cmtCount = 0
    pendingCmt = -1
    blockLvl = 0
    blkBuf = ""
    lineNo = 0
    lastLineCmt = 0
    lastCmtEnd = -99
    contLine = 0

    fh = FreeFile
    If Open(fpath For Input As #fh) <> 0 Then
        Say "  ! kan bestand niet openen: " & fpath
        skippedFiles = skippedFiles + 1
        Exit Sub
    End If

    While Not EOF(fh)
        Line Input #fh, ln
        lineNo = lineNo + 1
        ln = ReplaceAll(ln, Chr(9), " ")
        hadCode = 0
        i = 1

        While i <= Len(ln)
            ch = Mid(ln, i, 1)

            If blockLvl > 0 Then
                '' in een /' ... '/ blok; die zijn in FreeBASIC nestbaar
                If Mid(ln, i, 2) = "/'" Then
                    blockLvl = blockLvl + 1
                    blkBuf = blkBuf & "/'"
                    i = i + 2
                ElseIf Mid(ln, i, 2) = "'/" Then
                    blockLvl = blockLvl - 1
                    If blockLvl = 0 Then
                        i = i + 2
                        AddCmt(blkBuf, blkStart, lineNo, blkInline, 0)
                        If blkInline = 0 Then
                            pendingCmt = cmtCount
                            lastCmtEnd = lineNo
                            lastLineCmt = 0
                        End If
                        blkBuf = ""
                    Else
                        blkBuf = blkBuf & "'/"
                        i = i + 2
                    End If
                Else
                    blkBuf = blkBuf & ch
                    i = i + 1
                End If

            ElseIf ch = " " Then
                i = i + 1

            ElseIf Mid(ln, i, 2) = "/'" Then
                blkStart = lineNo
                blkInline = hadCode
                blockLvl = 1
                blkBuf = ""
                i = i + 2
                '' /'' markeert een doc-blok; de extra apostrof hoort niet in de tekst
                If Mid(ln, i, 1) = "'" Then i = i + 1
                lastLineCmt = 0

            ElseIf ch = "'" Then
                '' regelcommentaar tot einde regel
                buf = Trim(Mid(ln, i + 1))
                While Left(buf, 1) = "'"
                    buf = Trim(Mid(buf, 2))
                Wend
                If hadCode Then
                    AddCmt(buf, lineNo, lineNo, -1, 0)
                Else
                    If lastLineCmt <> 0 And lastCmtEnd = lineNo - 1 And cmtCount > 0 Then
                        cmtText(cmtCount) = cmtText(cmtCount) & Chr(10) & buf
                        cmtEnd(cmtCount) = lineNo
                        pendingCmt = cmtCount
                    Else
                        AddCmt(buf, lineNo, lineNo, 0, 0)
                        pendingCmt = cmtCount
                    End If
                    lastLineCmt = -1
                    lastCmtEnd = lineNo
                End If
                i = Len(ln) + 1

            ElseIf ch = Chr(34) Then
                q = ch
                buf = ch
                i = i + 1
                While i <= Len(ln)
                    nx = Mid(ln, i, 1)
                    buf = buf & nx
                    If nx = q Then
                        If Mid(ln, i + 1, 1) = q Then
                            buf = buf & q
                            i = i + 2
                        Else
                            i = i + 1
                            Exit While
                        End If
                    Else
                        i = i + 1
                    End If
                Wend
                AddTok(buf, lineNo, TK_STR)
                hadCode = -1
                lastLineCmt = 0

            ElseIf IsIdentCh(ch) Then
                buf = ""
                While i <= Len(ln)
                    nx = Mid(ln, i, 1)
                    If IsIdentCh(nx) = 0 Then Exit While
                    buf = buf & nx
                    i = i + 1
                Wend
                '' typesuffix zoals naam$ hoort bij de naam
                If i <= Len(ln) Then
                    If Mid(ln, i, 1) = "$" Then
                        buf = buf & "$"
                        i = i + 1
                    End If
                End If
                If IsDigitCh(Left(buf, 1)) Then
                    AddTok(buf, lineNo, TK_NUM)
                ElseIf LC(buf) = "rem" And hadCode = 0 Then
                    '' Rem-commentaar gedraagt zich als een apostrof
                    buf = Trim(Mid(ln, i))
                    AddCmt(buf, lineNo, lineNo, 0, 0)
                    pendingCmt = cmtCount
                    lastLineCmt = -1
                    lastCmtEnd = lineNo
                    i = Len(ln) + 1
                Else
                    AddTok(buf, lineNo, TK_IDENT)
                    hadCode = -1
                    lastLineCmt = 0
                End If

            ElseIf ch = "&" And (LC(Mid(ln, i + 1, 1)) = "h" Or LC(Mid(ln, i + 1, 1)) = "b" Or LC(Mid(ln, i + 1, 1)) = "o") Then
                buf = Mid(ln, i, 2)
                i = i + 2
                While i <= Len(ln)
                    nx = Mid(ln, i, 1)
                    If IsIdentCh(nx) = 0 Then Exit While
                    buf = buf & nx
                    i = i + 1
                Wend
                AddTok(buf, lineNo, TK_NUM)
                hadCode = -1
                lastLineCmt = 0

            ElseIf ch = ":" Then
                '' statementscheider binnen een regel
                AddTok(":", lineNo, TK_EOL)
                i = i + 1
                hadCode = -1
                lastLineCmt = 0

            Else
                AddTok(ch, lineNo, TK_PUNCT)
                i = i + 1
                hadCode = -1
                lastLineCmt = 0
            End If
        Wend

        '' regeleinde is een statementeinde, tenzij de regel op _ eindigt
        contLine = 0
        trimmed = RTrim(ln)
        If Right(trimmed, 1) = "_" Then
            If Len(trimmed) = 1 Then
                contLine = -1
            ElseIf IsIdentCh(Mid(trimmed, Len(trimmed) - 1, 1)) = 0 Then
                contLine = -1
            End If
        End If
        If blockLvl > 0 Then
            blkBuf = blkBuf & Chr(10)
        ElseIf contLine = 0 Then
            If tokCount > 0 Then
                If tokKind(tokCount) <> TK_EOL Then AddTok("", lineNo, TK_EOL)
            End If
        Else
            '' de _ zelf is geen token
            If tokCount > 0 Then
                If tokText(tokCount) = "_" Then tokCount = tokCount - 1
            End If
        End If
    Wend

    Close #fh

    If blockLvl > 0 Then AddCmt(blkBuf, blkStart, lineNo, blkInline, 0)
    AddTok("", lineNo + 1, TK_EOL)
End Sub

'' =====================================================================
''  parser hulpfuncties
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
''  doc-commentaar verwerken
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
    Dim As Integer nl
    nl = 0
    If LC(opt.langTxt) = "nl" Then nl = -1
    Select Case LC(k)
    Case "module"
        If nl Then Return "Module" Else Return "Module"
    Case "type"
        Return "Type"
    Case "union"
        Return "Union"
    Case "enum"
        If nl Then Return "Enumeratie" Else Return "Enumeration"
    Case "namespace"
        Return "Namespace"
    Case "class"
        Return "Class"
    Case "file"
        If nl Then Return "Bestand" Else Return "File"
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

'' =====================================================================
''  signatuur opbouwen
'' =====================================================================
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

'' =====================================================================
''  automatische beschrijvingen
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


'' =====================================================================
''  uitvoer
'' =====================================================================
Sub Emit(ByRef s As String)
    If outH > 0 Then
        Print #outH, s
    Else
        Print s
    End If
End Sub

Sub OutText()
    Dim As Integer i, k, pf, pc, j
    Dim As String s

    Emit "=====================================================================" 
    Emit " FreeBASIC documentatie" 
    If Len(opt.projName) > 0 Then Emit " Project : " & opt.projName
    Emit " Datum   : " & Date & " " & Time
    Emit " Parts   : " & Str(partCount) & "   leden: " & Str(memberCount)
    Emit "====================================================================="
    Emit ""

    For i = 1 To partCount
        If parts(i).isRef Then Continue For
        Emit "---------------------------------------------------------------------"
        s = KindLabel(parts(i).kind) & " " & parts(i).pname
        If Len(parts(i).stereo) > 0 Then s = s & "  (type " & parts(i).stereo & ")"
        Emit s
        Emit "  bestand : " & NormSep(parts(i).filePath) & ":" & Str(parts(i).lineNo)
        If Len(parts(i).pkg) > 0 Then Emit "  package : " & parts(i).pkg
        If parts(i).isAuto Then
            Emit "  " & parts(i).brief & "   [auto]"
        Else
            Emit "  " & parts(i).brief
        End If
        If Len(parts(i).detail) > 0 Then Emit "  " & ReplaceAll(parts(i).detail, Chr(10), Chr(10) & "  ")
        If Len(parts(i).authorTxt) > 0 Then Emit "  auteur  : " & parts(i).authorTxt
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
            Emit "      regel " & Str(members(k).lineNo)
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
                    s = "      -> roept " & MemberFullName(edges(j).toM)
                Else
                    s = "      -> roept " & edges(j).toNm & " [extern]"
                End If
                If edges(j).cnt > 1 Then s = s & " (" & Str(edges(j).cnt) & "x)"
                If edges(j).kindC > 0 Then s = s & "  [" & EdgeKindLabel(edges(j).kindC) & "]"
                Emit s
            Next j
            For j = 1 To edgeCount
                If edges(j).toM <> k Then Continue For
                s = "      <- vanuit " & MemberFullName(edges(j).fromM)
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

    Emit "# FreeBASIC documentatie"
    Emit ""
    If Len(opt.projName) > 0 Then Emit "**Project:** " & opt.projName & "  "
    Emit "**Gegenereerd:** " & Date & " " & Time & " door " & APP_NAME & " " & APP_VERSION & "  "
    Emit "**Parts:** " & Str(partCount) & " | **Leden:** " & Str(memberCount)
    Emit ""
    Emit "## Inhoud"
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
            Emit "> " & parts(i).brief & " _(automatisch gegenereerd)_"
        Else
            Emit parts(i).brief
        End If
        Emit ""
        If Len(parts(i).detail) > 0 Then
            Emit ReplaceAll(parts(i).detail, Chr(10), "  " & Chr(10))
            Emit ""
        End If
        If Len(parts(i).authorTxt) > 0 Then
            Emit "**Auteur:** " & parts(i).authorTxt
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
                Emit members(k).brief & " _(automatisch gegenereerd)_"
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
                Emit "| Parameter | Type | Richting | Beschrijving |"
                Emit "|---|---|---|---|"
                For j = pf To pf + pc - 1
                    If j < 1 Or j > paramCount Then Continue For
                    Emit "| `" & paramList(j).pname & "` | `" & paramList(j).ptype & "` | " & paramList(j).pmode & " | " & paramList(j).pdesc & " |"
                Next j
                Emit ""
            End If
            If Len(members(k).retType) > 0 Then
                Emit "**Returns** `" & members(k).retType & "` &mdash; " & members(k).retDesc
                Emit ""
            End If
            If Len(members(k).throwsTxt) > 0 Then
                Emit "**Exceptions:** " & ReplaceAll(members(k).throwsTxt, Chr(10), "; ")
                Emit ""
            End If
            If Len(members(k).seeTxt) > 0 Then
                Emit "**Zie ook:** " & ReplaceAll(members(k).seeTxt, Chr(10), ", ")
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
                Emit "### Velden en constanten"
                Emit ""
                Emit "| Naam | Type | Soort | Beschrijving |"
                Emit "|---|---|---|---|"
                hasAny = -1
            End If
            Emit "| `" & members(k).mname & "` | `" & members(k).retType & "` | " & members(k).kind & " | " & members(k).brief & " |"
        Next k
        If hasAny Then Emit ""
    Next i
End Sub

Sub OpenOut(ByRef p As String)
    If outH > 0 Then
        Close #outH
        outH = 0
    End If
    outH = FreeFile
    If Open(p For Output As #outH) <> 0 Then
        outH = 0
        Say "FOUT: kan niet schrijven naar " & p
        End 2
    End If
End Sub

Sub CloseOut()
    If outH > 0 Then
        Close #outH
        outH = 0
    End If
End Sub

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
    Emit "<html lang=" & q & "nl" & q & ">"
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
    Emit "<header><h1>FreeBASIC documentatie"
    If Len(opt.projName) > 0 Then Emit " &mdash; " & HtmlEsc(opt.projName)
    Emit "</h1><div class=" & q & "meta" & q & ">" & APP_NAME & " " & APP_VERSION & " (build " & APP_BUILD & ") &middot; " & Date & " " & Time & " &middot; " & Str(partCount) & " parts &middot; " & Str(memberCount) & " leden</div></header>"
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
    Emit "<div class=" & q & "stat" & q & ">Documentatiedekking: <b>" & Str(docd) & "</b> van <b>" & Str(tot) & "</b> elementen heeft echt broncommentaar"
    If tot > 0 Then Emit " (" & Fmt1(docd * 100 / tot) & "%)"
    Emit "</div>"
End Sub

Sub EmitNavList(ByVal frames As Integer)
    Dim As Integer i, k
    Dim As String q, anch, tgt
    q = Chr(34)
    tgt = ""
    If frames Then tgt = " target=" & q & "content" & q
    Emit "<input id=" & q & "q" & q & " placeholder=" & q & "Filter op naam..." & q & ">"
    Emit "<ul>"
    Emit "<li><a href=" & q & GraphHref() & q & tgt & "><b>Aanroepstructuur</b></a></li>"
    Emit "<li><a href=" & q & DepsHref() & q & tgt & "><b>Onopgeloste aanroepen</b></a></li>"
    Emit "<li><a href=" & q & DeadHref() & q & tgt & "><b>Mogelijk ongebruikt</b></a></li>"
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
    Emit "<h2 id=" & q & "graph" & q & ">Aanroepstructuur</h2>"
    If gCount > 0 And gCount <= 1200 Then
        Emit "<div class=" & q & "legend" & q & ">"
        Emit Str(gCount) & " functies, " & Str(edgeCount) & " relaties. Van links naar rechts: aanroeper voor aangeroepene. Klik een blok om naar de documentatie te springen; beweeg erover om alleen de eigen relaties te zien. Sleep om te verschuiven, scrollwiel of de knoppen rechtsonder om te zoomen."
        Emit "<br>Dikke rand = geen aanroeper binnen de gescande code (ingang of dode code). Gestippelde rand = private. Grijs gestippeld blok = referentieproject. Oranje gestippelde pijl = terugkoppeling of recursie. Blauwe fijngestippelde pijl = callback of onException van een service-aanroep."
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
        Emit "<h2 id=" & q & "deps" & q & ">Onopgeloste aanroepen</h2>"
        Emit "<div class=" & q & "legend" & q & ">Aanroepen naar bibliotheken die niet in de gescande code staan. Scan het betreffende project mee met --refs om ze in het diagram op te lossen.</div>"
        Emit "<table class=" & q & "deps" & q & "><tr><th>Bibliotheek</th><th>Package</th><th>Aanroepen</th><th>Functies</th></tr>"
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

    Emit "<h2 id=" & q & "dead" & q & ">Mogelijk ongebruikte code</h2>"
    Emit "<div class=" & q & "legend" & q & ">" & Str(n1) & " functie(s) zonder aanroeper binnen de gescande code, " & Str(n2) & " ingang(en) en " & Str(n3) & " via een property gekoppelde functie(s)."
    Emit "<br>Dit is een aanwijzing, geen bewijs: aanroepen via delegates, dynamische dictionary-toegang, gegenereerde Java of vanuit code buiten de scan worden niet gezien. Scan met --follow of --refs zo veel mogelijk mee voordat je iets weggooit."
    Emit "</div>"

    If n1 = 0 Then
        Emit "<p>Geen functies zonder aanroeper gevonden.</p>"
    Else
        Emit "<h3>Zonder aanroeper</h3>"
        Emit "<table><tr><th>Functie</th><th>Part</th><th>Bestand</th><th>Roept zelf aan</th></tr>"
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
        Emit "<p class=" & q & "loc" & q & ">Een functie die zelf niets aanroept en door niemand wordt aangeroepen is de meest verdachte categorie. Roept hij wel van alles aan, dan hangt daar mogelijk een hele tak ongebruikte code onder.</p>"
    End If

    If n3 > 0 Then
        Emit "<h3>Via een property gekoppeld</h3>"
        Emit "<div class=" & q & "legend" & q & ">Geen directe aanroeper, maar wel gekoppeld in een eigenschappenblok, bijvoorbeeld als event handler.</div>"
        Emit "<table><tr><th>Functie</th><th>Part</th><th>Bestand</th></tr>"
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
        Emit "<h3>Ingangen</h3>"
        Emit "<div class=" & q & "legend" & q & ">Functies in een service, interface of programma: die worden per definitie van buiten aangeroepen.</div>"
        Emit "<table><tr><th>Functie</th><th>Part</th></tr>"
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
            Emit "<div class=" & q & "loc" & q & ">auteur: " & HtmlEsc(parts(i).authorTxt) & "</div>"
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
                Emit "<table><tr><th>Parameter</th><th>Type</th><th>Richting</th><th>Beschrijving</th></tr>"
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
                Emit "<div><b>Returns</b> <code>" & HtmlEsc(members(k).retType) & "</code> &mdash; " & HtmlEsc(members(k).retDesc) & "</div>"
            End If
            If Len(members(k).throwsTxt) > 0 Then
                Emit "<div><b>Exceptions</b> " & HtmlEsc(ReplaceAll(members(k).throwsTxt, Chr(10), "; ")) & "</div>"
            End If
            If Len(members(k).seeTxt) > 0 Then
                Emit "<div><b>Zie ook</b> " & HtmlEsc(ReplaceAll(members(k).seeTxt, Chr(10), ", ")) & "</div>"
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
            If Len(s) > 0 Then Emit "<div><b>Roept aan</b> " & s & "</div>"

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
                Emit "<div><b>Aangeroepen door</b> " & s & "</div>"
            Else
                Emit "<div class=" & q & "loc" & q & ">geen aanroepers binnen de gescande code</div>"
            End If
            Emit "<div class=" & q & "loc" & q & ">" & HtmlEsc(PathBase(parts(i).filePath)) & ":" & Str(members(k).lineNo) & "</div>"
        Next k

        hasAny = 0
        For k = 1 To memberCount
            If members(k).ownerPart <> i Then Continue For
            If members(k).kind = "function" Then Continue For
            If hasAny = 0 Then
                Emit "<h3>Velden, constanten en waarden</h3>"
                Emit "<table><tr><th>Naam</th><th>Type</th><th>Soort</th><th>Beschrijving</th></tr>"
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
    EmitDocHead("FreeBASIC documentatie")
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
    n = 0
    Emit "Elementen zonder broncommentaar"
    Emit "-------------------------------"
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
    Emit "Totaal: " & Str(n)
End Sub

'' =====================================================================
''  aanroepgraaf
'' =====================================================================

'' Woorden die worden gevolgd door '(' maar geen functieaanroep zijn.

'' Ingebouwde methodes op arrays, dictionaries en strings. Die staan achter
'' een lokale variabele (messages.getSize()) en zijn geen functieaanroep.

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

Sub OutExternText()
    Dim As Integer k, p, q2
    Dim As String s, fn

    CollectExterns()
    Emit "---------------------------------------------------------------------"
    Emit "Onopgeloste aanroepen (niet in de gescande code gevonden):"
    Emit ""
    If extN = 0 Then
        Emit "  (geen)"
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
    Emit "Gebruik --follow om de ingesloten bestanden mee te lezen, of geef"
    Emit "een extra pad op met --refs."

    CollectAmbig()
    If ambN > 0 Then
        Emit ""
        Emit "Niet eenduidig opgelost (naam komt in meerdere parts voor):"
        For k = 1 To ambN
            Emit "  " & ambNm(k) & "   (" & Str(ambCnt(k)) & "x)"
        Next k
        Emit "Kwalificeer die aanroepen in de broncode, of beperk de scan."
    End If
End Sub

'' Niet van toepassing in FreeBASIC; hier voor compatibiliteit met de opzet.

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

'' =====================================================================
''  layout van de aanroepgraaf
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

'' =====================================================================
''  Hoe ver staat een referentiefunctie van de gedocumenteerde code af?
''
''  --follow trekt hele projecten naar binnen. Voor de graaf wil je alleen
''  de grens zien: welke functies roept jouw code aan, en eventueel een
''  paar stappen daarachter. Alles wat verder weg ligt valt buiten beeld,
''  anders krijg je een diagram met tienduizenden knopen.
'' =====================================================================
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

'' Backslash en aanhalingsteken in een DOT-label breken de syntax.
Function DotEsc(ByRef s As String) As String
    Dim As String t, bs
    bs = Chr(92)
    t = ReplaceAll(s, bs, bs & bs)
    t = ReplaceAll(t, Chr(34), bs & Chr(34))
    t = ReplaceAll(t, Chr(10), " ")
    t = ReplaceAll(t, Chr(13), "")
    Return t
End Function

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
    Emit "<html lang=" & q & "nl" & q & ">"
    Emit "<head><meta charset=" & q & "utf-8" & q & ">"
    Emit "<title>FreeBASIC documentatie"
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
    Emit "<iframe id=" & q & "navf" & q & " name=" & q & "nav" & q & " src=" & q & "nav.html" & q & " title=" & q & "Navigatie" & q & "></iframe>"
    Emit "<iframe id=" & q & "mainf" & q & " name=" & q & "content" & q & " src=" & q & "overview.html" & q & " title=" & q & "Inhoud" & q & "></iframe>"
    Emit "</div></body></html>"
    CloseOut()

    '' ---- navigatiekolom ----
    OpenOut(d & PSEP & "nav.html")
    EmitDocHead("Navigatie")
    Emit "<nav id=" & q & "side" & q & ">"
    Emit "<div class=" & q & "crumb" & q & "><a href=" & q & "overview.html" & q & " target=" & q & "content" & q & "><b>Overzicht</b></a></div>"
    EmitNavList(-1)
    Emit "</nav>"
    EmitFilterScript()
    Emit "</body></html>"
    CloseOut()

    '' ---- overzichtspagina ----
    OpenOut(d & PSEP & "overview.html")
    EmitDocHead("Overzicht")
    EmitHeaderBar()
    Emit "<main>"
    EmitCoverageBlock()
    Emit "<h2>Inhoud</h2>"
    Emit "<table><tr><th>Part</th><th>Package</th><th>Functies</th><th>Beschrijving</th></tr>"
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
    Emit "<p><a href=" & q & "graph.html" & q & ">Aanroepstructuur</a> &middot; <a href=" & q & "deps.html" & q & ">Onopgeloste aanroepen</a> &middot; <a href=" & q & "dead.html" & q & ">Mogelijk ongebruikt</a></p>"
    Emit "</main></body></html>"
    CloseOut()

    '' ---- diagram ----
    OpenOut(d & PSEP & "graph.html")
    EmitDocHead("Aanroepstructuur")
    Emit "<main>"
    EmitGraphSection()
    Emit "</main>"
    EmitGraphScript()
    Emit "</body></html>"
    CloseOut()

    '' ---- externe afhankelijkheden ----
    OpenOut(d & PSEP & "deps.html")
    EmitDocHead("Onopgeloste aanroepen")
    Emit "<main>"
    EmitDepsSection()
    If extN = 0 Then Emit "<p>Alle aanroepen zijn binnen de gescande code opgelost.</p>"
    Emit "</main></body></html>"
    CloseOut()

    '' ---- mogelijk ongebruikte code ----
    OpenOut(d & PSEP & "dead.html")
    EmitDocHead("Mogelijk ongebruikte code")
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
        Emit "<div class=" & q & "crumb" & q & "><a href=" & q & "overview.html" & q & ">Overzicht</a> &rsaquo; " & HtmlEsc(parts(i).pname) & "</div>"
        EmitPartSection(i)
        Emit "</main></body></html>"
        CloseOut()
        n = n + 1
    Next i

    If opt.quiet = 0 Then
        Say "  " & Str(n + 6) & " bestand(en) geschreven in " & d
    End If
End Sub

Sub OutDot()
    Dim As Integer i, k, e, n, shown
    Dim As String q, lbl, extNames(), en
    Dim As Integer extCount, found

    q = Chr(34)
    extCount = 0

    Emit "// Gegenereerd door " & APP_NAME & " " & APP_VERSION & " op " & Date
    Emit "// Renderen:  dot -Tsvg fbdoc.dot -o fbdoc.svg"
    Emit "digraph fbdoc {"
    Emit "  rankdir=LR;"
    Emit "  graph [fontname=" & q & "Helvetica" & q & ", fontsize=11, compound=true];"
    Emit "  node  [shape=box, style=rounded, fontname=" & q & "Consolas" & q & ", fontsize=10];"
    Emit "  edge  [fontname=" & q & "Helvetica" & q & ", fontsize=8, color=" & q & "#555555" & q & "];"
    Emit ""

    '' per part een cluster met de functies erin
    For i = 1 To partCount
        n = 0
        For k = 1 To memberCount
            If members(k).ownerPart = i Then
                If GraphVisible(k) Then n = n + 1
            End If
        Next k
        If n = 0 Then Continue For

        Emit "  subgraph cluster_" & Str(i) & " {"
        If parts(i).isRef Then
            Emit "    label=" & q & DotEsc(KindLabel(parts(i).kind) & " " & parts(i).pname) & "  (referentie)" & q & ";"
            Emit "    style=" & q & "rounded,dashed" & q & "; color=" & q & "#aaaaaa" & q & "; fontsize=11; fontcolor=" & q & "#777777" & q & ";"
        Else
            Emit "    label=" & q & DotEsc(KindLabel(parts(i).kind) & " " & parts(i).pname) & q & ";"
            Emit "    style=" & q & "rounded" & q & "; color=" & q & "#999999" & q & "; fontsize=11;"
        End If
        For k = 1 To memberCount
            If members(k).ownerPart <> i Then Continue For
            If GraphVisible(k) = 0 Then Continue For
            lbl = members(k).mname
            If parts(i).isRef Then
                Emit "    f" & Str(k) & " [label=" & q & DotEsc(lbl) & q & ", style=" & q & "rounded,dashed" & q & ", color=" & q & "#999999" & q & ", fontcolor=" & q & "#666666" & q & "];"
            ElseIf members(k).isPrivate Then
                Emit "    f" & Str(k) & " [label=" & q & DotEsc(lbl) & q & ", style=" & q & "rounded,dashed" & q & "];"
            ElseIf CallerCount(k) = 0 Then
                '' geen aanroeper binnen de gescande code: ingang of dode code
                Emit "    f" & Str(k) & " [label=" & q & DotEsc(lbl) & q & ", style=" & q & "rounded,filled" & q & ", fillcolor=" & q & "#e8f0fe" & q & "];"
            Else
                Emit "    f" & Str(k) & " [label=" & q & DotEsc(lbl) & q & "];"
            End If
        Next k
        Emit "  }"
    Next i
    Emit ""

    '' externe knopen
    If opt.inclExtern Then
        For e = 1 To edgeCount
            If edges(e).isExt = 0 Then Continue For
            found = 0
            For k = 1 To extCount
                If LC(extNames(k)) = LC(edges(e).toNm) Then found = k
            Next k
            If found = 0 Then
                extCount = extCount + 1
                ReDim Preserve extNames(1 To extCount)
                extNames(extCount) = edges(e).toNm
            End If
        Next e
        For k = 1 To extCount
            Emit "  x" & Str(k) & " [label=" & q & DotEsc(extNames(k)) & q & ", shape=ellipse, style=dashed, color=" & q & "#aa8844" & q & "];"
        Next k
        Emit ""
    End If

    '' kanten
    shown = 0
    For e = 1 To edgeCount
        If GraphVisible(edges(e).fromM) = 0 Then Continue For
        lbl = ""
        If edges(e).kindC > 0 Then
            lbl = " [label=" & q & EdgeKindLabel(edges(e).kindC) & q & ", style=dashed, color=" & q & "#3a7bbf" & q & ", fontcolor=" & q & "#3a7bbf" & q & "]"
        ElseIf edges(e).cnt > 1 Then
            lbl = " [label=" & q & Str(edges(e).cnt) & "x" & q & "]"
        End If

        If edges(e).toM > 0 Then
            If GraphVisible(edges(e).toM) = 0 Then Continue For
            Emit "  f" & Str(edges(e).fromM) & " -> f" & Str(edges(e).toM) & lbl & ";"
            shown = shown + 1
        ElseIf opt.inclExtern Then
            en = ""
            For k = 1 To extCount
                If LC(extNames(k)) = LC(edges(e).toNm) Then en = Str(k)
            Next k
            If Len(en) > 0 Then
                Emit "  f" & Str(edges(e).fromM) & " -> x" & en & lbl & " [style=dashed];"
                shown = shown + 1
            End If
        End If
    Next e

    Emit ""
    Emit "  // " & Str(shown) & " aanroeprelaties"
    Emit "}"

    If opt.quiet = 0 Then
        Say "  diagram: " & Str(shown) & " relaties"
        If shown > 800 Then
            Say "  ! dat is veel voor een leesbaar diagram. Overweeg --ref-depth 0,"
            Say "    een kleiner pad, of render met sfdp in plaats van dot."
        End If
    End If
End Sub

Sub OutMermaid()
    Dim As Integer i, k, e, n
    Dim As String lbl

    Emit "%% Gegenereerd door " & APP_NAME & " " & APP_VERSION & " op " & Date
    Emit "flowchart LR"

    For i = 1 To partCount
        n = 0
        For k = 1 To memberCount
            If members(k).ownerPart = i Then
                If GraphVisible(k) Then n = n + 1
            End If
        Next k
        If n = 0 Then Continue For

        Emit "  subgraph P" & Str(i) & "[" & KindLabel(parts(i).kind) & " " & parts(i).pname & "]"
        For k = 1 To memberCount
            If members(k).ownerPart <> i Then Continue For
            If GraphVisible(k) = 0 Then Continue For
            Emit "    f" & Str(k) & "[" & members(k).mname & "]"
        Next k
        Emit "  end"
    Next i

    For e = 1 To edgeCount
        If edges(e).toM < 1 Then Continue For
        If GraphVisible(edges(e).fromM) = 0 Then Continue For
        If GraphVisible(edges(e).toM) = 0 Then Continue For
        If edges(e).cnt > 1 Then
            Emit "  f" & Str(edges(e).fromM) & " -->|" & Str(edges(e).cnt) & "x| f" & Str(edges(e).toM)
        Else
            Emit "  f" & Str(edges(e).fromM) & " --> f" & Str(edges(e).toM)
        End If
    Next e
End Sub

Sub TreeBranch(ByVal midx As Integer, ByVal lvl As Integer, ByRef pfx As String)
    Dim As Integer e, n, seen, kids, idx
    Dim As String s

    If midx < 1 Then Exit Sub
    If lvl > opt.maxDepth Then
        Emit pfx & "  +-- ... (maximale diepte " & Str(opt.maxDepth) & " bereikt)"
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
            Emit pfx & "+-- " & s & "  [recursief]"
            Continue For
        End If

        seen = 0
        If expandedM(idx) Then
            If CalleeCount(idx) > 0 Then seen = -1
        End If
        If seen Then
            Emit pfx & "+-- " & s & "  [zie eerder]"
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
    Emit " Aanroepstructuur"
    If Len(opt.projName) > 0 Then Emit " Project : " & opt.projName
    Emit " Datum   : " & Date & " " & Time
    Emit " Relaties: " & Str(edgeCount)
    Emit "====================================================================="
    Emit ""
    Emit "Ingangen (functies die binnen de gescande code niet worden aangeroepen):"
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
        Emit "  (geen; mogelijk is alles onderling verbonden of zijn er geen aanroepen herkend)"
        Emit ""
    End If

    Emit "---------------------------------------------------------------------"
    Emit "Mogelijk ongebruikt (geen aanroeper, geen property-koppeling, geen ingang):"
    isolated = 0
    For k = 1 To memberCount
        If DeadKind(k) <> 1 Then Continue For
        isolated = isolated + 1
        i = members(k).ownerPart
        Emit "  " & MemberFullName(k) & "   (" & PathBase(parts(i).filePath) & ":" & Str(members(k).lineNo) & ")"
    Next k
    If isolated = 0 Then Emit "  (geen)"
    Emit ""

    Emit "---------------------------------------------------------------------"
    Emit "Losse functies (geen aanroepers en geen aanroepen):"
    isolated = 0
    For k = 1 To memberCount
        If members(k).kind <> "function" Then Continue For
        If members(k).isPrivate And opt.inclPriv = 0 Then Continue For
        If CallerCount(k) > 0 Or CalleeCount(k) > 0 Then Continue For
        isolated = isolated + 1
        i = members(k).ownerPart
        Emit "  " & MemberFullName(k) & "   (" & PathBase(parts(i).filePath) & ":" & Str(members(k).lineNo) & ")"
    Next k
    If isolated = 0 Then Emit "  (geen)"
    Emit ""
    Emit "Let op: aanroepen via delegates, dynamische dictionary-toegang of"
    Emit "gegenereerde Java worden niet gedetecteerd."
    Emit ""
    OutExternText()
End Sub

'' =====================================================================
''  help
'' =====================================================================
Sub ShowHelp()
    Say APP_NAME & " " & APP_VERSION & " (build " & APP_BUILD & ") - documentatiegenerator voor FreeBASIC"
    Say ""
    Say "Gebruik:  " & APP_NAME & " [opties] <pad> [pad2 ...]"
    Say ""
    Say "Paden mogen mappen of losse bestanden zijn."
    Say ""
    Say "Opties:"
    Say "  -o, --output <bestand>   schrijf uitvoer naar bestand (anders stdout)"
    Say "  -f, --format <fmt>       text | md | html | json | dot | mermaid | tree"
    Say "                           (standaard text)"
    Say "  -l, --lang <nl|en>       taal van gegenereerde teksten  (standaard nl)"
    Say "  -n, --name <naam>        projectnaam in de kop van het rapport"
    Say "  -e, --ext <lijst>        extensies, kommagescheiden (standaard .bas,.bi)"
    Say "  -x, --exclude <patroon>  pad-patroon uitsluiten (meerdere keren toegestaan)"
    Say "  -p, --private            private functies meenemen (standaard aan)"
    Say "      --no-private         alleen publieke functies documenteren"
    Say "  -R, --no-recursive       niet recursief scannen"
    Say "  -G, --no-generate        geen beschrijvingen genereren bij ontbrekend"
    Say "                           commentaar (laat leeg)"
    Say "  -u, --undocumented       toon alleen elementen zonder commentaar"
    Say "  -c, --coverage           print dekkingsoverzicht naar stderr/stdout"
    Say "      --fail-under <pct>   exitcode 1 als dekking onder pct ligt (CI)"
    Say "  -q, --quiet              geen voortgangsmeldingen"
    Say "  -v, --verbose            per bestand meldingen"
    Say "  -d, --debug              toon wat Dir() teruggeeft per map/bestand"
    Say "      --log <bestand>      schrijf alle meldingen ook naar dit bestand"
    Say ""
    Say "Aanroepgraaf (formaten dot, mermaid, tree):"
    Say "      --follow             #include verwijzingen volgen en die bestanden"
    Say "                           als referentie meelezen"
    Say "  -i, --include <map>      zoekpad voor #include (mag meerdere keren)"
    Say "      --follow-depth <n>   hoe diep transitief volgen (standaard 2)"
    Say "      --refs <pad>         extra pad meelezen om aanroepen naar andere"
    Say "                           projecten op te lossen; die code wordt niet"
    Say "                           gedocumenteerd, alleen in het diagram gebruikt"
    Say "                           (mag meerdere keren)"
    Say "      --ref-depth <n>      hoeveel stappen referentiecode in het diagram"
    Say "                           (standaard 1: alleen wat jouw code direct"
    Say "                           aanroept; 0 = geen)"
    Say "      --extern             ook onopgeloste aanroepen tonen"
    Say "      --depth <n>          maximale diepte van de tekstboom (standaard 12)"
    Say "  -h, --help               deze hulp"
    Say "      --version            versie"
    Say ""
    Say "Standaard uitsluitingen: /.git/  /.svn/  /obj/"
    Say ""
    Say "Voorbeelden:"
    Say "  " & APP_NAME & " -f html -o api.html -n " & Chr(34) & "Mijn project" & Chr(34) & " ./src"
    Say "  " & APP_NAME & " -f md -o API.md ./src"
    Say "  " & APP_NAME & " -u -c --fail-under 60 ./src"
    Say "  " & APP_NAME & " -f json -o egldoc.json -p ./src"
    Say "  " & APP_NAME & " -f tree -o calls.txt ./src"
    Say "  " & APP_NAME & " -f dot -o calls.dot ./src"
    Say "  " & APP_NAME & " -f html --split -o docs --follow -i inc ./src"
    Say "     en dan:  dot -Tsvg calls.dot -o calls.svg"
End Sub

'' =====================================================================
''  main
'' =====================================================================
Dim As String argS, pathArgs(1 To 64), nx
Dim As Integer argI, pathCount, i, k, tot, docd
Dim As Double covPct

OpenLogEarly()
Say APP_NAME & " " & APP_VERSION & " (build " & APP_BUILD & ") gestart"

opt.outFile   = ""
opt.fmtTxt    = "text"
opt.langTxt   = "nl"
opt.recurse   = -1
opt.inclPriv  = -1
opt.doGen     = -1
opt.onlyUndoc = 0
opt.showCov   = 0
opt.failUnder = -1
opt.quiet     = 0
opt.verbose   = 0
opt.debugOn   = 0
opt.inclExtern = 0
opt.maxDepth  = 12
opt.followRef = 0
opt.followDep = 2
opt.refDepth  = 1
incPaths = ";"
opt.splitOut  = 0
opt.extList   = ";.bas;.bi;"
opt.exclList  = ";/.git/;/.svn/;/obj/;"
opt.projName  = ""

pathCount = 0
argI = 1
Do
    argS = Command(argI)
    If Len(argS) = 0 Then Exit Do

    '' waarde-opties: controleren of er echt een waarde volgt
    Select Case LC(argS)
    Case "-o", "--output", "-f", "--format", "-l", "--lang", "-n", "--name", _
         "-e", "--ext", "-x", "--exclude", "--fail-under", "--log", "--depth", _
         "--refs", "--ref", "--follow-depth", "--ref-depth"
        nx = Command(argI + 1)
        If Len(nx) = 0 Then
            Say "FOUT: optie " & argS & " verwacht een waarde."
            End 2
        End If
        If Left(nx, 1) = "-" Then
            Say "FOUT: optie " & argS & " verwacht een waarde, maar kreeg " & nx
            End 2
        End If
        Select Case LC(argS)
        Case "-n", "--name", "-f", "--format", "-l", "--lang"
            If InStr(nx, PSEP) > 0 Or InStr(nx, "/") > 0 Or InStr(nx, ":") > 0 Then
                Say "FOUT: " & argS & " kreeg iets dat op een pad lijkt: " & nx
                Say "       Zet de waarde tussen quotes en geef het pad als los argument, bijv:"
                Say "       " & APP_NAME & " -f html -o api.html -n " & Chr(34) & "Mijn project" & Chr(34) & " C:\pad\naar\src"
                End 2
            End If
        End Select
    End Select

    Select Case LC(argS)
    Case "-h", "--help", "/?"
        ShowHelp()
        End 0
    Case "--version"
        Say APP_NAME & " " & APP_VERSION
        Say "gebouwd op " & APP_BUILD
        End 0
    Case "-o", "--output"
        argI = argI + 1
        opt.outFile = Command(argI)
    Case "-f", "--format"
        argI = argI + 1
        opt.fmtTxt = LC(Command(argI))
    Case "-l", "--lang"
        argI = argI + 1
        opt.langTxt = LC(Command(argI))
    Case "-n", "--name"
        argI = argI + 1
        opt.projName = Command(argI)
    Case "-e", "--ext"
        argI = argI + 1
        nx = LC(Command(argI))
        nx = ReplaceAll(nx, " ", "")
        nx = ReplaceAll(nx, ",", ";")
        opt.extList = ";" & nx & ";"
        opt.extList = ReplaceAll(opt.extList, ";;", ";")
    Case "-x", "--exclude"
        argI = argI + 1
        opt.exclList = opt.exclList & LC(Command(argI)) & ";"
    Case "-p", "--private"
        opt.inclPriv = -1
    Case "--no-private", "--public-only"
        opt.inclPriv = 0
    Case "-r", "--no-recursive"
        opt.recurse = 0
    Case "-g", "--no-generate"
        opt.doGen = 0
    Case "-u", "--undocumented"
        opt.onlyUndoc = -1
    Case "-c", "--coverage"
        opt.showCov = -1
    Case "--fail-under"
        argI = argI + 1
        opt.failUnder = Val(Command(argI))
        opt.showCov = -1
    Case "-q", "--quiet"
        opt.quiet = -1
    Case "-v", "--verbose"
        opt.verbose = -1
    Case "-d", "--debug"
        opt.debugOn = -1
        opt.verbose = -1
    Case "--log"
        argI = argI + 1
    Case "--refs", "--ref"
        argI = argI + 1
        collectingRefs = -1
        If IsDirPath(Command(argI)) Then
            nx = Command(argI)
            If Len(nx) > 1 And Right(nx, 1) = PSEP Then nx = Left(nx, Len(nx) - 1)
            ScanDirRec(nx)
        Else
            AddFileToList(Command(argI))
        End If
        collectingRefs = 0
    Case "--follow", "--includes"
        opt.followRef = -1
    Case "-i", "--include"
        argI = argI + 1
        incPaths = incPaths & Command(argI) & ";"
    Case "--follow-depth"
        argI = argI + 1
        opt.followDep = Val(Command(argI))
        If opt.followDep < 0 Then opt.followDep = 0
        opt.followRef = -1
    Case "--ref-depth"
        argI = argI + 1
        opt.refDepth = Val(Command(argI))
        If opt.refDepth < 0 Then opt.refDepth = 0
    Case "--split"
        opt.splitOut = -1
    Case "--extern"
        opt.inclExtern = -1
    Case "--depth"
        argI = argI + 1
        opt.maxDepth = Val(Command(argI))
        If opt.maxDepth < 1 Then opt.maxDepth = 12
    Case Else
        If Left(argS, 1) = "-" Then
            Say "Onbekende optie: " & argS
            Say "Gebruik --help voor hulp."
            End 2
        End If
        If pathCount < 64 Then
            pathCount = pathCount + 1
            pathArgs(pathCount) = argS
        End If
    End Select
    argI = argI + 1
Loop

If pathCount = 0 Then
    Say "FOUT: geen pad opgegeven om te scannen."
    Say ""
    ShowHelp()
    End 2
End If

'' bestanden verzamelen
Dim As String dp
For i = 1 To pathCount
    If IsDirPath(pathArgs(i)) Then
        dp = pathArgs(i)
        If Len(dp) > 1 And Right(dp, 1) = PSEP Then dp = Left(dp, Len(dp) - 1)
        ScanDirRec(dp)
    Else
        AddFileToList(pathArgs(i))
    End If
Next i

'' includes worden gevolgd nadat de hoofdbestanden gelezen zijn

If fileCount = 0 Then
    Say "Geen bestanden gevonden met extensie(s) " & opt.extList
    Say "Gescande pad(en):"
    For i = 1 To pathCount
        nx = "nee"
        If IsDirPath(pathArgs(i)) Then nx = "ja"
        Say "  " & pathArgs(i) & "   (herkend als map: " & nx & ")"
    Next i
    Say "Draai opnieuw met -d om te zien wat Dir() teruggeeft."
    End 2
End If

SortFileList()
ReDim refDone(1 To 8192)

If opt.quiet = 0 Then
    Say APP_NAME & " " & APP_VERSION & ": " & Str(fileCount) & " bestand(en) gevonden"
End If

For i = 1 To fileCount
    If opt.verbose Then Say "  lezen: " & fileList(i)
    TokenizeFile(fileList(i))
    ParseTokens(fileList(i))
Next i

'' referentiebestanden: alleen meegelezen voor naamresolutie
If opt.followRef Then FollowIncludes(opt.followDep)

If refCount > 0 Then
    parsingRefs = -1
    For i = 1 To refCount
        If refDone(i) Then Continue For
        refDone(i) = -1
        If opt.verbose Then Say "  referentie: " & refList(i)
        TokenizeFile(refList(i))
        ParseTokens(refList(i))
    Next i
    parsingRefs = 0
    If opt.quiet = 0 Then Say "  " & Str(refCount) & " referentiebestand(en) meegelezen"
End If

GenerateMissing()
ResolveCalls()
ResolveBindings()
ComputeRefDist()

If opt.quiet = 0 Then
    Say "  " & Str(partCount) & " part(s), " & Str(memberCount) & " lid/leden, " & Str(paramCount) & " parameter(s)"
    Say "  " & Str(edgeCount) & " aanroeprelatie(s)"
End If

If partCount = 0 And memberCount = 0 Then
    Say "LET OP: er zijn " & Str(fileCount) & " bestand(en) gelezen, maar geen declaraties herkend."
    Say "        Controleer of het echt FreeBASIC-bronbestanden zijn (-v toont welke bestanden gelezen worden)."
End If

'' uitvoer openen
If opt.splitOut Then
    If opt.fmtTxt <> "html" And opt.fmtTxt <> "htm" Then
        Say "  ! --split geldt alleen voor -f html; wordt genegeerd"
        opt.splitOut = 0
    End If
End If

outH = 0
If Len(opt.outFile) > 0 And opt.splitOut = 0 Then
    outH = FreeFile
    If Open(opt.outFile For Output As #outH) <> 0 Then
        Say "Kan uitvoerbestand niet schrijven: " & opt.outFile
        End 2
    End If
End If

If opt.onlyUndoc Then
    OutUndoc()
Else
    Select Case opt.fmtTxt
    Case "md", "markdown"
        OutMd()
    Case "html", "htm"
        OutHtml()
    Case "json"
        OutJson()
    Case "dot", "graphviz"
        OutDot()
    Case "mermaid", "mmd"
        OutMermaid()
    Case "tree", "boom", "calls"
        OutTree()
    Case Else
        OutText()
    End Select
End If

If opt.splitOut Then
    If opt.quiet = 0 Then Say "  open " & outDir & PSEP & "index.html in een browser"
End If

If outH > 0 Then
    Close #outH
    outH = 0
    If opt.quiet = 0 Then
        Dim As String shownPath
        shownPath = opt.outFile
        If InStr(shownPath, ":") = 0 And Left(shownPath, 1) <> PSEP And Left(shownPath, 1) <> "/" Then
            shownPath = CurDir & PSEP & shownPath
        End If
        Say "  geschreven: " & shownPath
    End If
End If

'' dekking
tot = 0
docd = 0
For i = 1 To partCount
    If parts(i).isRef Then Continue For
    tot = tot + 1
    If parts(i).isAuto = 0 Then docd = docd + 1
Next i
For k = 1 To memberCount
    If members(k).isPrivate And opt.inclPriv = 0 Then Continue For
    If members(k).ownerPart >= 1 Then
        If parts(members(k).ownerPart).isRef Then Continue For
    End If
    tot = tot + 1
    If members(k).isAuto = 0 Then docd = docd + 1
Next k

covPct = 0
If tot > 0 Then covPct = docd * 100 / tot

If opt.showCov Then
    Say ""
    Say "Documentatiedekking: " & Str(docd) & "/" & Str(tot) & " = " & Fmt1(covPct) & "%"
End If

If opt.failUnder >= 0 Then
    If covPct < opt.failUnder Then
        Say "FOUT: dekking " & Fmt1(covPct) & "% ligt onder de drempel " & Fmt1(opt.failUnder) & "%"
        End 1
    End If
End If

End 0
