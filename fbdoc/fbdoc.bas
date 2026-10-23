#lang "fblite"

'' =====================================================================
''  fbdoc 1.1.0 -- documentatiegenerator voor FreeBASIC
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
''  - Engels is de standaardtaal; vertalingen zijn .po-bestanden in de
''    map lang naast de executable (zie inc/lang.bas en CHANGELOG.md)
''
''  Compileren:
''      fbc -lang fblite -s console fbdoc.bas
'' =====================================================================
Const APP_NAME    = "fbdoc"
Const APP_VERSION = "1.1.0"
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
''  onderdelen (map inc)
'' ---------------------------------------------------------------------
#include once "inc/types.bi"
#include once "inc/globals.bi"
#include once "inc/declares.bi"

#include once "inc/util.bas"
#include once "inc/lang.bas"
#include once "inc/files.bas"
#include once "inc/tokenizer.bas"
#include once "inc/parser.bas"
#include once "inc/doccomment.bas"
#include once "inc/autodoc.bas"
#include once "inc/callgraph.bas"
#include once "inc/layout.bas"
#include once "inc/out_text.bas"
#include once "inc/out_html.bas"
#include once "inc/out_graph.bas"
#include once "inc/help.bas"

'' =====================================================================
''  main
'' =====================================================================
Dim As String argS, pathArgs(1 To 64), nx
Dim As Integer argI, pathCount, i, k, tot, docd
Dim As Double covPct

OpenLogEarly()
LangEarly()
Say Tr3("%1 %2 (build %3) started", APP_NAME, APP_VERSION, APP_BUILD)

opt.outFile   = ""
opt.fmtTxt    = "text"
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
            Say Tr1("ERROR: option %1 expects a value.", argS)
            End 2
        End If
        If Left(nx, 1) = "-" Then
            Say Tr2("ERROR: option %1 expects a value, but got %2", argS, nx)
            End 2
        End If
        Select Case LC(argS)
        Case "-n", "--name", "-f", "--format"
            If InStr(nx, PSEP) > 0 Or InStr(nx, "/") > 0 Or InStr(nx, ":") > 0 Then
                Say Tr2("ERROR: %1 got something that looks like a path: %2", argS, nx)
                Say Tr("       Put the value in quotes and give the path as a separate argument, e.g.:")
                Say "       " & APP_NAME & " -f html -o api.html -n " & Chr(34) & Tr("My project") & Chr(34) & " " & Tr("C:\path\to\src")
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
        Say Tr1("built on %1", APP_BUILD)
        End 0
    Case "-o", "--output"
        argI = argI + 1
        opt.outFile = Command(argI)
    Case "-f", "--format"
        argI = argI + 1
        opt.fmtTxt = LC(Command(argI))
    Case "-l", "--lang"
        '' al verwerkt door LangEarly()
        argI = argI + 1
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
            Say Tr1("Unknown option: %1", argS)
            Say Tr("Use --help for help.")
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
    Say Tr("ERROR: no path given to scan.")
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
    Say Tr1("No files found with extension(s) %1", opt.extList)
    Say Tr("Scanned path(s):")
    For i = 1 To pathCount
        nx = Tr("no")
        If IsDirPath(pathArgs(i)) Then nx = Tr("yes")
        Say "  " & pathArgs(i) & "   " & Tr1("(recognised as folder: %1)", nx)
    Next i
    Say Tr("Run again with -d to see what Dir() returns.")
    End 2
End If

SortFileList()
ReDim refDone(1 To 8192)

If opt.quiet = 0 Then
    Say APP_NAME & " " & APP_VERSION & ": " & Tr1("%1 file(s) found", Str(fileCount))
End If

For i = 1 To fileCount
    If opt.verbose Then Say "  " & Tr1("reading: %1", fileList(i))
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
        If opt.verbose Then Say "  " & Tr1("reference: %1", refList(i))
        TokenizeFile(refList(i))
        ParseTokens(refList(i))
    Next i
    parsingRefs = 0
    If opt.quiet = 0 Then Say "  " & Tr1("%1 reference file(s) read", Str(refCount))
End If

GenerateMissing()
ResolveCalls()
ResolveBindings()
ComputeRefDist()

If opt.quiet = 0 Then
    Say "  " & Tr3("%1 part(s), %2 member(s), %3 parameter(s)", Str(partCount), Str(memberCount), Str(paramCount))
    Say "  " & Tr1("%1 call relation(s)", Str(edgeCount))
End If

If partCount = 0 And memberCount = 0 Then
    Say Tr1("NOTE: %1 file(s) were read, but no declarations were recognised.", Str(fileCount))
    Say Tr("      Check that they really are FreeBASIC source files (-v shows which files are read).")
End If

'' uitvoer openen
If opt.splitOut Then
    If opt.fmtTxt <> "html" And opt.fmtTxt <> "htm" Then
        Say "  ! " & Tr("--split only applies to -f html; ignored")
        opt.splitOut = 0
    End If
End If

outH = 0
If Len(opt.outFile) > 0 And opt.splitOut = 0 Then
    outH = FreeFile
    If Open(opt.outFile For Output As #outH) <> 0 Then
        Say Tr1("Cannot write output file: %1", opt.outFile)
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
    If opt.quiet = 0 Then Say "  " & Tr1("open %1 in a browser", outDir & PSEP & "index.html")
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
        Say "  " & Tr1("written: %1", shownPath)
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
    Say Tr3("Documentation coverage: %1/%2 = %3%", Str(docd), Str(tot), Fmt1(covPct))
End If

If opt.failUnder >= 0 Then
    If covPct < opt.failUnder Then
        Say Tr2("ERROR: coverage %1% is below the threshold %2%", Fmt1(covPct), Fmt1(opt.failUnder))
        End 1
    End If
End If

End 0
