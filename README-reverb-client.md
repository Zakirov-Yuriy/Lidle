# Клиентские изменения для пуш-уведомлений через Reverb (прод)

Серверная часть на проде уже полностью настроена и проверена (Reverb на 10.10.10.20,
nginx :2080, edge api.lidle.io пропускает WebSocket, BROADCAST_CONNECTION=reverb,
воркер на очереди default публикует бродкасты). Осталось собрать и выкатить клиент
с этими файлами.

## Что менять — 4 файла (положить поверх соответствующих путей в клиентском репо)

- lib/core/config/app_config.dart
    Прод-ветка Reverb: _reverbKey = 'f58e60af3c7f0cd783162dd1bfe35a67'
    (host api.lidle.io, порт 443, wss, broadcastAuthUrl .../v1/broadcasting/auth).
    ВАЖНО: это и есть единственное изменение в этом файле по сравнению с плейсхолдером
    'PROD_REVERB_APP_KEY'. Дев-ветка не тронута.
- lib/services/reverb_connection.dart
    Сырой Pusher-WS клиент: wss://api.lidle.io/app/<key>?protocol=7...,
    pusher:ping/pong, приватный канал user.{id}, авторизация через broadcastAuthUrl (Bearer Sanctum).
- lib/services/websocket_service.dart
    Обёртка: слушает события feed.import.done и moderation.ai.done, дёргает колбэки.
- lib/services/ws_foreground_service.dart
    Фоновый сервис поддержания WS-соединения.

## Как собрать
Обычная сборка Flutter под прод-окружение (environment=prod), как вы обычно релизите:
- Android:  flutter build apk --release   (или appbundle)
- iOS:      flutter build ipa --release
Проверьте, что окружение приложения = prod (AppConfig.initialize(environmentValue: 'prod')).

## Финальный тест на телефоне
1. Поставить свежую сборку, залогиниться пользователем 139.
2. На проде (ssh nodeadmin@10.10.10.20, /var/www/back) выполнить:
     sudo -u www-data php artisan tinker --execute="event(new App\\Events\\Adverts\\FeedImportedEvent(139, 1));"
3. На устройстве должен прийти пуш «Объявления из фида готовы».
   Если нужно проверить второй тип события:
     sudo -u www-data php artisan tinker --execute="event(new App\\Events\\Adverts\\ModerationAiCompletedEvent(139));"
   (проверьте сигнатуру конструктора ModerationAiCompletedEvent в вашем коде).

## Диагностика, если пуш не пришёл
- С компьютера проверить, что WS проходит снаружи (должно быть 101 Switching Protocols):
    curl -s -i -N --http1.1 -H "Connection: Upgrade" -H "Upgrade: websocket" \
      -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" -H "Sec-WebSocket-Version: 13" \
      "https://api.lidle.io/app/f58e60af3c7f0cd783162dd1bfe35a67?protocol=7&client=js&version=8.0" \
      --max-time 8 | head -20
- На проде посмотреть, что бродкаст не падает: tail -f storage/logs/laravel.log и storage/logs/reverb.log.
- Убедиться, что приватный канал user.{id} авторизуется: клиент должен слать Bearer-токен на
  https://api.lidle.io/v1/broadcasting/auth и получать 200.
