#!/bin/bash
# Скрипт для запуска приложения и просмотра логов фильтрации

cd "c:\Users\zakco\Documents\VS code\Lidle"

# Запускаем приложение и фильтруем логи только для фильтрации
flutter run -d emulator-5554 2>&1 | grep -E "ХАРАКТЕРИСТИКИ|FILTER BY|🔍🔍|ОЖИДАЕМЫЕ|ОСНОВНОЕ|Все значения|ВСЕ значения"
