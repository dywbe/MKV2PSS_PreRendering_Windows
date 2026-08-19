@echo off
setlocal EnableExtensions EnableDelayedExpansion
title MKV to PSS - PSBBN - CPU FIXED + RECOVERY

rem ============================================================================
rem  MKV -> PSS for the PSBBN Definitive Project
rem
rem  Expected folder layout:
rem
rem    This_folder\
rem      MKV_TO_PSS_PSBBN_RUN.bat
rem      episode01.mkv
rem      episode02.mkv
rem      ...
rem      000_tools\
rem        ffmpeg.exe
rem        ffprobe.exe
rem        ps2str.exe
rem        ps2strw.exe
rem        encvag.dll
rem
rem  Outputs:
rem      000_PSS\episode01.pss
rem      000_PSS\episode02.pss
rem
rem  IMPORTANT:
rem  - 100%% CPU conversion.
rem  - The _pss_tmp folder is NOT deleted at startup.
rem  - If a complete WAV + M2V pair already exists (from the old broken batch),
rem    it is reused so processing can resume directly from step [3/4].
rem ============================================================================
rem
rem  Attribution:
rem  - Conversion workflow/parameters are based on CosmicScale's
rem    PSBBN Definitive Project Media Installer.
rem  - FFmpeg and ffprobe are part of the FFmpeg project.
rem  - ps2str / ps2strw / encvag are legacy Sony Computer Entertainment tools.
rem  See README.md for licensing and redistribution notes.

rem ----------------------------- USER SETTINGS ----------------------------------

rem FFmpeg audio track index: 0 = first audio track, 1 = second, etc.
set "AUDIO_TRACK=0"

rem 0 = skip if the PSS output already exists
rem 1 = overwrite the existing PSS
set "OVERWRITE=0"

rem 1 = reuse complete WAV/M2V files found in _pss_tmp
rem     (useful after the previous broken CPU batch)
rem 0 = rebuild everything
set "RECOVER_TEMP=1"

rem --------------------------- FOLDERS / TOOLS ----------------------------------

set "ROOT=%~dp0"
set "TOOLS=%ROOT%000_tools"
set "OUT=%ROOT%000_PSS"
set "TMP=%ROOT%_pss_tmp"
set "LOG=%ROOT%conversion_pss.log"

set "FFMPEG=%TOOLS%\ffmpeg.exe"
set "FFPROBE=%TOOLS%\ffprobe.exe"
set "PS2STR=%TOOLS%\ps2str.exe"
set "ENCVAG=%TOOLS%\encvag.dll"
set "POWERSHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

echo.
echo ===============================================================================
echo       MKV ^> PSS PSBBN - CPU FIXED + RECOVERY
echo ===============================================================================
echo.

rem ------------------------------ CHECKS -----------------------------------------

if not exist "%FFMPEG%" (
    echo [ERROR] Missing: "%FFMPEG%"
    echo Put ffmpeg.exe in the "000_tools" folder.
    goto :FATAL
)

if not exist "%FFPROBE%" (
    echo [ERROR] Missing: "%FFPROBE%"
    echo Put ffprobe.exe in the "000_tools" folder.
    goto :FATAL
)

if not exist "%PS2STR%" (
    echo [ERROR] Missing: "%PS2STR%"
    echo Put ps2str.exe in the "000_tools" folder.
    goto :FATAL
)

if not exist "%ENCVAG%" (
    echo [ERROR] Missing: "%ENCVAG%"
    echo Put encvag.dll next to ps2str.exe in the "000_tools" folder.
    goto :FATAL
)

if not exist "%ROOT%*.mkv" (
    echo [ERROR] No MKV files were found in:
    echo "%ROOT%"
    goto :FATAL
)

if not exist "%OUT%" mkdir "%OUT%"
if not exist "%TMP%" mkdir "%TMP%"

rem IMPORTANT: keep old WAV/M2V files so work from the previous broken
rem CPU batch can be recovered.
del /q "%TMP%\job_*.ads" "%TMP%\job_*.mux" "%TMP%\job_*.pss" "%TMP%\job_*_duration.txt" "%TMP%\job_*_field_order.txt" "%TMP%\job_*_codec.txt" "%TMP%\job_*_recover_*.txt" >nul 2>&1

> "%LOG%" echo ===============================================================
>>"%LOG%" echo MKV to PSS PSBBN conversion
>>"%LOG%" echo Started: %DATE% %TIME%
>>"%LOG%" echo Folder: %ROOT%
>>"%LOG%" echo ===============================================================

