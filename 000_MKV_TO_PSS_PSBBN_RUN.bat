@echo off
setlocal EnableExtensions EnableDelayedExpansion
title MKV to PSS - PSBBN

set "AUDIO_TRACK="
set "AUDIO_LANG="
set "AUDIO_LANG_NAME="
set "AUDIO_LANG_FILES=0"
set "OVERWRITE=0"

set "ROOT=%~dp0"
set "TOOLS=%ROOT%000_tools"
set "OUT=%ROOT%000_PSS"
set "TMP=%ROOT%_pss_tmp"
set "LOG=%ROOT%conversion_pss.log"

set "FFMPEG=%TOOLS%\ffmpeg.exe"
set "FFPROBE=%TOOLS%\ffprobe.exe"
set "PS2STR=%TOOLS%\ps2str.exe"
set "PS2STRW=%TOOLS%\ps2strw.exe"
set "ENCVAG=%TOOLS%\encvag.dll"
set "POWERSHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

set "IA_ID=ps2str_v1.08_2001"
set "IA_FILE=ps2str_v1.08_2001.zip"
set "IA_META=https://archive.org/metadata/%IA_ID%"
set "IA_DOWNLOAD=https://archive.org/download/%IA_ID%/%IA_FILE%"
set "IA_SERVE=https://archive.org/serve/%IA_ID%/%IA_FILE%"
set "PSXCORE_PAGE=https://psx-core.ru/load/ps2_soft/mf_audio_ps2str/8-1-0-634"
set "PSXCORE_DOWNLOAD=https://psx-core.ru/load/0-0-0-634-20"

echo.
echo ===============================================================================
echo                         MKV ^> PSS PSBBN
echo ===============================================================================
echo.

if not exist "%TOOLS%" mkdir "%TOOLS%"
if not exist "%OUT%" mkdir "%OUT%"
if not exist "%TMP%" mkdir "%TMP%"

if not exist "%FFMPEG%" (
    echo [ERROR] Missing "%FFMPEG%"
    goto :FATAL
)

if not exist "%FFPROBE%" (
    echo [ERROR] Missing "%FFPROBE%"
    goto :FATAL
)

if not exist "%PS2STR%" (
    call :GET_PS2STR
    if errorlevel 1 goto :FATAL
)

if not exist "%ENCVAG%" (
    call :GET_PS2STR
    if errorlevel 1 goto :FATAL
)

if not exist "%ROOT%*.mkv" (
    echo [ERROR] No MKV files found.
    goto :FATAL
)

> "%LOG%" echo ===============================================================
>>"%LOG%" echo MKV to PSS PSBBN
>>"%LOG%" echo Started: %DATE% %TIME%
>>"%LOG%" echo Folder: %ROOT%
>>"%LOG%" echo ===============================================================

set /a TOTAL=0
set /a INDEX=0
set /a SUCCESS=0
set /a FAILED=0
set /a SKIPPED=0
set "ABORT_ALL=0"

for %%F in ("%ROOT%*.mkv") do set /a TOTAL+=1

echo Output      : "%OUT%"
echo.
echo !TOTAL! MKV file(s) found.
echo.
echo ===============================================================================
echo                    AUDIO LANGUAGE DETECTION - MKV LIST
echo ===============================================================================
echo.

set /a SCAN_INDEX=0
set /a AUDIO_SCAN_ERRORS=0
set "LANG_REPORT=%TMP%\audio_languages.txt"
set "LANG_RAW=%TMP%\audio_language_raw.txt"
set "LANG_MENU=%TMP%\audio_language_menu.txt"

>"!LANG_REPORT!" echo Audio language scan - %DATE% %TIME%
>>"!LANG_REPORT!" echo.
>"!LANG_RAW!" type nul

for %%F in ("%ROOT%*.mkv") do (
    set /a SCAN_INDEX+=1
    call :SCAN_AUDIO_LANGUAGES "%%~fF" "%%~nxF"
)

echo.
echo [OK] Audio language scan complete. Building selection menu...
echo.

set "PSS_LANG_RAW=!LANG_RAW!"
set "PSS_LANG_MENU=!LANG_MENU!"

"%POWERSHELL%" -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; try {$rows=@(Get-Content -LiteralPath $env:PSS_LANG_RAW | Where-Object {$_ -match '\|'}); $items=@(); foreach($r in $rows){$p=$r -split '\|',2; if($p.Count -eq 2){$items += [pscustomobject]@{Code=$p[0];Name=$p[1]}}}; $groups=@($items | Group-Object Code); $priority=@{jpn=1;fra=2;eng=3;spa=4}; $menu=@(); foreach($g in $groups){$code=$g.Name; $name=($g.Group | Select-Object -First 1).Name; $rank=100; if($priority.ContainsKey($code)){$rank=$priority[$code]}; $menu += [pscustomobject]@{Code=$code;Name=$name;Count=$g.Count;Rank=$rank}}; $i=0; @($menu | Sort-Object Rank,Name,Code | ForEach-Object {$i++; '{0}|{1}|{2}|{3}' -f $i,$_.Code,$_.Name,$_.Count}) | Set-Content -LiteralPath $env:PSS_LANG_MENU -Encoding ASCII; exit 0} catch {exit 1}" >nul 2>&1

