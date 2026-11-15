@echo off
setlocal EnableDelayedExpansion
rem ------------------------------------------------------------------
rem  julklappar.bat - bestammer vem som ger julklapp till vem.
rem
rem  Anvandning:
rem    julklappar.bat      kor programmet (t.ex. genom att dubbelklicka)
rem    julklappar.bat T    kor det inbyggda testet (5-15 deltagare)
rem
rem  Allt finns i den har filen. Listan och tidigare ars cykler sparas
rem  som rader sist i filen (#LISTA, #AR, #PLAN). Nya rader laggs bara
rem  till i slutet; den senaste raden av varje slag galler.
rem
rem  Programmet:
rem    1. fragar vilket ar det galler (foreslar aret efter det senaste)
rem    2. visar listan, och forra arets cykel om den finns
rem    3. fragar om nagot namn ska tas bort eller laggas till
rem    4. skriver ut arets cykel och sparar den sist i filen
rem
rem  Varje namn ger till nasta, och det sista ger till det forsta.
rem
rem  Hur paren valjs
rem  ---------------
rem  En "plan" ar P cykler som aldrig anvander samma par (Waleckis
rem  konstruktion). Udda antal deltagare N: P = N-1, vilket ar maximum.
rem  Jamnt N: P = N-2. Med oforandrad lista anvands planen ett ar i
rem  taget och borjar sedan om, sa ett par aterkommer forst efter P ar.
rem
rem  Nar listan andras gors en ny plan. Programmet provar ett antal
rem  slumpade satt att placera namnen i planen och valjer det som haller
rem  par fran tidigare ar borta langst. Det ar "tillrackligt bra", inte
rem  bevisat bast.
rem ------------------------------------------------------------------

set "SJALV=%~f0"
set /a KANDIDATER=60
if /i "%~1"=="T" goto :test
if /i "%~1"=="/T" goto :test

call :lasdata

rem Foresla aret efter det senaste sparade, annars innevarande ar
set /a FORSLAG=0
for %%y in (!HAR!) do if %%y GTR !FORSLAG! set /a FORSLAG=%%y
if %FORSLAG% GTR 0 (
    set /a FORSLAG+=1
) else (
    call :iar FORSLAG
)
set "AR="
set /p "AR=Vilket ar galler det? [%FORSLAG%]: "
if "%AR%"=="" set "AR=%FORSLAG%"
set "ICKESIFFROR="
for /f "delims=0123456789" %%x in ("%AR%") do set "ICKESIFFROR=%%x"
if defined ICKESIFFROR (
    echo Ogiltigt artal: "%AR%"
    goto :fel
)
for /f "tokens=* delims=0" %%x in ("%AR%") do set "AR=%%x"
if "%AR%"=="" set "AR=0"
if %AR% GTR 99999 (
    echo Ogiltigt artal: "%AR%"
    goto :fel
)

set "ANDRAD="
call :redigera
if %N% LSS 3 (
    echo Listan maste innehalla minst tre namn.
    goto :fel
)

call :berakna

echo.
echo Cykel for %AR%:
echo.
set /a NM1=N-1
for /l %%i in (0,1,%NM1%) do (
    set /a "j=(%%i+1) %% N"
    for %%j in (!j!) do echo   !ut[%%i]! -^> !ut[%%j]!
)
echo.
call :info

rem Spara: lagg till rader sist i filen
set "RAD="
for /l %%i in (0,1,%NM1%) do set "RAD=!RAD!|!ut[%%i]!"
if defined ANDRAD (
    set "LRAD="
    for /l %%i in (0,1,%NM1%) do set "LRAD=!LRAD!|!namn[%%i]!"
    >>"%SJALV%" echo(#LISTA;!LRAD:~1!
)
if defined NYPLAN >>"%SJALV%" echo(#PLAN %PLANSTART%;!PLANRAD!
>>"%SJALV%" echo(#AR %AR%;!RAD:~1!
echo Arets cykel ar sparad i julklappar.bat.
echo.
pause
endlocal
exit /b 0

:fel
pause
endlocal
exit /b 1

rem ==================================================================
rem  :lasdata - laser raderna sist i filen.
rem  Ger namn[0..N-1], N, HAR (lista med ar), AR_<ar> (cykel med |),
rem  PLANSTART och PLANRAD ("namn|namn...;ordning,ordning...").
rem ==================================================================
:lasdata
set "LISTRAD="
set "HAR="
set "PLANRAD="
set "PLANSTART="
for /f "usebackq tokens=1,* delims=;" %%a in (`findstr /b "#" "%SJALV%"`) do (
    if "%%a"=="#LISTA" set "LISTRAD=%%b"
    for /f "tokens=1,2" %%x in ("%%a") do (
        if "%%x"=="#AR" (
            if not defined AR_%%y set "HAR=!HAR! %%y"
            set "AR_%%y=%%b"
        )
        if "%%x"=="#PLAN" (
            set "PLANSTART=%%y"
            set "PLANRAD=%%b"
        )
    )
)
set /a N=0
if defined LISTRAD (
    set "LISTRAD=!LISTRAD:|=" "!"
    for %%x in ("!LISTRAD!") do (
        set "namn[!N!]=%%~x"
        set /a N+=1
    )
)
exit /b 0

rem :iar variabel - satter variabeln till innevarande ar (ur %date%)
:iar
set "D=%date%"
set "D=!D:/= !"
set "D=!D:-= !"
set "D=!D:.= !"
set /a "%~1=2026"
for %%a in (!D!) do (
    set /a "x=0"
    set /a "x=%%a" 2>nul
    if !x! GEQ 1900 if !x! LEQ 2999 set /a "%~1=x"
)
exit /b 0

rem ==================================================================
rem  :berakna - raknar fram arets cykel.
rem  In:  namn[0..N-1], N, AR, HAR/AR_<ar>, PLANSTART, PLANRAD
rem  Ut:  ut[0..N-1], P, NYPLAN, BEST (minsta avstand i ny plan),
rem       MINST (minsta avstand for arets par), PLANSTART, PLANRAD
rem ==================================================================
:berakna
set /a NM1=N-1
for /l %%i in (0,1,%NM1%) do set "idx_!namn[%%i]!=%%i"

rem --- L_a_b = senaste ar (fore AR) som namn a gav till namn b -------
for /f "delims==" %%v in ('set L_ 2^>nul') do set "%%v="
for %%y in (!HAR!) do if %%y LSS %AR% (
    set "C=!AR_%%y!"
    set "C=!C:|=" "!"
    set "FORSTA="
    set "FORSTAKLAR="
    set "FOREG="
    for %%x in ("!C!") do (
        set "I="
        if defined idx_%%~x set "I=!idx_%%~x!"
        if defined FOREG if defined I (
            set /a "cur=L_!FOREG!_!I!"
            if !cur! LSS %%y set /a "L_!FOREG!_!I!=%%y"
        )
        if not defined FORSTAKLAR (
            set "FORSTA=!I!"
            set "FORSTAKLAR=1"
        )
        set "FOREG=!I!"
    )
    if defined FOREG if defined FORSTA (
        set /a "cur=L_!FOREG!_!FORSTA!"
        if !cur! LSS %%y set /a "L_!FOREG!_!FORSTA!=%%y"
    )
)

rem --- Waleckis cykler for N deltagare: cyc_t_i och cyn_t_i (nasta) -
call :walecki

rem --- Galler den sparade planen? ------------------------------------
set "NYPLAN=1"
if defined PLANRAD if !PLANSTART! LEQ %AR% (
    for /f "tokens=1,2 delims=;" %%p in ("!PLANRAD!") do (
        set "PN=%%p"
        set "PO=%%q"
    )
    set "PN=!PN:|=" "!"
    set /a K=0
    set "OK=1"
    for %%x in ("!PN!") do (
        set "pv[!K!]=%%~x"
        if not defined idx_%%~x set "OK="
        set /a K+=1
    )
    if not !K!==%N% set "OK="
    set /a K=0
    for %%o in (!PO!) do (
        set "ord[!K!]=%%o"
        set /a K+=1
    )
    if not !K!==%P% set "OK="
    if defined OK set "NYPLAN="
)

if defined NYPLAN call :nyplan

rem --- Arets cykel -----------------------------------------------------
set /a "T=(AR - PLANSTART) %% P"
for %%t in (!ord[%T%]!) do (
    for /l %%i in (0,1,%NM1%) do for %%v in (!cyc_%%t_%%i!) do set "ut[%%i]=!pv[%%v]!"
)
set /a MINST=99999
for /l %%i in (0,1,%NM1%) do (
    set /a "j=(%%i+1) %% N"
    for %%j in (!j!) do for %%x in ("!ut[%%i]!") do for %%z in ("!ut[%%j]!") do (
        set "a=!idx_%%~x!" & set "b=!idx_%%~z!"
    )
    for %%a in (!a!) do for %%b in (!b!) do if defined L_%%a_%%b (
        set /a "g=AR - L_%%a_%%b"
        if !g! LSS !MINST! set /a MINST=g
    )
)
for /l %%i in (0,1,%NM1%) do set "idx_!namn[%%i]!="
exit /b 0

rem ==================================================================
rem  :nyplan - valjer hur namnen placeras i Waleckis cykler (q) och i
rem  vilken ordning cyklerna anvands (ord), sa att par fran tidigare ar
rem  haller sig borta sa lange som mojligt.
rem ==================================================================
:nyplan
set /a PM1=P-1
set "HIST="
for /f "delims==" %%v in ('set L_ 2^>nul') do set "HIST=1"
set /a BEST=-1
set /a KAND=0
for /l %%i in (0,1,%NM1%) do set /a "bq%%i=%%i"
for /l %%t in (0,1,%PM1%) do set /a "bord%%t=%%t"
if not defined HIST (
    set /a BEST=0
    goto :nyplan_klar
)

:nyplan_kandidat
set /a KAND+=1
rem Slumpad placering q0..q(N-1) (Fisher-Yates)
for /l %%i in (0,1,%NM1%) do set /a "q%%i=%%i"
for /l %%i in (%NM1%,-1,1) do (
    set /a "j=!random! %% (%%i+1)"
    for %%j in (!j!) do (
        set /a "tmp=q%%i"
        set /a "q%%i=q%%j"
        set /a "q%%j=tmp"
    )
)
rem s_t = minsta tid sedan nagot par i cykel t senast anvandes
for /l %%t in (0,1,%PM1%) do (
    set /a s=99999
    for /l %%i in (0,1,%NM1%) do (
        set /a "a=q!cyc_%%t_%%i!, b=q!cyn_%%t_%%i!"
        set /a "g=AR - L_!a!_!b!"
        if !g! LSS !s! set /a s=g
    )
    set /a "s%%t=s"
    set "anv%%t="
)
rem Cykler med langst tid sedan anvandning forst; poang = min(k + s)
set /a POANG=99999
for /l %%k in (0,1,%PM1%) do (
    set /a MAXS=-1
    set /a MAXT=0
    for /l %%t in (0,1,%PM1%) do if not defined anv%%t if !s%%t! GTR !MAXS! (
        set /a MAXS=s%%t
        set /a MAXT=%%t
    )
    for %%m in (!MAXT!) do set "anv%%m=1"
    set /a "o%%k=MAXT"
    set /a "v=%%k + MAXS"
    if !v! LSS !POANG! set /a POANG=v
)
if %POANG% GTR %P% set /a POANG=P
if %POANG% GTR %BEST% (
    set /a BEST=POANG
    for /l %%i in (0,1,%NM1%) do set /a "bq%%i=q%%i"
    for /l %%k in (0,1,%PM1%) do set /a "bord%%k=o%%k"
)
if %BEST% GEQ %P% goto :nyplan_klar
if %KAND% LSS %KANDIDATER% goto :nyplan_kandidat

:nyplan_klar
set "PN="
for /l %%v in (0,1,%NM1%) do for %%q in (!bq%%v!) do (
    set "pv[%%v]=!namn[%%q]!"
    set "PN=!PN!|!namn[%%q]!"
)
set "PO="
for /l %%k in (0,1,%PM1%) do (
    set "ord[%%k]=!bord%%k!"
    set "PO=!PO!,!bord%%k!"
)
set "PLANSTART=%AR%"
set "PLANRAD=!PN:~1!;!PO:~1!"
exit /b 0

rem ==================================================================
rem  :walecki - bygger P cykler for N noder (0..N-1) som aldrig delar
rem  par. Udda N: noden N-1 ar navet, sicksack z(i) = K+f(i) mod N-1
rem  framlanges och baklanges. Jamnt N: samma for N-1 noder, och nod
rem  N-1 stoppas in mellan z(m-1) och z(m).
rem ==================================================================
:walecki
set /a "UDDA=N %% 2"
if %UDDA%==1 (
    set /a "TVAM=N-1, P=N-1, INF=N-1, X=-1"
) else (
    set /a "TVAM=N-2, P=N-2, INF=N-2, X=N-1"
)
set /a "M=TVAM/2, MM1=M-1, SISTAZ=TVAM-1, PM1=P-1"
for /l %%i in (0,1,%SISTAZ%) do (
    set /a "r=%%i %% 2"
    if %%i==0 (set /a "f%%i=0") else if !r!==1 (set /a "f%%i=(%%i+1)/2") else (set /a "f%%i=-(%%i/2)")
)
for /l %%t in (0,1,%PM1%) do (
    if %%t LSS %M% (set /a "K=%%t" & set "RIKT=fram") else (set /a "K=%%t-M" & set "RIKT=bak")
    set "cyc_%%t_0=%INF%"
    set /a POS=1
    for /l %%s in (0,1,%SISTAZ%) do (
        if "!RIKT!"=="fram" (set /a "i=%%s") else (set /a "i=SISTAZ-%%s")
        for %%i in (!i!) do set /a "cyc_%%t_!POS!=(K + f%%i + TVAM) %% TVAM"
        set /a POS+=1
        if %X% GEQ 0 (
            set "INS="
            if "!RIKT!"=="fram" if !i!==%MM1% set "INS=1"
            if "!RIKT!"=="bak" if !i!==%M% set "INS=1"
            if defined INS (
                set "cyc_%%t_!POS!=%X%"
                set /a POS+=1
            )
        )
    )
    for /l %%i in (0,1,%NM1%) do (
        set /a "j=(%%i+1) %% N"
        for %%j in (!j!) do set "cyn_%%t_%%i=!cyc_%%t_%%j!"
    )
)
exit /b 0

rem :info - skriver ut hur lange sedan arets par forekom
:info
if defined NYPLAN if !BEST! GTR 0 echo Listan har andrats, sa en ny plan ar gjord. Under dess forsta %P% ar upprepas inget par inom %BEST% ar.
if %MINST%==99999 (
    echo Inget av arets par har forekommit tidigare.
) else (
    echo Arets par forekom senast for %MINST% ar sedan eller tidigare.
)
echo Med oforandrad lista aterkommer samma par tidigast efter %P% ar.
exit /b 0

rem ==================================================================
rem  :redigera - visar listan och later anvandaren andra den.
rem ==================================================================
:redigera
set /a FORRA=AR-1
echo.
echo Listan:
call :visalista
if defined AR_%FORRA% (
    echo.
    echo Sa har gick julklapparna %FORRA%:
    set "C=!AR_%FORRA%!"
    set "C=!C:|=" "!"
    set "FORSTA="
    set "FOREG="
    for %%x in ("!C!") do (
        if defined FOREG (echo   !FOREG! -^> %%~x) else (set "FORSTA=%%~x")
        set "FOREG=%%~x"
    )
    echo   !FOREG! -^> !FORSTA!
)
echo.

:redigera_fraga
set "SVAR="
set /p "SVAR=Vill du gora nagra andringar i listan? (J/N): "
if /i "!SVAR!"=="N" exit /b 0
if /i not "!SVAR!"=="J" goto :redigera_fraga

:redigera_meny
echo.
echo   1 = Ta bort ett namn
echo   2 = Lagg till ett namn
echo   3 = Klar
set "VAL="
set /p "VAL=Val: "
if "!VAL!"=="1" goto :redigera_tabort
if "!VAL!"=="2" goto :redigera_lagg
if "!VAL!"=="3" goto :redigera_klar
goto :redigera_meny

:redigera_tabort
echo.
call :visalista
set "SVAR="
set /p "SVAR=Nummer eller namn att ta bort (Enter = avbryt): "
if "!SVAR!"=="" goto :redigera_meny
set /a IDX=-1
for /l %%i in (1,1,%N%) do if "!SVAR!"=="%%i" set /a IDX=%%i-1
set /a SISTA=N-1
if !IDX! LSS 0 for /l %%i in (0,1,!SISTA!) do if /i "!SVAR!"=="!namn[%%i]!" set /a IDX=%%i
if !IDX! LSS 0 (
    echo Hittade inget namn som matchar "!SVAR!".
    goto :redigera_tabort
)
for %%i in (!IDX!) do set "BORT=!namn[%%i]!"
set /a SISTA=N-2
for /l %%i in (!IDX!,1,!SISTA!) do (
    set /a "nasta=%%i+1"
    for %%n in (!nasta!) do set "namn[%%i]=!namn[%%n]!"
)
set /a N-=1
set "namn[!N!]="
set "ANDRAD=1"
echo !BORT! ar borttagen.
goto :redigera_meny

:redigera_lagg
echo.
set "NYTT="
set /p "NYTT=Namn att lagga till (Enter = avbryt): "
if "!NYTT!"=="" goto :redigera_meny
set "KONTROLL=!NYTT:"=!"
set "KONTROLL=!KONTROLL:|=!"
set "KONTROLL=!KONTROLL:;=!"
set "KONTROLL=!KONTROLL: =!"
if not "!KONTROLL!"=="!NYTT!" (
    echo Namnet far inte innehalla mellanslag, citattecken, ^| eller ;.
    goto :redigera_lagg
)
set "FINNS="
set /a SISTA=N-1
for /l %%i in (0,1,!SISTA!) do if /i "!NYTT!"=="!namn[%%i]!" set "FINNS=1"
if defined FINNS (
    echo !NYTT! finns redan i listan.
    goto :redigera_lagg
)
set "namn[!N!]=!NYTT!"
set /a N+=1
call :sortera
set "ANDRAD=1"
echo !NYTT! ar tillagd.
goto :redigera_meny

:redigera_klar
echo.
echo Arets lista:
call :visalista
exit /b 0

:visalista
set /a SISTA=N-1
for /l %%i in (0,1,%SISTA%) do (
    set /a "nr=%%i+1"
    echo   !nr!. !namn[%%i]!
)
exit /b 0

rem Sorterar namn[0..N-1] i omvand bokstavsordning
:sortera
set /a SISTA=N-2
for /l %%a in (0,1,%SISTA%) do (
    for /l %%i in (0,1,%SISTA%) do (
        set /a "nasta=%%i+1"
        for %%n in (!nasta!) do (
            if /i "!namn[%%i]!" LSS "!namn[%%n]!" (
                set "tmp=!namn[%%i]!"
                set "namn[%%i]=!namn[%%n]!"
                set "namn[%%n]=!tmp!"
            )
        )
    )
)
exit /b 0

rem ==================================================================
rem  :test - simulerar ar utan att rora filen.
rem    1. Oforandrad lista, 5-15 deltagare: varje ar en giltig cykel och
rem       inget par upprepas inom P ar (N-1 for udda N, N-2 for jamnt).
rem    2. Deltagare laggs till och tas bort: giltiga cykler, utlovat
rem       avstand till tidigare ar halls, och P ar inom varje plan.
rem ==================================================================
:test
set /a TESTFEL=0
echo 1. Oforandrad lista:
for /l %%n in (5,1,15) do call :test_fast %%n
echo.
echo 2. Deltagare laggs till och tas bort:
setlocal
set "HAR="
set "PLANRAD="
set "PLANSTART="
call :test_steg 2020 2030 "Theo Stefan Pia Mona Linus Josa Ella Birgit Alice"
call :test_steg 2031 2040 "Theo Stefan Pia Mona Linus Josa Ella Birgit"
call :test_steg 2041 2052 "Theo Stefan Pia Mona Linus Josa Ella Birgit Anna Bo"
call :test_steg 2053 2063 "Theo Stefan Mona Linus Ella Birgit Anna Bo Cia"
call :test_steg 2064 2072 "Theo Stefan Mona Linus Ella"
call :test_steg 2073 2085 "Theo Stefan Mona Linus Ella Anna Bo Cia Dan Eva Fia Gun Hans"
endlocal & set /a TESTFEL=%TESTFEL%
echo.
if %TESTFEL%==0 (echo ALLA TESTER GODKANDA) else (echo %TESTFEL% FEL HITTADES)
endlocal & exit /b %TESTFEL%

:test_fast
setlocal
set "HAR="
set "PLANRAD="
set "PLANSTART="
set /a N=%1
for /l %%i in (1,1,%1) do (
    set /a k=%%i-1
    set "namn[!k!]=N%%i"
)
set /a "UDDA=N %% 2"
if %UDDA%==1 (set /a "PF=N-1") else (set /a "PF=N-2")
set /a "SLUT=2020 + PF + 2"
set /a FORE=TESTFEL
call :test_ar 2020 %SLUT%
if !INRE! LSS %PF% call :test_fel "N=%N%: par upprepades efter !INRE! ar, forvantat %PF%"
if %FORE%==%TESTFEL% (set "S=OK ") else (set "S=FEL")
echo   %S%  N=%N%: upprepning tidigast efter !INRE! ar
endlocal & set /a TESTFEL=%TESTFEL%
exit /b 0

:test_steg
set /a N=0
for %%x in (%~3) do (
    set "namn[!N!]=%%x"
    set /a N+=1
)
set /a FORE=TESTFEL
call :test_ar %1 %2
if !INRE! LSS %FORSTAP% call :test_fel "N=%N%: par inom planen upprepades efter !INRE! ar, forvantat %FORSTAP%"
if defined FORSTABEST if !KORS! LSS !FORSTABEST! call :test_fel "N=%N%: par fran tidigare ar upprepades efter !KORS! ar, utlovat %FORSTABEST%"
set "KT=inga par fran tidigare ar"
if !KORS! LSS 99999 set "KT=par fran tidigare ar tidigast efter !KORS! ar (utlovat %FORSTABEST%, planens period %FORSTAP%)"
if %FORE%==%TESTFEL% (set "S=OK ") else (set "S=FEL")
echo   %S%  N=%N% ar %1-%2: %KT%, inom planen efter !INRE! ar
exit /b 0

rem :test_ar fran till - kor ar i foljd, sparar i minnet och kontrollerar
rem cyklerna. Ger INRE (minsta avstand inom intervallet) och KORS
rem (minsta avstand till ar fore intervallet).
:test_ar
set /a INRE=99999, KORS=99999
set "FORSTABEST="
set "FORSTAP="
for /l %%y in (%1,1,%2) do (
    set /a AR=%%y
    call :berakna
    if not defined FORSTAP (
        set /a FORSTAP=P
        if defined NYPLAN if !BEST! GTR 0 set /a FORSTABEST=BEST
    )
    set "RAD="
    set /a NM1=N-1
    for /l %%i in (0,1,!NM1!) do (
        set "RAD=!RAD!|!ut[%%i]!"
        set "giv_!ut[%%i]!="
    )
    if not defined AR_%%y set "HAR=!HAR! %%y"
    set "AR_%%y=!RAD:~1!"
    rem Alla namn exakt en gang i cykeln
    for /l %%i in (0,1,!NM1!) do (
        if defined giv_!ut[%%i]! call :test_fel "ar %%y: !ut[%%i]! forekommer flera ganger"
        set "giv_!ut[%%i]!=1"
    )
    for /l %%i in (0,1,!NM1!) do if not defined giv_!namn[%%i]! call :test_fel "ar %%y: !namn[%%i]! saknas"
    rem Avstand sedan paret senast forekom
    for /l %%i in (0,1,!NM1!) do (
        set /a "j=(%%i+1) %% N"
        for %%j in (!j!) do (
            set "PK=S_!ut[%%i]!_!ut[%%j]!"
            for %%k in (!PK!) do (
                if defined %%k (
                    set /a "g=%%y - %%k"
                    if !%%k! LSS %1 (
                        if !g! LSS !KORS! set /a KORS=g
                    ) else (
                        if !g! LSS !INRE! set /a INRE=g
                    )
                )
                set "%%k=%%y"
            )
        )
    )
)
exit /b 0

:test_fel
set /a TESTFEL+=1
echo     FEL: %~1
exit /b 0

rem ==================================================================
rem  Data. Rader har laggs till av programmet; den senaste galler.
rem ==================================================================
#LISTA;Theo|Stefan|Pia|Mona|Linus|Josa|Ella|Birgit|Alice