rem ----------------------------- CPU MODE ---------------------------------------

echo [OK] CPU-only mode.
echo [OK] Main dependencies are present.

echo.
echo Selected audio track : !AUDIO_TRACK!
echo Output folder        : "%OUT%"
echo.

rem ----------------------------- COUNTING ----------------------------------------

set /a TOTAL=0
set /a INDEX=0
set /a SUCCESS=0
set /a FAILED=0
set /a SKIPPED=0
set "ABORT_ALL=0"

for %%F in ("%ROOT%*.mkv") do set /a TOTAL+=1

echo !TOTAL! MKV file(s) found.
echo.

rem ------------------------------ CONVERSION --------------------------------------

for %%F in ("%ROOT%*.mkv") do (
    set /a INDEX+=1
    call :PROCESS "%%~fF"
    if "!ABORT_ALL!"=="1" goto :FINISH
)

goto :FINISH


rem =============================================================================
rem                               PROCESSING
rem =============================================================================

:PROCESS
set "INPUT=%~1"
set "NAME=%~nx1"
set "BASE=%~n1"
set "JOB=job_!INDEX!"
set "WAV=%TMP%\!JOB!.wav"
set "M2V=%TMP%\!JOB!.m2v"
set "ADS=%TMP%\!JOB!.ads"
set "MUX=%TMP%\!JOB!.mux"
set "PSS_TMP=%TMP%\!JOB!.pss"
set "PS2LOG=%TMP%\!JOB!_ps2str.log"
set "OUTPUT=%OUT%\!BASE!.pss"

echo.
echo ===============================================================================
echo [!INDEX!/!TOTAL!] !NAME!
echo ===============================================================================

>>"%LOG%" echo.
>>"%LOG%" echo [!INDEX!/!TOTAL!] !NAME!

rem Note: avoid the ! character in filenames if possible,
rem because this batch uses DelayedExpansion. No FINDSTR test is performed here.

if exist "!OUTPUT!" (
    if "!OVERWRITE!"=="0" (
        echo [SKIP] Output already exists:
        echo        "!OUTPUT!"
        >>"%LOG%" echo SKIP: output already exists.
        set /a SKIPPED+=1
        exit /b
    )
)

rem Do NOT delete WAV/M2V here: they may come from the previous batch
rem and may be recoverable. Only later-stage temporary files are cleaned.
del /q "!ADS!" "!MUX!" "!PSS_TMP!" "!PS2LOG!" "%TMP%\!JOB!_duration.txt" "%TMP%\!JOB!_field_order.txt" "%TMP%\!JOB!_recover_*.txt" >nul 2>&1

rem ------------------------- DURATION / PSBBN BITRATE ---------------------------

set "DURATION="
set "DURFILE=%TMP%\!JOB!_duration.txt"

rem Robust method: write ffprobe output to a temporary file.
rem This avoids CMD quoting issues with FOR /F and paths containing spaces.
"%FFPROBE%" -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "!INPUT!" > "!DURFILE!" 2>>"%LOG%"

if errorlevel 1 (
    echo [ERROR] ffprobe could not read this file.
    >>"%LOG%" echo FAILED: ffprobe duration read error.
    if exist "!DURFILE!" del /q "!DURFILE!" >nul 2>&1
    set /a FAILED+=1
    exit /b
)

if exist "!DURFILE!" (
    set /p "DURATION="<"!DURFILE!"
    del /q "!DURFILE!" >nul 2>&1
)

if not defined DURATION (
    echo [ERROR] Could not determine duration with ffprobe.
    >>"%LOG%" echo FAILED: duration not found.
    set /a FAILED+=1
    exit /b
)

set "SECONDS="
for /f "tokens=1 delims=." %%S in ("!DURATION!") do set "SECONDS=%%S"

if not defined SECONDS (
    echo [ERROR] Invalid duration: !DURATION!
    >>"%LOG%" echo FAILED: invalid duration.
    set /a FAILED+=1
    exit /b
)

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

echo Approx. duration     : !MINUTES! minute(s)
echo Bitrate MPEG-2     : !BITRATE! kb/s
>>"%LOG%" echo Duration=!DURATION! sec ; minutes=!MINUTES! ; bitrate=!BITRATE! kb/s

rem ---------------------------- INTERLACING --------------------------------------

set "FIELD_ORDER="
set "FIELDFILE=%TMP%\!JOB!_field_order.txt"

