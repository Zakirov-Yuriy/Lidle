# Скрипт для замены всех print() на log.d() в Dart файлах

$libPath = "lib"
$dartFiles = Get-ChildItem -Path $libPath -Recurse -Filter "*.dart"

$replacements = @(
    @{ Find = "print('✅"; Replace = "log.i('" },
    @{ Find = "print('💚"; Replace = "log.i('" },
    @{ Find = "print('✨"; Replace = "log.i('" },
    @{ Find = "print('❌"; Replace = "log.e('" },
    @{ Find = "print('⚠️"; Replace = "log.w('" },
    @{ Find = "print('🔔"; Replace = "log.d('" },
    @{ Find = "print('🌙"; Replace = "log.d('" },
    @{ Find = "print('📱"; Replace = "log.d('" },
    @{ Find = "print('🌐"; Replace = "log.d('" },
    @{ Find = "print('💾"; Replace = "log.d('" },
    @{ Find = "print('📖"; Replace = "log.d('" },
    @{ Find = "print('🔍"; Replace = "log.d('" },
    @{ Find = "print('🏗️"; Replace = "log.d('" },
    @{ Find = "print('🎧"; Replace = "log.d('" },
    @{ Find = "print('⏱️"; Replace = "log.d('" },
    @{ Find = "print('═"; Replace = "log.d('" },
    @{ Find = "print('🔄"; Replace = "log.d('" },
    @{ Find = "print('💔"; Replace = "log.i('" },
    @{ Find = "print('💗"; Replace = "log.i('" },
    @{ Find = "print('"; Replace = "log.d('" }  # Last one - catch all remaining
)

$loggerImport = "import 'package:lidle/core/logger.dart';"
$filesToUpdate = @()

Write-Host "Обрабатываю файлы..." -ForegroundColor Cyan

foreach ($file in $dartFiles) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    
    # Проверяем, есть ли print( в файле
    if ($content -cmatch "print\(") {
        $filesToUpdate += $file.FullName
        
        # Добавляем импорт если его нет
        if (-not ($content -cmatch "import 'package:lidle/core/logger.dart'")) {
            # Находим позицию для вставки импорта (после существующих импортов)
            $lines = $content -split "`n"
            $importIndex = 0
            
            foreach ($i in 0..($lines.Count - 1)) {
                if ($lines[$i] -match "^import ") {
                    $importIndex = $i + 1
                }
            }
            
            if ($importIndex -gt 0) {
                # Вставляем импорт после последнего существующего импорта
                $lines = $lines[0..($importIndex-1)] + $loggerImport + $lines[$importIndex..($lines.Count-1)]
                $content = $lines -join "`n"
            } else {
                # Если импортов нет, добавляем в начало (после комментариев)
                $content = $loggerImport + "`n" + $content
            }
        }
        
        # Делаем замены print()
        foreach ($replacement in $replacements) {
            $content = $content -replace [regex]::Escape($replacement.Find), $replacement.Replace
        }
        
        # Записываем обратно
        Set-Content $file.FullName $content -Encoding UTF8
        Write-Host "✓ Обновлен: $($file.Name)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Готово! Обновлено файлов: $($filesToUpdate.Count)" -ForegroundColor Green
