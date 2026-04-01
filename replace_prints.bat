@echo off
REM Batch script to replace all print( with log.d( in Dart files

setlocal enabledelayedexpansion
set "count=0"

echo Searching for Dart files...

for /r lib %%F in (*.dart) do (
    findstr /M "print(" "%%F" >nul
    if !errorlevel! equ 0 (
        echo Processing: %%F
        
        REM Use PowerShell for file operations (more reliable for UTF-8)
        powershell -NoProfile -Command "^
        $file = '%%F'; ^
        $content = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8); ^
        if ($content -match 'import.*lidle/core/logger') { ^
            Write-Host 'Already has logger import'; ^
        } else { ^
            $lines = $content -split '`n'; ^
            $insertIndex = 0; ^
            for ($i = 0; $i -lt $lines.Count; $i++) { ^
                if ($lines[$i] -match '^import ') { $insertIndex = $i + 1 } ^
            } ^
            if ($insertIndex -eq 0) { ^
                $content = \"import 'package:lidle/core/logger.dart';`n\" + $content; ^
            } else { ^
                $newLines = @($lines[0..($insertIndex-1)]) + @(\"import 'package:lidle/core/logger.dart';\") + @($lines[$insertIndex..($lines.Count-1)]); ^
                $content = $newLines -join \"`n\"; ^
            } ^
        } ^
        $content = $content -replace 'print\(', 'log.d('; ^
        [System.IO.File]::WriteAllText($file, $content, [System.Text.Encoding]::UTF8); ^
        Write-Host 'Updated %%F'; ^
        "
        
        set /a count=!count!+1
    )
)

echo.
echo Done! Processed %count% files
pause