"%FFPROBE%" -v error -select_streams v:0 -show_entries stream=field_order -of default=nw=1:nk=1 "!INPUT!" > "!FIELDFILE!" 2>>"%LOG%"
if exist "!FIELDFILE!" (
    set /p "FIELD_ORDER="<"!FIELDFILE!"
    del /q "!FIELDFILE!" >nul 2>&1
)

set "INTERLACE_OPTS="
if /i "!FIELD_ORDER!"=="progressive" (
    echo Source             : progressive
) else (
    set "INTERLACE_OPTS=-flags +ilme+ildct -field_order tt"
    if defined FIELD_ORDER (
        echo Source             : !FIELD_ORDER! ^(interlaced output^)
    ) else (
        echo Source             : unknown order ^(PSBBN uses TFF interlacing^)
    )
)

rem ------------------------- TEMPORARY RECOVERY --------------------------------

set "REUSE_OK=0"
if "!RECOVER_TEMP!"=="1" (
    call :CHECK_RECOVERY
)

if "!REUSE_OK!"=="1" (
    echo.
    echo [RECOVERY] Complete WAV + M2V already found for this file.
    echo            Steps [1/4] and [2/4] will not be rebuilt.
    >>"%LOG%" echo RECOVERY: WAV + M2V reused.
) else (
    rem If old temporary files are missing or incomplete, start over cleanly.
    del /q "!WAV!" "!M2V!" >nul 2>&1
)

if "!REUSE_OK!"=="0" (
    rem ------------------------------- AUDIO -----------------------------------------

    echo.
    echo [1/4] Extracting 48 kHz stereo WAV audio...

    set "GUESS_LAYOUT_OPT="
    "%FFMPEG%" -hide_banner -h full 2>&1 | findstr /i /c:"guess_layout_max" >nul
    if not errorlevel 1 set "GUESS_LAYOUT_OPT=-guess_layout_max 0"

    "%FFMPEG%" -y -hide_banner -loglevel error -stats ^
        !GUESS_LAYOUT_OPT! ^
        -i "!INPUT!" ^
        -af "aresample=48000,volume=3.874dB" ^
        -map 0:a:!AUDIO_TRACK! ^
        -vn ^
        -ac 2 ^
        -c:a pcm_s16le ^
        -map_metadata -1 ^
        "!WAV!"

    if errorlevel 1 (
        echo.
        echo [ERROR] Audio extraction failed.
        echo Check AUDIO_TRACK at the top of the BAT if the MKV does not contain that track.
        >>"%LOG%" echo FAILED: audio extraction.
        call :CLEAN_JOB
        set /a FAILED+=1
        exit /b
    )

    if not exist "!WAV!" (
        echo [ERROR] Temporary WAV file was not created.
        >>"%LOG%" echo FAILED: WAV missing.
        call :CLEAN_JOB
        set /a FAILED+=1
        exit /b
    )

    rem ------------------------------- VIDEO -----------------------------------------

    echo.
    echo [2/4] Encoding PSBBN MPEG-2 video 640x480 / 29.97 fps...

    call :ENCODE_VIDEO

    if errorlevel 1 (
        echo.
        echo [ERROR] Video encoding failed.
        >>"%LOG%" echo FAILED: video encoding.
        call :CLEAN_JOB
        set /a FAILED+=1
        exit /b
    )

)

rem ------------------------- 2 GiB LIMIT CHECK ----------------------------------

