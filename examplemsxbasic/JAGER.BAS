10 '## Ruimtejager - demoprogramma voor msxbasicdoc
20 ' Klein spelletje om subroutines, events en
30 ' foutafhandeling te laten zien.
40 '@auteur Marcel
50 '@versie 0.1
60 DEFINT A-Z
70 SCREEN 1:COLOR 15,1,1:KEY OFF
80 ON ERROR GOTO 9000
90 DEF FNR(X)=INT(RND(-TIME)*X)+1
100 GOSUB 1000
110 ON INTERVAL=50 GOSUB 5000:INTERVAL ON
120 ON STRIG GOSUB 6000:STRIG(0) ON
130 '--- hoofdlus ---
140 S=STICK(0):IF S=0 THEN 140
150 ON S GOSUB 2000,2000,2100,2100,2200,2200,2300,2300
160 IF PUNTEN>=100 THEN 300 ELSE 140
300 GOSUB 3000
310 IF A$="J" THEN RUN ELSE END
990 '
1000 '## Init - zet het speelveld klaar
1010 '@uit X,Y startpositie; PUNTEN=0
1020 CLS:X=15:Y=10:PUNTEN=0:LEVEN=3
1030 RESTORE 8000:FOR I=0 TO 7:READ D:VPOKE BASE(7)+I,D:NEXT I
1040 GOSUB 4000
1050 RETURN
1990 '
2000 ' Beweeg omhoog
2010 IF Y>0 THEN Y=Y-1
2020 GOTO 2400
2100 ' Beweeg rechts
2110 IF X<31 THEN X=X+1
2120 GOTO 2400
2200 ' Beweeg omlaag
2210 IF Y<22 THEN Y=Y+1
2220 GOTO 2400
2300 ' Beweeg links
2310 IF X>0 THEN X=X-1
2400 ' gezamenlijk: speler opnieuw tekenen
2410 GOSUB 4000:RETURN
2990 '
3000 '## Einde - toon score en vraag om opnieuw
3010 LOCATE 5,10:PRINT "Score:";PUNT
3020 LOCATE 5,12:INPUT "Nog een keer (J/N)";A$
3030 RETURN
3990 '
4000 '## Teken - speler op X,Y zetten
4010 LOCATE X,Y:PRINT CHR$(128);
4020 RETURN
4990 '
5000 '## Tik - interval-handler, telt punten
5010 PUNTEN=PUNTEN+1
5020 IF PUNTEN MOD 10=0 THEN BEEP
5030 RETURN
5990 '
6000 '## Vuur - spatiebalk ingedrukt
6010 _TURBO ON
6020 E=FNR(6):PUNTEN=PUNTEN+E
6030 RETURN
6040 PRINT "Deze regel wordt nooit bereikt"
6050 GOTO 7777
6990 '
8000 DATA 24,60,126,219,255,36,90,165
8990 '
9000 '## Fout - foutafhandeling
9010 PRINT "Fout";ERR;"in regel";ERL
9020 IF ERR=5 THEN RESUME NEXT
9030 RESUME 140