if errorlevel 1 (
    echo [ERROR] Could not build the audio language menu.
    goto :FATAL
)

set /a LANGUAGE_COUNT=0
for /f "usebackq tokens=1,2,3,4 delims=|" %%A in ("!LANG_MENU!") do set /a LANGUAGE_COUNT+=1

if !LANGUAGE_COUNT! LEQ 0 (
    echo [ERROR] No usable audio language was detected in the MKV files.
    goto :FATAL
)

echo.
echo -------------------------------------------------------------------------------
echo Audio languages detected across the MKV collection:
for /f "usebackq tokens=1,2,3,4 delims=|" %%A in ("!LANG_MENU!") do (
    echo   %%A. %%C : %%D/!TOTAL! file^(s^) [%%B]
)
if not "!AUDIO_SCAN_ERRORS!"=="0" echo   Scan errors: !AUDIO_SCAN_ERRORS!
echo -------------------------------------------------------------------------------
echo.
echo The menu is generated automatically from the languages actually present.
echo Japanese, French, English and Spanish are shown first when detected.
echo Any other valid language tag is also supported automatically.
echo.

:CHOOSE_AUDIO_LANGUAGE
set "AUDIO_CHOICE="
set "AUDIO_LANG="
set "AUDIO_LANG_NAME="
set "AUDIO_LANG_FILES=0"

echo Choose the audio language to use for ALL conversions:
echo.
for /f "usebackq tokens=1,2,3,4 delims=|" %%A in ("!LANG_MENU!") do (
    echo   %%A. %%C [%%B]
)
echo.
set /p "AUDIO_CHOICE=Choice [1-!LANGUAGE_COUNT!]: "

for /f "usebackq tokens=1,2,3,4 delims=|" %%A in ("!LANG_MENU!") do (
    if "%%A"=="!AUDIO_CHOICE!" (
        set "AUDIO_LANG=%%B"
        set "AUDIO_LANG_NAME=%%C"
        set "AUDIO_LANG_FILES=%%D"
    )
)

if not defined AUDIO_LANG (
    echo.
    echo [ERROR] Invalid choice. Enter a number from 1 to !LANGUAGE_COUNT!.
    echo.
    goto :CHOOSE_AUDIO_LANGUAGE
)

echo.
echo Selected audio: !AUDIO_LANG_NAME! [!AUDIO_LANG!]
if !AUDIO_LANG_FILES! LSS !TOTAL! echo [WARNING] This language was detected in !AUDIO_LANG_FILES!/!TOTAL! MKV file(s). Files without it will not be converted.
echo.

>>"%LOG%" echo Selected audio language: !AUDIO_LANG_NAME! [!AUDIO_LANG!] - !AUDIO_LANG_FILES!/!TOTAL! file(s)
>>"%LOG%" echo Available audio languages:
type "!LANG_MENU!" >>"%LOG%"

for %%F in ("%ROOT%*.mkv") do (
    set /a INDEX+=1
    call :PROCESS "%%~fF"
    if "!ABORT_ALL!"=="1" goto :FINISH
)

goto :FINISH


:PROCESS
set "INPUT=%~1"
set "NAME=%~nx1"
set "BASE=%~n1"
set "JOB=job_!INDEX!"

set "WAV=%TMP%\!JOB!.wav"
set "WAV2=%TMP%\!JOB!_aligned.wav"
set "M2V=%TMP%\!JOB!.m2v"
set "ADS=%TMP%\!JOB!.ads"
set "MUX=%TMP%\!JOB!.mux"
set "PSS_TMP=%TMP%\!JOB!.pss"
set "OUTPUT=%OUT%\!BASE!.pss"

set "DURFILE=%TMP%\!JOB!_duration.txt"
set "FIELDFILE=%TMP%\!JOB!_field.txt"
set "FRAMEFILE=%TMP%\!JOB!_frames.txt"
set "TARGETFILE=%TMP%\!JOB!_target.txt"
set "WAVDURFILE=%TMP%\!JOB!_wavdur.txt"
set "PS2LOG=%TMP%\!JOB!_ps2str.log"

echo.
echo ===============================================================================
echo [!INDEX!/!TOTAL!] !NAME!
echo ===============================================================================

>>"%LOG%" echo.
>>"%LOG%" echo [!INDEX!/!TOTAL!] !NAME!

if exist "!OUTPUT!" (
    if "!OVERWRITE!"=="0" (
        echo [SKIP] Output already exists.
        >>"%LOG%" echo SKIP: !OUTPUT!
        set /a SKIPPED+=1
        exit /b
    )
)

del /q "!WAV!" "!WAV2!" "!M2V!" "!ADS!" "!MUX!" "!PSS_TMP!" "!DURFILE!" "!FIELDFILE!" "!FRAMEFILE!" "!TARGETFILE!" "!WAVDURFILE!" "!PS2LOG!" >nul 2>&1

"%FFPROBE%" -v error -show_entries format=duration -of default=nw=1:nk=1 "!INPUT!" > "!DURFILE!" 2>>"%LOG%"

if errorlevel 1 (
    echo [ERROR] Could not read duration.
    >>"%LOG%" echo FAILED: ffprobe duration.
    set /a FAILED+=1
    exit /b
)