if exist "%POWERSHELL%" (
    set "PSS_SIZE_WAV=!WAV!"
    set "PSS_SIZE_M2V=!M2V!"
    "%POWERSHELL%" -NoProfile -Command ^
      "$a=(Get-Item -LiteralPath $env:PSS_SIZE_WAV).Length; $v=(Get-Item -LiteralPath $env:PSS_SIZE_M2V).Length; if(($a+$v) -gt 2131755008){exit 2}else{exit 0}"
    set "SIZE_RC=!errorlevel!"

    if "!SIZE_RC!"=="2" (
        echo.
        echo [WARNING] WAV + M2V may exceed the PSBBN size limit.
        set /a BITRATE-=200

        if !BITRATE! LSS 200 (
            echo [ERROR] Bitrate cannot be reduced any further safely.
            >>"%LOG%" echo FAILED: excessive size.
            call :CLEAN_JOB
            set /a FAILED+=1
            exit /b
        )

        echo Retrying at !BITRATE! kb/s...
        >>"%LOG%" echo Re-encode due to size: !BITRATE! kb/s
        del /q "!M2V!" >nul 2>&1

        call :ENCODE_VIDEO

        if errorlevel 1 (
            echo [ERROR] Second MPEG-2 pass failed.
            >>"%LOG%" echo FAILED: second video pass.
            call :CLEAN_JOB
            set /a FAILED+=1
            exit /b
        )

        set "PSS_SIZE_WAV=!WAV!"
        set "PSS_SIZE_M2V=!M2V!"
        "%POWERSHELL%" -NoProfile -Command ^
          "$a=(Get-Item -LiteralPath $env:PSS_SIZE_WAV).Length; $v=(Get-Item -LiteralPath $env:PSS_SIZE_M2V).Length; if(($a+$v) -gt 2131755008){exit 2}else{exit 0}"
        set "SIZE_RC=!errorlevel!"

        if "!SIZE_RC!"=="2" (
            echo [ERROR] The movie is still too large after the second pass.
            echo         Conversion aborted to avoid an oversized PSS/PSM.
            >>"%LOG%" echo FAILED: still too large after second pass.
            call :CLEAN_JOB
            set /a FAILED+=1
            exit /b
        )
    ) else if not "!SIZE_RC!"=="0" (
        echo [WARNING] PowerShell size check failed ^(code !SIZE_RC!^).
        echo           Conversion will continue without this check.
        >>"%LOG%" echo WARNING: PowerShell size check code !SIZE_RC!.
    )
) else (
    echo [WARNING] PowerShell not found: 2 GiB check skipped.
)

rem ----------------------------- WAV -> ADS ------------------------------------

echo.
echo [3/4] Converting WAV audio ^> ADS with ps2str...

rem PSBBN under WSL calls the Win32 ps2str using absolute Windows paths.
rem The same method is used here.
del /q "!PS2LOG!" >nul 2>&1
"%PS2STR%" encode -v "!WAV!" "!ADS!" > "!PS2LOG!" 2>&1
set "PS2RC=!errorlevel!"

if exist "!PS2LOG!" type "!PS2LOG!" >> "%LOG%"

if not "!PS2RC!"=="0" (
    echo.
    echo [ERROR] ps2str encode returned code !PS2RC!.
    echo.
    if exist "!PS2LOG!" (
        echo ----- ps2str output -----
        type "!PS2LOG!"
        echo ----------------------------
    )
    echo.
    echo WAV and M2V files are kept for troubleshooting:
    echo "!WAV!"
    echo "!M2V!"
    echo.
    echo The batch stops here to avoid processing the remaining files unnecessarily.
    >>"%LOG%" echo FATAL FAILURE: ps2str encode code !PS2RC!. Temporary files kept.
    set /a FAILED+=1
    set "ABORT_ALL=1"
    exit /b
)

if not exist "!ADS!" (
    echo [ERROR] ps2str returned 0 but the ADS file is missing.
    echo Temporary files are kept for troubleshooting.
    >>"%LOG%" echo FATAL FAILURE: ADS missing despite exit code 0.
    set /a FAILED+=1
    set "ABORT_ALL=1"
    exit /b
)

rem The WAV is no longer needed after a valid ADS has been created.
del /q "!WAV!" "!PS2LOG!" >nul 2>&1

rem ----------------------------- MUX -> PSS ------------------------------------

echo.
echo [4/4] Multiplexing M2V + ADS ^> PSS...

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

if exist "!PS2LOG!" type "!PS2LOG!" >> "%LOG%"

if not "!PS2RC!"=="0" (
    echo.
    echo [ERROR] ps2str mux returned code !PS2RC!.
    if exist "!PS2LOG!" (
        echo ----- ps2str output -----
        type "!PS2LOG!"
        echo ----------------------------
    )
    echo M2V, ADS and MUX files are kept in _pss_tmp.
    >>"%LOG%" echo FATAL FAILURE: ps2str mux code !PS2RC!. Temporary files kept.
    set /a FAILED+=1
    set "ABORT_ALL=1"
    exit /b
)

if not exist "!PSS_TMP!" (
    echo [ERROR] Temporary PSS file is missing after muxing.
    >>"%LOG%" echo FAILED: PSS missing.
    call :CLEAN_JOB
    set /a FAILED+=1
    exit /b
)

move /y "!PSS_TMP!" "!OUTPUT!" >nul

if errorlevel 1 (
    echo [ERROR] Could not move the final PSS to:
    echo "!OUTPUT!"
    >>"%LOG%" echo FAILED: output move.
    call :CLEAN_JOB
    set /a FAILED+=1
    exit /b
)

call :CLEAN_JOB

echo.
echo [OK] Completed:
echo "!OUTPUT!"
>>"%LOG%" echo OK : !OUTPUT!
set /a SUCCESS+=1
exit /b


