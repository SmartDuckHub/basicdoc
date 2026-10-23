'' ============================================================
'' msxbasicdoc - documentatiegenerator voor MSX-BASIC
''
'' Brengt de structuur van een (ASCII-opgeslagen) MSX-BASIC programma
'' in kaart door GOTO/GOSUB/RETURN en verwante sprongen te volgen.
''
'' Compileren:  fbc -lang fblite msxbasicdoc.bas
'' Gebruik:     msxbasicdoc [opties] PROGRAMMA.BAS [...]
'' ============================================================

#include once "inc/mbd_globals.bi"
#include once "inc/mbd_util.bi"
#include once "inc/mbd_lexer.bi"
#include once "inc/mbd_load.bi"
#include once "inc/mbd_analyse.bi"
#include once "inc/mbd_flow.bi"
#include once "inc/mbd_html.bi"
#include once "inc/mbd_svg.bi"

Sub Usage()
    Print "msxbasicdoc " & MBD_VERSION & " - documentatie voor MSX-BASIC programma's"
    Print
    Print "Gebruik: msxbasicdoc [opties] PROGRAMMA.BAS [...]"
    Print
    Print "Opties:"
    Print "  -o MAP     uitvoer in MAP (standaard: naast het bronbestand)"
    Print "  -dot       ook een Graphviz .dot-bestand van de aanroepgraaf maken"
    Print "  -q         stil: alleen fouten tonen"
    Print "  -h         deze hulp"
    Print
    Print "Invoer moet ASCII zijn (op de MSX: SAVE ""NAAM.BAS"",A)."
    Print
    Print "Documentatieconventies in commentaar:"
    Print "  '## Naam - omschrijving   naam van routine (of programma, bovenaan)"
    Print "  '@tag waarde              vrije tags, bijv. '@in X,Y  '@uit A$"
    Print "  ' gewone tekst            omschrijving"
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
        Print "Fout: kan " & fname & " niet openen"
        ProcessFile = 1 : Exit Function
    ElseIf r = -2 Then
        Print "Fout: " & fname & " is een getokeniseerd bestand."
        Print "      Sla het op de MSX op als ASCII: SAVE """ & UCase(gFile) & """,A"
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
        Print gFile & ": " & NStr(gNL) & " regels, " & NStr(IIf(gNEn > 0, gNEn - 1, 0)) & " routines, " & _
            NStr(gNV) & " variabelen, " & NStr(gNW) & " waarschuwingen -> " & outBase & ".html"
    End If
    ProcessFile = 0
End Function

'' --- start ---
Dim i As Integer, a As String, nFiles As Integer, errs As Integer
Dim files(0 To 255) As String

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