set "DURATION="
if exist "!DURFILE!" set /p "DURATION="<"!DURFILE!"
if not defined DURATION (
    echo [ERROR] Could not read duration.
    >>"%LOG%" echo FAILED: duration missing.
    set /a FAILED+=1
    exit /b
)

for /f "tokens=1 delims=." %%S in ("!DURATION!") do set "SECONDS=%%S"
set /a MINUTES=SECONDS/60

if !MINUTES! LEQ 31 (
    set "BITRATE=1800"
) else if !MINUTES! LEQ 89 (
    set "BITRATE=1600"
) else if !MINUTES! LEQ 92 (
    set "BITRATE=1400"
) else if !MINUTES! LEQ 102 (
    set "BITRATE=1200"
) else if !MINUTES! LEQ 107 (
    set "BITRATE=1000"
) else if !MINUTES! LEQ 120 (
    set "BITRATE=800"
) else (
    set "BITRATE=600"
)

set "FIELD_ORDER="
"%FFPROBE%" -v error -select_streams v:0 -show_entries stream=field_order -of default=nw=1:nk=1 "!INPUT!" > "!FIELDFILE!" 2>>"%LOG%"
if exist "!FIELDFILE!" set /p "FIELD_ORDER="<"!FIELDFILE!"

set "INTERLACE_OPTS="
if /i "!FIELD_ORDER!"=="progressive" (
    set "SOURCE_MODE=progressive"
) else (
    set "SOURCE_MODE=interlaced"
    set "INTERLACE_OPTS=-flags +ilme+ildct -field_order tt"
)

echo Duration      : !MINUTES! minute(s)
echo MPEG-2 bitrate: !BITRATE! kb/s
echo Source        : !FIELD_ORDER!

call :RESOLVE_AUDIO_TRACK
if errorlevel 1 (
    echo [ERROR] !AUDIO_LANG_NAME! audio track was not found in this MKV.
    >>"%LOG%" echo FAILED: !AUDIO_LANG_NAME! audio track not found.
    call :CLEAN_JOB
    set /a FAILED+=1
    exit /b
)

echo Audio         : !AUDIO_LANG_NAME! ^(audio track !AUDIO_TRACK!^)
>>"%LOG%" echo Audio: !AUDIO_LANG_NAME! track=!AUDIO_TRACK!

echo.
echo [1/4] Encoding video and audio...

call :ENCODE_MEDIA
if errorlevel 1 (
    echo [ERROR] FFmpeg conversion failed.
    >>"%LOG%" echo FAILED: FFmpeg media conversion.
    call :CLEAN_JOB
    set /a FAILED+=1
    exit /b
)

call :ALIGN_AUDIO
if errorlevel 1 (
    echo [ERROR] Audio alignment failed.
    >>"%LOG%" echo FAILED: audio alignment.
    call :CLEAN_JOB
    set /a FAILED+=1
    exit /b
)

call :CHECK_SIZE
if "!SIZE_TOO_BIG!"=="1" (
    set /a BITRATE-=200

    if !BITRATE! LSS 200 (
        echo [ERROR] Output is too large.
        >>"%LOG%" echo FAILED: output too large.
        call :CLEAN_JOB
        set /a FAILED+=1
        exit /b
    )

    echo [2/4] Re-encoding video at !BITRATE! kb/s...

    call :ENCODE_VIDEO
    if errorlevel 1 (
        echo [ERROR] Video re-encode failed.
        >>"%LOG%" echo FAILED: video re-encode.
        call :CLEAN_JOB
        set /a FAILED+=1
        exit /b
    )

    call :ALIGN_AUDIO
    if errorlevel 1 (
        echo [ERROR] Audio alignment failed.
        >>"%LOG%" echo FAILED: audio alignment after re-encode.
        call :CLEAN_JOB
        set /a FAILED+=1
        exit /b
    )

    call :CHECK_SIZE
    if "!SIZE_TOO_BIG!"=="1" (
        echo [ERROR] Output is still too large.
        >>"%LOG%" echo FAILED: output still too large.
        call :CLEAN_JOB
        set /a FAILED+=1
        exit /b
    )
) else (
    echo [2/4] MPEG-2 and PCM ready.
)

echo.
echo [3/4] Converting WAV ^> ADS...

"%PS2STR%" encode -v "!WAV!" "!ADS!" > "!PS2LOG!" 2>&1
set "PS2RC=!errorlevel!"

if exist "!PS2LOG!" type "!PS2LOG!" >>"%LOG%"

if not "!PS2RC!"=="0" (
    echo [ERROR] ps2str encode returned !PS2RC!.
    if exist "!PS2LOG!" type "!PS2LOG!"
    >>"%LOG%" echo FAILED: ps2str encode !PS2RC!.
    set /a FAILED+=1
    set "ABORT_ALL=1"
    exit /b
)

if not exist "!ADS!" (
    echo [ERROR] ADS file was not created.
    >>"%LOG%" echo FAILED: ADS missing.
    set /a FAILED+=1
    set "ABORT_ALL=1"
    exit /b
)

echo.
echo [4/4] Multiplexing PSS...