rem =============================================================================
rem                         VIDEO ENCODING SUBROUTINE
rem =============================================================================

:ENCODE_VIDEO

del /q "!M2V!" >nul 2>&1

echo FFmpeg CPU encoding ^(PSBBN method^)...
>>"%LOG%" echo CPU MPEG-2 encoding bitrate=!BITRATE! kb/s

"%FFMPEG%" -y -hide_banner -loglevel error -stats ^
    -i "!INPUT!" ^
    -vf "fps=30000/1001,scale=iw*sar:ih,setsar=1,scale=640:480:force_original_aspect_ratio=decrease,pad=640:480:(ow-iw)/2:(oh-ih)/2,format=yuv420p" ^
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


rem =============================================================================
rem                    RECOVERABLE TEMP FILE CHECK
rem =============================================================================

:CHECK_RECOVERY
set "REUSE_OK=0"

if not exist "!WAV!" exit /b 0
if not exist "!M2V!" exit /b 0

set "REC_WAV_DUR="
set "REC_FRAMES="
set "REC_WAV_FILE=%TMP%\!JOB!_recover_wav.txt"
set "REC_FRAME_FILE=%TMP%\!JOB!_recover_frames.txt"

"%FFPROBE%" -v error -show_entries format=duration -of default=nw=1:nk=1 "!WAV!" > "!REC_WAV_FILE!" 2>nul
if exist "!REC_WAV_FILE!" set /p "REC_WAV_DUR="<"!REC_WAV_FILE!"

rem Counting M2V frames is slower than a simple file-size check,
rem but prevents reuse of a file that was interrupted mid-encode.
"%FFPROBE%" -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of default=nw=1:nk=1 "!M2V!" > "!REC_FRAME_FILE!" 2>nul
if exist "!REC_FRAME_FILE!" set /p "REC_FRAMES="<"!REC_FRAME_FILE!"

del /q "!REC_WAV_FILE!" "!REC_FRAME_FILE!" >nul 2>&1

if not defined REC_WAV_DUR exit /b 0
if not defined REC_FRAMES exit /b 0

set "REC_SOURCE_SECONDS=!SECONDS!"
set "REC_WAV_SECONDS=!REC_WAV_DUR!"
set "REC_FRAME_COUNT=!REC_FRAMES!"

rem The WAV must cover almost the entire source and the M2V must contain
rem at least ~99 %% of the expected frame count at 29.97 fps.
"%POWERSHELL%" -NoProfile -Command ^
  "try {$s=[double]$env:REC_SOURCE_SECONDS; $w=[double]$env:REC_WAV_SECONDS; $f=[double]$env:REC_FRAME_COUNT; if(($w -ge ($s-3)) -and ($f -ge ($s*29.7))){exit 0}else{exit 1}} catch {exit 1}" >nul 2>&1

if errorlevel 1 (
    echo [RECOVERY] Temporary files found but incomplete: rebuilding is required.
    >>"%LOG%" echo RECOVERY: incomplete temporary files, rebuilding.
    exit /b 0
)

set "REUSE_OK=1"
exit /b 0

rem =============================================================================
rem                                CLEANUP
rem =============================================================================

:CLEAN_JOB
del /q "!WAV!" "!M2V!" "!ADS!" "!MUX!" "!PSS_TMP!" "!PS2LOG!" "%TMP%\!JOB!_duration.txt" "%TMP%\!JOB!_field_order.txt" "%TMP%\!JOB!_recover_*.txt" >nul 2>&1
exit /b


rem =============================================================================
rem                                  FINISH
rem =============================================================================

:FINISH
echo.
echo ===============================================================================
echo                                 FINISHED
echo ===============================================================================
echo.
echo Successful : !SUCCESS!
echo Skipped    : !SKIPPED!
echo Failed     : !FAILED!
echo Total    : !TOTAL!
echo.
echo PSS files are located in:
echo "%OUT%"
echo.
echo Log file:
echo "%LOG%"
echo.

>>"%LOG%" echo.
>>"%LOG%" echo ===============================================================
>>"%LOG%" echo Finished: %DATE% %TIME%
>>"%LOG%" echo Successful=!SUCCESS! Skipped=!SKIPPED! Failed=!FAILED! Total=!TOTAL!
>>"%LOG%" echo ===============================================================

if not "!ABORT_ALL!"=="1" rd "%TMP%" >nul 2>&1

pause
exit /b 0


:FATAL
echo.
echo The batch cannot continue.
echo.
pause
exit /b 1
