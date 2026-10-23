'' =====================================================================
''  fbdoc - Datastructuren
'' =====================================================================

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
