'' ============================================================
'' msxbasicdoc - documentatiegenerator voor MSX-BASIC
''
'' Brengt de structuur van een (ASCII-opgeslagen) MSX-BASIC programma
'' in kaart door GOTO/GOSUB/RETURN en verwante sprongen te volgen.
''
'' Engels is de standaardtaal; vertalingen zijn .po-bestanden in de
'' map lang naast het programma (zie inc/mbd_lang.bi).
''
'' Compileren:  fbc -lang fblite msxbasicdoc.bas
'' Gebruik:     msxbasicdoc [opties] PROGRAMMA.BAS [...]
'' ============================================================

#include once "inc/mbd_globals.bi"
#include once "inc/mbd_lang.bi"
#include once "inc/mbd_util.bi"
#include once "inc/mbd_lexer.bi"
#include once "inc/mbd_load.bi"
#include once "inc/mbd_analyse.bi"
#include once "inc/mbd_flow.bi"
#include once "inc/mbd_html.bi"
#include once "inc/mbd_svg.bi"

Sub Usage()
    Print Tr1("msxbasicdoc %1 - documentation for MSX-BASIC programs", MBD_VERSION)
    Print
    Print Tr("Usage: msxbasicdoc [options] PROGRAM.BAS [...]")
    Print
    Print Tr("Options:")
    Print Tr("  -o DIR     output in DIR (default: next to the source file)")
    Print Tr("  -dot       also write a Graphviz .dot file of the call graph")
    Print Tr("  -l CODE    language: en (default), lang/CODE.po next to the")
    Print Tr("             program, or a .po file; MSXBASICDOC_LANG sets the default")
    Print Tr("  -q         quiet: show errors only")
    Print Tr("  -h         this help")
    Print
    Print Tr1("Input must be ASCII (on the MSX: %1).", "SAVE " & Chr(34) & Tr("NAME.BAS") & Chr(34) & ",A")
    Print
    Print Tr("Documentation conventions in comments:")
    Print Tr("  '## Name - description    name of a routine (or of the program, at the top)")
    Print Tr("  '@tag value               free tags, e.g. '@in X,Y  '@out A$")
    Print Tr("  ' plain text              description")
End Sub

Sub ResetState()
    Dim c As Integer
    gNL = 0 : gNT = 0 : gNE = 0 : gNX = 0 : gNU = 0 : gNV = 0
    gNF = 0 : gNFU = 0 : gNEn = 0 : gNW = 0
    gProgTitle = "" : gProgDesc = "" : gProgTags = ""
    Erase gWLine, gWText
    For c = 0 To 25
        gDefType(c) = ""
    Next
End Sub

Function BaseName(ByRef p As String) As String
    Dim i As Integer, s As String
    s = p
    For i = Len(s) To 1 Step -1
        If Mid(s, i, 1) = "/" Or Mid(s, i, 1) = "\" Then
            s = Mid(s, i + 1) : Exit For
        End If
    Next
    BaseName = s
End Function

Function StripExt(ByRef p As String) As String
    Dim i As Integer
    For i = Len(p) To 1 Step -1
        If Mid(p, i, 1) = "." Then
            StripExt = Left(p, i - 1) : Exit Function
        End If
        If Mid(p, i, 1) = "/" Or Mid(p, i, 1) = "\" Then Exit For
    Next
    StripExt = p
End Function

Function ProcessFile(ByRef fname As String) As Integer
    Dim r As Integer, outBase As String, sep As String

    ResetState
    gFile = BaseName(fname)
    r = LoadSource(fname)
    If r = -1 Then
        Print Tr1("Error: cannot open %1", fname)
        ProcessFile = 1 : Exit Function
    ElseIf r = -2 Then
        Print Tr1("Error: %1 is a tokenized file.", fname)
        Print Tr1("       Save it on the MSX as ASCII: %1", "SAVE " & Chr(34) & UCase(gFile) & Chr(34) & ",A")
        ProcessFile = 1 : Exit Function
    End If

    TokenizeAll
    AnalyseAll
    ResolveEdges
    ResolveVars
    BuildEntries
    ComputeMembership
    ComputeCalls
    ComputeReach
    CollectDocs
    ComputeWarnings

    If Len(gOutDir) > 0 Then
        sep = "/"
        If Right(gOutDir, 1) = "/" Or Right(gOutDir, 1) = "\" Then sep = ""
        outBase = gOutDir & sep & StripExt(gFile)
    Else
        outBase = StripExt(fname)
    End If

    WriteHtml outBase & ".html"
    If gOptDot Then WriteDot outBase & ".dot"

    If gOptQuiet = 0 Then
        Print gFile & ": " & Tr3("%1 lines, %2 routines, %3 variables", NStr(gNL), NStr(IIf(gNEn > 0, gNEn - 1, 0)), NStr(gNV)) & _
            ", " & Tr1("%1 warnings", NStr(gNW)) & " -> " & outBase & ".html"
    End If
    ProcessFile = 0
End Function

'' --- start ---
Dim i As Integer, a As String, nFiles As Integer, errs As Integer
Dim files(0 To 255) As String

LangEarly
InitKeywords
i = 1
Do
    a = Command(i)
    If Len(a) = 0 Then Exit Do
    Select Case LCase(a)
    Case "-h", "--help", "/?"
        Usage : End 0
    Case "-dot"
        gOptDot = 1
    Case "-q"
        gOptQuiet = 1
    Case "-l", "--lang"
        i += 1     '' al verwerkt door LangEarly
    Case "-o"
        i += 1 : gOutDir = Command(i)
    Case Else
        If nFiles <= 255 Then
            files(nFiles) = a : nFiles += 1
        End If
    End Select
    i += 1
Loop

If nFiles = 0 Then
    Usage : End 1
End If

For i = 0 To nFiles - 1
    errs += ProcessFile(files(i))
Next
If errs > 0 Then End 1
End 0