> "!MUX!" (
    echo pss
    echo     stream video:0
    echo         input "!JOB!.m2v"
    echo     end
    echo.
    echo     stream pcm:0
    echo         input "!JOB!.ads"
    echo     end
    echo end
)

pushd "%TMP%"
"%PS2STR%" mux -v "!JOB!.mux" > "!PS2LOG!" 2>&1
set "PS2RC=!errorlevel!"
popd

if exist "!PS2LOG!" type "!PS2LOG!" >>"%LOG%"

if not "!PS2RC!"=="0" (
    echo [ERROR] ps2str mux returned !PS2RC!.
    if exist "!PS2LOG!" type "!PS2LOG!"
    >>"%LOG%" echo FAILED: ps2str mux !PS2RC!.
    set /a FAILED+=1
    set "ABORT_ALL=1"
    exit /b
)

if not exist "!PSS_TMP!" (
    echo [ERROR] PSS file was not created.
    >>"%LOG%" echo FAILED: PSS missing.
    set /a FAILED+=1
    exit /b
)

move /y "!PSS_TMP!" "!OUTPUT!" >nul
if errorlevel 1 (
    echo [ERROR] Could not move the final PSS.
    >>"%LOG%" echo FAILED: output move.
    set /a FAILED+=1
    exit /b
)

echo [OK] "!OUTPUT!"
>>"%LOG%" echo OK: !OUTPUT!
set /a SUCCESS+=1

call :CLEAN_JOB
exit /b


:SCAN_AUDIO_LANGUAGES
set "SCAN_INPUT=%~1"
set "SCAN_NAME=%~2"
set "SCAN_RESULT_FILE=%TMP%\audio_scan_!SCAN_INDEX!.txt"
set "PSS_SCAN_INPUT=!SCAN_INPUT!"
set "PSS_FFPROBE=%FFPROBE%"

del /q "!SCAN_RESULT_FILE!" >nul 2>&1

"%POWERSHELL%" -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; function InitMaps {$script:two=@{};$script:three=@{};$script:names=@{}; foreach($c in [Globalization.CultureInfo]::GetCultures([Globalization.CultureTypes]::AllCultures)){try{$a=($c.TwoLetterISOLanguageName+'').ToLowerInvariant();$b=($c.ThreeLetterISOLanguageName+'').ToLowerInvariant(); if($a -and $b -and $a -ne 'iv'){$script:two[$a]=$b;$script:three[$b]=$b;if(-not $script:names.ContainsKey($b)){$n=($c.EnglishName -replace '\s*\(.*$','').Trim();if($n){$script:names[$b]=$n}}}}catch{}}; $script:alias=@{fre='fra';ger='deu';dut='nld';cze='ces';chi='zho';gre='ell';rum='ron';slo='slk';alb='sqi';arm='hye';baq='eus';bur='mya';ice='isl';mac='mkd';mao='mri';may='msa';per='fas';tib='bod';wel='cym';jp='jpn'}}; function Canon([string]$l,[string]$t){$l=($l+'').Trim().ToLowerInvariant(); if($l -match '^([a-z]{2,3})(?:[-_].*)?$'){$l=$Matches[1]}; if($script:alias.ContainsKey($l)){$l=$script:alias[$l]}; if($script:two.ContainsKey($l)){return $script:two[$l]}; if($script:three.ContainsKey($l)){return $script:three[$l]}; if($l -and $l -notin @('und','unk','unknown')){return $l}; $t=($t+'').Trim().ToLowerInvariant(); $p=[ordered]@{jpn='japanese|japonais|nihongo';fra='french|fran.ais|vff|vfq';eng='english|anglais';spa='spanish|espa.ol|castellano';deu='german|deutsch|allemand';ita='italian|italiano|italien';por='portuguese|portugu.s|portugues';nld='dutch|nederlands|neerlandais';rus='russian|russe';zho='chinese|mandarin|cantonese';kor='korean|coreen';ara='arabic|arabe';pol='polish|polski|polonais';ces='czech|cesky|tcheque';hun='hungarian|magyar|hongrois';swe='swedish|svenska|suedois';nor='norwegian|norsk|norvegien';dan='danish|dansk|danois';fin='finnish|suomi|finnois';ell='greek|grec';tur='turkish|turkce|turc';ron='romanian|romana|roumain';ukr='ukrainian|ukrainien';hin='hindi';tha='thai';vie='vietnamese|vietnamien';ind='indonesian|bahasa indonesia'}; foreach($k in $p.Keys){if($t -match ('(^|[^a-z])('+$p[$k]+')([^a-z]|$)')){return $k}}; return 'und'}; function LangName([string]$c){if($script:names.ContainsKey($c)){return $script:names[$c]}; switch($c){'jpn'{return 'Japanese'};'fra'{return 'French'};'eng'{return 'English'};'spa'{return 'Spanish'};'und'{return 'Undetermined / untagged'};'zxx'{return 'No linguistic content'};'mul'{return 'Multiple languages'};default{return $c.ToUpperInvariant()}}}; try {InitMaps; $raw=& $env:PSS_FFPROBE -v error -select_streams a -show_entries 'stream=index:stream_tags=language,title' -of json $env:PSS_SCAN_INPUT 2>$null | Out-String; $j=$raw|ConvertFrom-Json; $streams=@($j.streams); $seen=@{}; $labels=New-Object System.Collections.Generic.List[string]; for($i=0;$i -lt $streams.Count;$i++){$st=$streams[$i];$code=Canon ([string]$st.tags.language) ([string]$st.tags.title);$name=LangName $code;$labels.Add(('A{0}={1} [{2}]' -f $i,$name,$code));if(-not $seen.ContainsKey($code)){$seen[$code]=$name}}; if($labels.Count -eq 0){$labels.Add('no-audio')}; 'LABELS|'+($labels -join ', '); foreach($code in @($seen.Keys|Sort-Object)){'LANG|{0}|{1}' -f $code,$seen[$code]}; exit 0} catch {'ERROR|SCAN-ERROR'; exit 1}" > "!SCAN_RESULT_FILE!"

