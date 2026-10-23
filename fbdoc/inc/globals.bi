'' =====================================================================
''  fbdoc - Globale opslag
'' =====================================================================

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
