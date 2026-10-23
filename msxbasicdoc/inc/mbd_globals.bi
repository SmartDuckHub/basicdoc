'' ============================================================
'' msxbasicdoc - globale constanten en gedeelde data
'' ============================================================

#define MBD_VERSION "0.4.0"

'' --- Tokensoorten ---
Const TK_KW = 1      '' sleutelwoord (genormaliseerd, hoofdletters)
Const TK_ID = 2      '' variabele / naam (hoofdletters, incl. type-suffix)
Const TK_NUM = 3     '' getal
Const TK_STR = 4     '' string-literal incl. aanhalingstekens
Const TK_OP = 5      '' operator / leesteken
Const TK_SEP = 6     '' ':' statementscheiding
Const TK_REM = 7     '' commentaar (REM of ')
Const TK_DATA = 8    '' ruwe DATA-inhoud
Const TK_CALL = 9    '' naam na CALL / _

'' --- Soorten verwijzingen (edges) ---
Const ED_GOTO = 1
Const ED_GOSUB = 2
Const ED_THEN = 3        '' IF ... THEN 100
Const ED_ELSE = 4        '' ... ELSE 200
Const ED_ONGOTO = 5
Const ED_ONGOSUB = 6
Const ED_RETURNTO = 7    '' RETURN 100
Const ED_RESUME = 8      '' RESUME 100
Const ED_RUN = 9         '' RUN 100
Const ED_ONERROR = 10    '' ON ERROR GOTO 100
Const ED_ONEVENT = 11    '' ON INTERVAL/KEY/SPRITE/STRIG/STOP GOSUB
Const ED_RESTORE = 12    '' RESTORE 100 (data, geen flow)

'' --- Soorten ingangen (routines) ---
Const EN_MAIN = 0
Const EN_GOSUB = 1
Const EN_EVENT = 2
Const EN_ERROR = 3

'' --- Opties ---
Dim Shared gOptDot As Integer
Dim Shared gOptQuiet As Integer
Dim Shared gOutDir As String

'' --- Bronregels ---
Dim Shared gFile As String
Dim Shared gNL As Integer
Dim Shared gLnNum() As Long
Dim Shared gLnText() As String
Dim Shared gLnTk1() As Integer, gLnTkN() As Integer
Dim Shared gLnEd1() As Integer, gLnEdN() As Integer
Dim Shared gLnFalls() As Integer     '' loopt door naar volgende regel
Dim Shared gLnRet() As Integer       '' bevat RETURN
Dim Shared gLnEnd() As Integer       '' bevat END/STOP
Dim Shared gLnRem() As Integer       '' alleen commentaar
Dim Shared gLnData() As Integer      '' begint met DATA
Dim Shared gLnTarget() As Integer    '' is doel van een sprong/aanroep
Dim Shared gLnOwners() As Integer    '' aantal routines waartoe regel hoort
Dim Shared gLnEntry() As Integer     '' ingang die op deze regel begint, of -1

'' --- Tokens ---
Dim Shared gNT As Integer
Dim Shared gTkType() As Integer
Dim Shared gTkText() As String
Dim Shared gTkVal() As Long          '' regelnummerwaarde, of -1

'' --- Verwijzingen ---
Dim Shared gNE As Integer
Dim Shared gEdFrom() As Integer      '' regelindex van bron
Dim Shared gEdKind() As Integer
Dim Shared gEdNum() As Long          '' doelregelnummer
Dim Shared gEdTo() As Integer        '' doelregelindex of -1
Dim Shared gEdInfo() As String       '' bijv. "INTERVAL"

'' --- Externe verwijzingen (CALL, RUN "x", LOAD, BLOAD, DEF USR) ---
Dim Shared gNX As Integer
Dim Shared gExLine() As Integer
Dim Shared gExKind() As String
Dim Shared gExName() As String

'' --- Variabelengebruik ---
Dim Shared gNU As Integer
Dim Shared gUsLine() As Integer
Dim Shared gUsName() As String
Dim Shared gUsArr() As Integer
Dim Shared gUsMode() As Integer      '' 0 = lezen, 1 = schrijven, 2 = DIM
Dim Shared gUsVar() As Integer

'' --- Variabelen (na resolutie) ---
Dim Shared gNV As Integer
Dim Shared gVarKey() As String
Dim Shared gVarNames() As String     '' "|SCORE|SC|"
Dim Shared gVarType() As String
Dim Shared gVarArr() As Integer
Dim Shared gDefType(0 To 25) As String

'' --- DEF FN ---
Dim Shared gNF As Integer
Dim Shared gFnName() As String
Dim Shared gFnLine() As Integer
Dim Shared gNFU As Integer
Dim Shared gFuName() As String
Dim Shared gFuLine() As Integer

'' --- Ingangen / routines ---
Dim Shared gNEn As Integer
Dim Shared gEnLine() As Integer
Dim Shared gEnKind() As Integer
Dim Shared gEnInfo() As String
Dim Shared gEnName() As String
Dim Shared gEnDesc() As String
Dim Shared gEnTags() As String       '' "tag" TAB "waarde" LF ...
Dim Shared gEnDocd() As Integer      '' heeft echt broncommentaar
Dim Shared gEnReach() As Integer     '' bereikbaar vanuit hoofdprogramma (via aanroepen)
Dim Shared gEnHasCaller() As Integer '' heeft een aanroeper binnen bereikbare code
Dim Shared gMem() As UByte           '' lidmaatschap: e * gNL + regel
Dim Shared gCall() As UByte          '' 1 = GOSUB, 2 = registreert handler

'' --- Programma-kop ---
Dim Shared gProgTitle As String
Dim Shared gProgDesc As String
Dim Shared gProgTags As String

'' --- Waarschuwingen ---
Dim Shared gNW As Integer
Dim Shared gWLine() As Integer
Dim Shared gWText() As String

'' --- Sleutelwoorden ---
Dim Shared gNKw As Integer
Dim Shared gKw() As String
Dim Shared gKwFirst(0 To 25) As Integer
Dim Shared gKwLast(0 To 25) As Integer

'' --- Uitvoer ---
Dim Shared gOut As Integer
Dim Shared gTreeShown() As Integer
Dim Shared gTreeOnPath() As Integer