set "SCAN_LANGS=SCAN-ERROR"
set "SCAN_FAILED=0"

if not exist "!SCAN_RESULT_FILE!" (
    set "SCAN_FAILED=1"
) else (
    for /f "usebackq tokens=1,* delims=|" %%A in ("!SCAN_RESULT_FILE!") do (
        if /i "%%A"=="LABELS" set "SCAN_LANGS=%%B"
        if /i "%%A"=="LANG" >>"!LANG_RAW!" echo %%B
        if /i "%%A"=="ERROR" set "SCAN_FAILED=1"
    )
)

if "!SCAN_FAILED!"=="1" set /a AUDIO_SCAN_ERRORS+=1

echo [!SCAN_INDEX!/!TOTAL!] !SCAN_NAME!  --^>  !SCAN_LANGS!
>>"!LANG_REPORT!" echo [!SCAN_INDEX!/!TOTAL!] !SCAN_NAME!  --^>  !SCAN_LANGS!
>>"%LOG%" echo AUDIO SCAN [!SCAN_INDEX!/!TOTAL!] !SCAN_NAME! --^> !SCAN_LANGS!

del /q "!SCAN_RESULT_FILE!" >nul 2>&1
exit /b 0


:RESOLVE_AUDIO_TRACK
set "AUDIO_TRACK="
set "AUDIOSELFILE=%TMP%\!JOB!_audio_track.txt"
set "PSS_AUDIO_INPUT=!INPUT!"
set "PSS_AUDIO_LANG=!AUDIO_LANG!"
set "PSS_FFPROBE=%FFPROBE%"

del /q "!AUDIOSELFILE!" >nul 2>&1

"%POWERSHELL%" -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; function InitMaps {$script:two=@{};$script:three=@{}; foreach($c in [Globalization.CultureInfo]::GetCultures([Globalization.CultureTypes]::AllCultures)){try{$a=($c.TwoLetterISOLanguageName+'').ToLowerInvariant();$b=($c.ThreeLetterISOLanguageName+'').ToLowerInvariant();if($a -and $b -and $a -ne 'iv'){$script:two[$a]=$b;$script:three[$b]=$b}}catch{}};$script:alias=@{fre='fra';ger='deu';dut='nld';cze='ces';chi='zho';gre='ell';rum='ron';slo='slk';alb='sqi';arm='hye';baq='eus';bur='mya';ice='isl';mac='mkd';mao='mri';may='msa';per='fas';tib='bod';wel='cym';jp='jpn'}}; function Canon([string]$l,[string]$t){$l=($l+'').Trim().ToLowerInvariant();if($l -match '^([a-z]{2,3})(?:[-_].*)?$'){$l=$Matches[1]};if($script:alias.ContainsKey($l)){$l=$script:alias[$l]};if($script:two.ContainsKey($l)){return $script:two[$l]};if($script:three.ContainsKey($l)){return $script:three[$l]};if($l -and $l -notin @('und','unk','unknown')){return $l};$t=($t+'').Trim().ToLowerInvariant();$p=[ordered]@{jpn='japanese|japonais|nihongo';fra='french|fran.ais|vff|vfq';eng='english|anglais';spa='spanish|espa.ol|castellano';deu='german|deutsch|allemand';ita='italian|italiano|italien';por='portuguese|portugu.s|portugues';nld='dutch|nederlands|neerlandais';rus='russian|russe';zho='chinese|mandarin|cantonese';kor='korean|coreen';ara='arabic|arabe';pol='polish|polski|polonais';ces='czech|cesky|tcheque';hun='hungarian|magyar|hongrois';swe='swedish|svenska|suedois';nor='norwegian|norsk|norvegien';dan='danish|dansk|danois';fin='finnish|suomi|finnois';ell='greek|grec';tur='turkish|turkce|turc';ron='romanian|romana|roumain';ukr='ukrainian|ukrainien';hin='hindi';tha='thai';vie='vietnamese|vietnamien';ind='indonesian|bahasa indonesia'};foreach($k in $p.Keys){if($t -match ('(^|[^a-z])('+$p[$k]+')([^a-z]|$)')){return $k}};return 'und'}; try {InitMaps;$raw=& $env:PSS_FFPROBE -v error -select_streams a -show_entries 'stream=index:stream_tags=language,title' -of json $env:PSS_AUDIO_INPUT 2>$null | Out-String;$j=$raw|ConvertFrom-Json;$streams=@($j.streams);for($i=0;$i -lt $streams.Count;$i++){$st=$streams[$i];$code=Canon ([string]$st.tags.language) ([string]$st.tags.title);if($code -eq $env:PSS_AUDIO_LANG){[Console]::WriteLine($i);exit 0}};exit 3} catch {exit 4}" > "!AUDIOSELFILE!"

