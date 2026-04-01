# Simplified script to replace all print() with log in Dart files
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$libPath = "lib"
$dartFiles = Get-ChildItem -Path $libPath -Recurse -Filter "*.dart"

$loggerImport = "import 'package:lidle/core/logger.dart';"
$filesUpdated = 0

Write-Host "Starting replacement of print() with log in Dart files..." -ForegroundColor Cyan

foreach ($file in $dartFiles) {
    try {
        $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
        
        # Check if file contains print(
        if ($content -match "print\(") {
            # Add import if missing
            if (-not ($content -match "import 'package:lidle/core/logger.dart'")) {
                $lines = $content -split "`n"
                $lastImportIndex = -1
                
                for ($i = 0; $i -lt $lines.Count; $i++) {
                    if ($lines[$i] -match "^import ") {
                        $lastImportIndex = $i
                    }
                }
                
                if ($lastImportIndex -ge 0) {
                    # Insert after last import
                    $lines = @($lines[0..$lastImportIndex]) + @($loggerImport) + @($lines[($lastImportIndex+1)..($lines.Count-1)])
                    $content = $lines -join "`n"
                } else {
                    # Prepend if no imports found
                    $content = $loggerImport + "`n" + $content
                }
            }
            
            # Replace all print( with log.d(
            $originalLength = $content.Length
            $content = $content -replace 'print\(', 'log.d('
            
            if ($content.Length -ne $originalLength) {
                # Write back to file
                [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.Encoding]::UTF8)
                $filesUpdated++
                Write-Host "✓ Updated: $($file.Name)" -ForegroundColor Green
            }
        }
    }
    catch {
        Write-Host "✗ Error processing $($file.Name): $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Done! Updated $filesUpdated files" -ForegroundColor Green
