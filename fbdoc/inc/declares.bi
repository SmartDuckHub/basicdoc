'' =====================================================================
''  fbdoc - Declaraties van alle procedures
'' =====================================================================

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