if errorlevel 1 (
    del /q "!AUDIOSELFILE!" >nul 2>&1
    exit /b 1
)

if exist "!AUDIOSELFILE!" set /p "AUDIO_TRACK="<"!AUDIOSELFILE!"
del /q "!AUDIOSELFILE!" >nul 2>&1

if not defined AUDIO_TRACK exit /b 1
exit /b 0


:ENCODE_MEDIA
del /q "!WAV!" "!M2V!" >nul 2>&1

"%FFMPEG%" -y -hide_banner -loglevel error -stats ^
    -copyts -start_at_zero ^
    -i "!INPUT!" ^
    -filter_complex "[0:v:0]fps=30000/1001:start_time=0:round=near,scale=iw*sar:ih,setsar=1,scale=640:480:force_original_aspect_ratio=decrease,pad=640:480:(ow-iw)/2:(oh-ih)/2,format=yuv420p[v];[0:a:!AUDIO_TRACK!]aresample=48000:async=1000:first_pts=0:min_hard_comp=0.100,volume=3.874dB[a]" ^
    -map "[v]" ^
    -c:v mpeg2video ^
    -b:v !BITRATE!k ^
    -g 30 ^
    -bf 3 ^
    -trellis 1 ^
    -dc 10 ^
    -sc_threshold 40 ^
    -threads 0 ^
    !INTERLACE_OPTS! ^
    -an ^
    "!M2V!" ^
    -map "[a]" ^
    -c:a pcm_s16le ^
    -ac 2 ^
    -ar 48000 ^
    -vn ^
    -map_metadata -1 ^
    "!WAV!"

if errorlevel 1 exit /b 1
if not exist "!M2V!" exit /b 1
if not exist "!WAV!" exit /b 1
exit /b 0


:ENCODE_VIDEO
del /q "!M2V!" >nul 2>&1

"%FFMPEG%" -y -hide_banner -loglevel error -stats ^
    -copyts -start_at_zero ^
    -i "!INPUT!" ^
    -vf "fps=30000/1001:start_time=0:round=near,scale=iw*sar:ih,setsar=1,scale=640:480:force_original_aspect_ratio=decrease,pad=640:480:(ow-iw)/2:(oh-ih)/2,format=yuv420p" ^
    -an ^
    -c:v mpeg2video ^
    -b:v !BITRATE!k ^
    -g 30 ^
    -bf 3 ^
    -trellis 1 ^
    -dc 10 ^
    -sc_threshold 40 ^
    -threads 0 ^
    !INTERLACE_OPTS! ^
    "!M2V!"

if errorlevel 1 exit /b 1
if not exist "!M2V!" exit /b 1
exit /b 0


:ALIGN_AUDIO
del /q "!WAV2!" "!FRAMEFILE!" "!TARGETFILE!" "!WAVDURFILE!" >nul 2>&1

"%FFPROBE%" -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of default=nw=1:nk=1 "!M2V!" > "!FRAMEFILE!" 2>>"%LOG%"
if errorlevel 1 exit /b 1

set "FRAMES="
if exist "!FRAMEFILE!" set /p "FRAMES="<"!FRAMEFILE!"
if not defined FRAMES exit /b 1
if /i "!FRAMES!"=="N/A" exit /b 1

set "PSS_FRAMES=!FRAMES!"
"%POWERSHELL%" -NoProfile -Command "$f=[double]$env:PSS_FRAMES; $d=$f*1001.0/30000.0; [Console]::WriteLine($d.ToString('0.000000000',[Globalization.CultureInfo]::InvariantCulture))" > "!TARGETFILE!"
if errorlevel 1 exit /b 1

set "TARGET="
if exist "!TARGETFILE!" set /p "TARGET="<"!TARGETFILE!"
if not defined TARGET exit /b 1

"%FFMPEG%" -y -hide_banner -loglevel error ^
    -i "!WAV!" ^
    -af "apad,atrim=start=0:end=!TARGET!,asetpts=N/SR/TB" ^
    -c:a pcm_s16le ^
    -ac 2 ^
    -ar 48000 ^
    "!WAV2!"

if errorlevel 1 exit /b 1
if not exist "!WAV2!" exit /b 1

move /y "!WAV2!" "!WAV!" >nul
if errorlevel 1 exit /b 1

"%FFPROBE%" -v error -show_entries format=duration -of default=nw=1:nk=1 "!WAV!" > "!WAVDURFILE!" 2>>"%LOG%"
if errorlevel 1 exit /b 1

set "WAV_DURATION="
if exist "!WAVDURFILE!" set /p "WAV_DURATION="<"!WAVDURFILE!"
if not defined WAV_DURATION exit /b 1

set "PSS_TARGET=!TARGET!"
set "PSS_WAV_DURATION=!WAV_DURATION!"

"%POWERSHELL%" -NoProfile -Command "$t=[double]$env:PSS_TARGET; $a=[double]$env:PSS_WAV_DURATION; if([Math]::Abs($a-$t) -le 0.002){exit 0}else{exit 1}"
if errorlevel 1 exit /b 1

