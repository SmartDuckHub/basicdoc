'' =====================================================================
''  fbdoc - Bestanden zoeken en #include verwerken
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
                If opt.debugOn Then Say "  [dbg] include not found: " & incWhat(i)
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
        Say "  [dbg] folder " & dirPath & " : " & Str(n) & " entries"
    End If

    For i = 1 To n
        full = dirPath & PSEP & names(i)
        If IsExcluded(full) Then
            If opt.debugOn Then Say "  [dbg]   excluded: " & names(i)
        ElseIf isDir(i) Then
            If opt.debugOn Then Say "  [dbg]   <DIR> " & names(i)
            If opt.recurse Then ScanDirRec(full)
        ElseIf ExtWanted(names(i)) = 0 Then
            If opt.debugOn Then Say "  [dbg]   extension not wanted: " & names(i) & " (" & PathExtOf(names(i)) & ") attr=&h" & Hex(attrs(i))
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
