# 🔍 Диагностика Wishlist API

## Проблема
Добавление объявления в wishlist остается только локальным, не отправляется на API.

## Что было исправлено

### 1. ✅ ApiService.post() - передача токена
**Файл:** `lib/services/api_service.dart` (строка 150)
```dart
// ❌ ДО:
() => _postRequest(endpoint, body, null)

// ✅ ПОСЛЕ:
() => _postRequest(endpoint, body, token)
```

### 2. ✅ WishlistBloc - удаление кеша токена  
**Файл:** `lib/blocs/wishlist/wishlist_bloc.dart`
- Удалено кеширование токена `String? _token`
- Теперь получаем свежий токен из Hive каждый раз

### 3. ✅ Расширенное логирование
**Файл:** `lib/services/api_service.dart` (_postRequest)
- Логирует полный запрос с заголовками и телом
- Логирует ответ со статус-кодом и телом

## Как отлаживать

### Шаг 1: Запустить приложение
```bash
flutter run
```

### Шаг 2: Открыть DevTools или смотреть логи в консоли
```bash
flutter logs
```

### Шаг 3: Клацнуть на сердечко (добавить в wishlist)

### Шаг 4: Проверить логи на предмет:

#### ✅ Если всё работает правильно, вы должны видеть:

```
🎯 WishlistBloc._onAddToWishlist: START добавляем advertId=123
✅ WishlistBloc: Локальное хранилище обновлено, ID: 123
📡 WishlistBloc: Отправляем POST запрос на /me/wishlist/add
📡 WishlistBloc: Параметры: advert_id=123, token_length=456

📤 WishlistService.addToWishlist(): Добавляем advert_id=123

═══════════════════════════════════════════════════════
📤 POST REQUEST
URL: https://dev-api.lidle.io/v1/me/wishlist/add
Token provided: true
Token preview: eyJhbGciOiJIUzI1NiIs...
Token type: JWT
Headers:
  Authorization: Bearer [HIDDEN]
  Content-Type: application/json
  Accept: application/json
Body: {advert_id: 123}
Body keys: [advert_id]
  advert_id: 123 (type: int)
═══════════════════════════════════════════════════════

📥 Response status: 200
📥 Response body: {"success":true,"message":"Объявление добавлено в список желаемых."}

✅ WishlistService.addToWishlist(): Успешно добавлено, ответ: {success: true, ...}
✅ WishlistBloc: Сервер подтвердил добавление объявления
```

#### ❌ Если что-то не работает:

**а) Логин не пропускает (нет токена):**
```
❌ WishlistBloc: Токен НЕ ПЕРЕДАН! Не могу отправить запрос на сервер
```
→ Нужно авторизоваться сначала

**б) Токен пустой:**
```
⚠️ WishlistBloc._getToken(): Токен НЕ НАЙДЕН в Hive!
```
→ Проверить, сохраняется ли токен после логина

**в) Ошибка 401:**
```
📥 Response status: 401
📥 Response body: {"success":false,"message":"Неверный токен"}
```
→ Токен истёк, нужен refresh

**г) Ошибка 422 (уже в wishlist):**
```
📥 Response status: 422
📥 Response body: {"success":false,"message":"Объявление уже в списке желаемых."}
```
→ Объявление уже добавлено

## Ключевые моменты

1. **Токен ОБЯЗАТЕЛЬНО должен быть в Hive** перед попыткой добавления
2. **Authorization header ОБЯЗАТЕЛЬНО должен быть** в запросе
3. **Тело запроса ОБЯЗАТЕЛЬНО должно содержать** `{"advert_id": int}`
4. **Ответ 200-299** = успех
5. **Ответ 401** = токен истёк, нужен refresh
6. **Ответ 422** = объявление уже в wishlist

## Возможные причины если не работает

1. ❌ Не авторизован → Токен не в Hive
2. ❌ Токен истёк → Сервер вернет 401
3. ❌ Объявление уже в wishlist → Сервер вернет 422
4. ❌ Нет интернета → Timeout или ClientException
5. ❌ Ошибка на сервере → Status 500

## Следующие шаги

1. Запустить приложение
2. Авторизоваться
3. Отметить логирование в консоли при добавлении в wishlist
4. Проверить, отправляется ли POST запрос
5. Проверить ответ сервера