>>"%LOG%" echo A/V: frames=!FRAMES! target=!TARGET! audio=!WAV_DURATION!
exit /b 0


:CHECK_SIZE
set "SIZE_TOO_BIG=0"
set "PSS_SIZE_WAV=!WAV!"
set "PSS_SIZE_M2V=!M2V!"

"%POWERSHELL%" -NoProfile -Command "$a=(Get-Item -LiteralPath $env:PSS_SIZE_WAV).Length; $v=(Get-Item -LiteralPath $env:PSS_SIZE_M2V).Length; if(($a+$v) -gt 2131755008){exit 2}else{exit 0}"

if errorlevel 2 set "SIZE_TOO_BIG=1"
exit /b 0


:GET_PS2STR
echo [TOOLS] Downloading PS2STR...

set "PS2_ZIP=%TMP%\%IA_FILE%"
set "PS2_META=%TMP%\ps2str_metadata.json"
set "PS2_URLS=%TMP%\ps2str_urls.txt"
set "PS2_EXTRACT=%TMP%\ps2str_extract"

del /q "%PS2_ZIP%" "%PS2_META%" "%PS2_URLS%" >nul 2>&1
if exist "%PS2_EXTRACT%" rd /s /q "%PS2_EXTRACT%" >nul 2>&1
mkdir "%PS2_EXTRACT%" >nul 2>&1

set "CURL_EXE="
if exist "%SystemRoot%\System32\curl.exe" set "CURL_EXE=%SystemRoot%\System32\curl.exe"
if not defined CURL_EXE (
    where curl.exe >nul 2>&1
    if not errorlevel 1 set "CURL_EXE=curl.exe"
)

set "DOWNLOAD_OK=0"

rem Build Archive.org candidate URLs.
> "%PS2_URLS%" echo %IA_DOWNLOAD%
>>"%PS2_URLS%" echo %IA_SERVE%

if defined CURL_EXE (
    "!CURL_EXE!" -sS -L --fail --connect-timeout 10 --max-time 45 ^
        -o "%PS2_META%" "%IA_META%" >nul 2>&1
)

if not exist "%PS2_META%" (
    "%POWERSHELL%" -NoProfile -ExecutionPolicy Bypass -Command ^
      "$ProgressPreference='SilentlyContinue'; try { Invoke-WebRequest -UseBasicParsing -Uri $env:IA_META -TimeoutSec 30 -OutFile $env:PS2_META; exit 0 } catch { exit 1 }" >nul 2>&1
)

if exist "%PS2_META%" (
    "%POWERSHELL%" -NoProfile -ExecutionPolicy Bypass -Command ^
      "try {$m=Get-Content -Raw -LiteralPath $env:PS2_META | ConvertFrom-Json; $hosts=@($m.server,$m.d1,$m.d2) | Where-Object {$_} | Select-Object -Unique; $direct=@(); foreach($h in $hosts){$direct += ('https://' + $h + $m.dir + '/' + $env:IA_FILE)}; $existing=Get-Content -LiteralPath $env:PS2_URLS; @($direct + $existing) | Select-Object -Unique | Set-Content -LiteralPath $env:PS2_URLS -Encoding ASCII; exit 0} catch {exit 1}" >nul 2>&1
)

if defined CURL_EXE (
    echo [TOOLS] Trying Archive.org...
    for /f "usebackq delims=" %%U in ("%PS2_URLS%") do (
        if "!DOWNLOAD_OK!"=="0" (
            del /q "%PS2_ZIP%" >nul 2>&1
            "!CURL_EXE!" -sS -L --fail --retry 2 --retry-delay 2 ^
                --connect-timeout 12 --max-time 90 ^
                -A "Mozilla/5.0" ^
                -o "%PS2_ZIP%" "%%U" >nul 2>&1

            if not errorlevel 1 (
                call :VALIDATE_ZIP "%PS2_ZIP%"
                if not errorlevel 1 set "DOWNLOAD_OK=1"
            )
        )
    )
)

if "!DOWNLOAD_OK!"=="0" (
    echo [TOOLS] Trying Archive.org with PowerShell...
    "%POWERSHELL%" -NoProfile -ExecutionPolicy Bypass -Command ^
      "$ProgressPreference='SilentlyContinue'; $urls=Get-Content -LiteralPath $env:PS2_URLS; foreach($u in $urls){try{$wc=New-Object Net.WebClient; $wc.Headers['User-Agent']='Mozilla/5.0'; $wc.DownloadFile($u,$env:PS2_ZIP); if((Test-Path -LiteralPath $env:PS2_ZIP) -and ((Get-Item -LiteralPath $env:PS2_ZIP).Length -gt 1024)){exit 0}}catch{}}; exit 1" >nul 2>&1

    if not errorlevel 1 (
        call :VALIDATE_ZIP "%PS2_ZIP%"
        if not errorlevel 1 set "DOWNLOAD_OK=1"
    )
)

if "!DOWNLOAD_OK!"=="0" (
    echo [TOOLS] Trying PSX-Core mirror...
    del /q "%PS2_ZIP%" >nul 2>&1

    if defined CURL_EXE (
        "!CURL_EXE!" -sS -L --fail --retry 2 --retry-delay 2 ^
            --connect-timeout 12 --max-time 120 ^
            -A "Mozilla/5.0" ^
            -e "%PSXCORE_PAGE%" ^
            -o "%PS2_ZIP%" "%PSXCORE_DOWNLOAD%" >nul 2>&1
    )

    if not errorlevel 1 (
        call :VALIDATE_ZIP "%PS2_ZIP%"
        if not errorlevel 1 set "DOWNLOAD_OK=1"
    )

    if "!DOWNLOAD_OK!"=="0" (
        "%POWERSHELL%" -NoProfile -ExecutionPolicy Bypass -Command ^
          "$ProgressPreference='SilentlyContinue'; try {$h=@{'User-Agent'='Mozilla/5.0';'Referer'=$env:PSXCORE_PAGE}; Invoke-WebRequest -UseBasicParsing -MaximumRedirection 10 -Headers $h -Uri $env:PSXCORE_DOWNLOAD -OutFile $env:PS2_ZIP -TimeoutSec 90; exit 0} catch {exit 1}" >nul 2>&1

        if not errorlevel 1 (
            call :VALIDATE_ZIP "%PS2_ZIP%"
            if not errorlevel 1 set "DOWNLOAD_OK=1"
        )
    )
)

if "!DOWNLOAD_OK!"=="0" (
    echo [ERROR] Could not download PS2STR.
    exit /b 1
)

echo [TOOLS] Extracting PS2STR...

"%POWERSHELL%" -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; Expand-Archive -LiteralPath $env:PS2_ZIP -DestinationPath $env:PS2_EXTRACT -Force" >nul 2>&1

if errorlevel 1 (
    echo [ERROR] Could not extract PS2STR.
    exit /b 1
)

set "PS2SRC=%PS2_EXTRACT%\ps2str\win32"

if not exist "%PS2SRC%\ps2str.exe" (
    echo [ERROR] Missing ps2str.exe in downloaded archive.
    exit /b 1
)

if not exist "%PS2SRC%\encvag.dll" (
    echo [ERROR] Missing encvag.dll in downloaded archive.
    exit /b 1
)

copy /y "%PS2SRC%\ps2str.exe" "%PS2STR%" >nul
if errorlevel 1 (
    echo [ERROR] Could not copy ps2str.exe.
    exit /b 1
)

copy /y "%PS2SRC%\encvag.dll" "%ENCVAG%" >nul
if errorlevel 1 (
    echo [ERROR] Could not copy encvag.dll.
    exit /b 1
)

if exist "%PS2SRC%\ps2strw.exe" (
    copy /y "%PS2SRC%\ps2strw.exe" "%PS2STRW%" >nul
)

if not exist "%PS2STR%" (
    echo [ERROR] ps2str.exe is missing after copy.
    exit /b 1
)

if not exist "%ENCVAG%" (
    echo [ERROR] encvag.dll is missing after copy.
    exit /b 1
)

del /q "%PS2_ZIP%" "%PS2_META%" "%PS2_URLS%" >nul 2>&1
rd /s /q "%PS2_EXTRACT%" >nul 2>&1

echo [OK] PS2STR ready.
echo.
exit /b 0


:VALIDATE_ZIP
set "CHECK_ZIP=%~1"
if not exist "%CHECK_ZIP%" exit /b 1
set "PSS_ZIP_CHECK=%CHECK_ZIP%"

"%POWERSHELL%" -NoProfile -ExecutionPolicy Bypass -Command ^
  "try {$p=$env:PSS_ZIP_CHECK; $f=Get-Item -LiteralPath $p; if($f.Length -le 1024){exit 1}; $s=[IO.File]::OpenRead($p); try {$b=New-Object byte[] 2; [void]$s.Read($b,0,2)} finally {$s.Dispose()}; if($b[0]-eq 0x50 -and $b[1]-eq 0x4B){exit 0}else{exit 1}} catch {exit 1}" >nul 2>&1

exit /b %errorlevel%


:CLEAN_JOB
del /q "!WAV!" "!WAV2!" "!M2V!" "!ADS!" "!MUX!" "!PSS_TMP!" "!DURFILE!" "!FIELDFILE!" "!FRAMEFILE!" "!TARGETFILE!" "!WAVDURFILE!" "!PS2LOG!" >nul 2>&1
exit /b 0


:FINISH
echo.
echo ===============================================================================
echo                                  FINISHED
echo ===============================================================================
echo.
echo Successful : !SUCCESS!
echo Skipped    : !SKIPPED!
echo Failed     : !FAILED!
echo Total      : !TOTAL!
echo.
echo Output:
echo "%OUT%"
echo.
echo Log:
echo "%LOG%"
echo.

>>"%LOG%" echo.
>>"%LOG%" echo ===============================================================
>>"%LOG%" echo Finished: %DATE% %TIME%
>>"%LOG%" echo Successful=!SUCCESS! Skipped=!SKIPPED! Failed=!FAILED! Total=!TOTAL!
>>"%LOG%" echo ===============================================================

rd "%TMP%" >nul 2>&1
pause
exit /b 0


:FATAL
echo.
echo The batch cannot continue.
echo.
pause
exit /b 1
