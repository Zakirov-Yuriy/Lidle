![Bot Logo](assets/images/Lidle.png)

# LIDLE

LIDLE - современное кроссплатформенное мобильное приложение маркетплейса на базе Flutter, предназначенное для удобной покупки и продажи автомобилей, недвижимости и других товаров/услуг. Приложение предоставляет интуитивный интерфейс для просмотра объявлений, управления личным профилем, публикации объявлений и обработки всех аспектов аутентификации пользователей.


# Аутентификация и безопасность
- Регистрация пользователей с email верификацией
- Авторизация и управление сессиями
- Восстановление пароля через email
- Безопасное хранение данных пользователя

# Маркетплейс объявлений
- Просмотр объявлений об автомобилях и недвижимости
- Детальная информация о товарах/услугах
- Публикация новых объявлений
- Управление собственными объявлениями

# Категории и навигация
- Широкий спектр категорий товаров и услуг (Недвижимость, Авто и мото, Работа, Подработка)
- Подкатегории для детальной фильтрации
- Интуитивная навигация между разделами
- Быстрый доступ к популярным категориям
- Специальная навигация для категории "Недвижимость" на экран RealEstateListingsScreen

# Профиль пользователя
- Личная панель управления
- Список избранных объявлений
- История просмотров и взаимодействий
- Настройки профиля

# Поиск и фильтры
- Продвинутый поиск по ключевым словам
- Множественные фильтры (цена, локация, состояние)
- Сортировка результатов
- Сохранение поисковых запросов

# Локальное хранилище
- Оффлайн доступ к данным
- Кэширование объявлений и изображений
- Синхронизация данных при подключении

# Адаптивный дизайн
- Оптимизация для различных размеров экранов
- Кастомные UI компоненты
- Поддержка темной и светлой темы
- Плавная анимация и переходы

# Быстрый старт

# Предварительные требования
- **Flutter SDK**: ^3.9.2 [Установка](https://flutter.dev/docs/get-started/install)
- **Dart SDK**: включен во Flutter
- **IDE**: Android Studio или VS Code с плагином Flutter
- **Устройство**: Android/iOS эмулятор или физическое устройство

# Установка и запуск

1. **Клонируйте репозиторий:**
   ```bash
   git clone https://github.com/Zakirov-Yuriy/Lidle.git
   cd lidle
   ```

2. **Установите зависимости:**
   ```bash
   flutter pub get
   ```

3. **Проверьте установку:**
   ```bash
   flutter doctor
   ```

4. **Запустите приложение:**
   ```bash
   flutter run
   ```

# Сборка для продакшена

**Android APK:**
```bash
flutter build apk --release
```

**iOS (на macOS):**
```bash
flutter build ios --release
```

# Архитектура

LIDLE следует подходу чистой архитектуры с использованием паттерна BLoC (Business Logic Component) для управления состоянием.

# Структура проекта

Проект LIDLE организован согласно принципам чистой архитектуры Flutter с четким разделением ответственности. Ниже представлена полная структура проекта с подробными описаниями.



# Директория lib/ (Основной код приложения)

# Слой бизнес-логики (BLoC)
```
lib/blocs/
├── auth/                      # Управление аутентификацией
│   ├── auth_bloc.dart         # Логика входа/регистрации/восстановления
│   ├── auth_event.dart        # События аутентификации
│   └── auth_state.dart        # Состояния аутентификации
├── listings/                  # Управление объявлениями
│   ├── listings_bloc.dart     # Получение, фильтрация, сортировка объявлений
│   ├── listings_event.dart    # События объявлений
│   └── listings_state.dart    # Состояния объявлений
├── navigation/                # Навигация приложения
│   ├── navigation_bloc.dart   # Состояние нижней навигации
│   ├── navigation_event.dart  # События навигации
│   └── navigation_state.dart  # Состояния навигации
├── profile/                   # Профиль пользователя
│   ├── profile_bloc.dart      # Управление данными профиля
│   ├── profile_event.dart     # События профиля
│   └── profile_state.dart     # Состояния профиля
└── password_recovery/         # Восстановление пароля
    ├── password_recovery_bloc.dart
    ├── password_recovery_event.dart
    └── password_recovery_state.dart
```

# Модели данных
```
lib/models/
├── home_models.dart           # Модели для главной страницы
│   ├── Category              # Категории товаров/услуг
│   ├── Listing               # Структура объявления
│   ├── User                  # Данные пользователя
│   └── Filter                # Параметры фильтрации
└── filter_models.dart        # Модели фильтров (сгенерированные с Freezed)
    ├── filter_models.freezed.dart
    └── filter_models.g.dart
```

#  Пользовательский интерфейс (Pages)
```
lib/pages/
├── auth/                                 # Аутентификация
│   ├── sign_in_screen.dart               # Вход в приложение
│   ├── register_screen.dart              # Регистрация нового пользователя
│   ├── register_verify_screen.dart       # Подтверждение email
│   ├── account_recovery.dart             # Запрос восстановления пароля
│   ├── account_recovery_code.dart        # Ввод кода восстановления
│   └── account_recovery_new_password.dart # Установка нового пароля
├── dynamic_filter/                       # Динамические фильтры
│   └── dynamic_filter.dart               # Динамический фильтр
├── favorites_screen.dart                 # Избранные объявления
├── filters_screen.dart                   # Настройки фильтров
├── full_category_screen/                 # Полные экраны категорий
│   ├── commercial_property/              # Коммерческая недвижимость
│   │   ├── filters_commercial_property_sell_screen.dart
│   │   ├── filters_coworking_screen.dart
│   │   ├── filters_office_rent_screen.dart
│   │   ├── filters_office_sell_screen.dart
│   │   └── full_real_estate_commercial_property_screen.dart
│   ├── daily_rent/                       # Посуточная аренда
│   │   ├── daily_hourly_apartment_rent_screen.dart
│   │   ├── daily_hourly_hostel_rent_screen.dart
│   │   ├── daily_hourly_hotel_rent_screen.dart
│   │   ├── daily_hourly_rent_screen.dart
│   │   ├── daily_hourly_rooms_rent_screen.dart
│   │   └── daily_hourly_tour_operator_rent_screen.dart
│   ├── filters_real_estate_rent_listings_screen.dart
│   ├── foreign_real_estate/              # Заграничная недвижимость
│   │   ├── filters_foreign_apartment_rent_screen.dart
│   │   ├── filters_foreign_apartment_sell_screen.dart
│   │   ├── filters_foreign_house_rent_screen.dart
│   │   └── filters_foreign_house_sell_screen.dart
│   ├── full_category_screen.dart
│   ├── full_real_estate_apartments_screen.dart
│   ├── full_real_estate_subcategories_screen.dart
│   ├── garages/                          # Гаражи
│   │   ├── filters_garage_rent_screen.dart
│   │   └── filters_garage_sell_screen.dart
│   ├── houses/                           # Дома
│   │   ├── filters_houses_rent_screen.dart
│   │   └── filters_houses_sell_screen.dart
│   ├── intermediate_filters_screen.dart
│   ├── land/                             # Земля
│   │   ├── filters_land_rent_screen.dart
│   │   └── filters_land_sell_screen.dart
│   ├── map_screen.dart                   # Карта с объявлениями
│   ├── mini_property_details_screen.dart
│   ├── mini_property_filtered_details_screen.dart
│   ├── property_details_screen.dart
│   ├── real_estate_filtered_screen.dart
│   ├── real_estate_full_apartments_screen.dart
│   ├── real_estate_full_filters_screen.dart
│   ├── real_estate_full_subcategories_screen.dart
│   ├── real_estate_listings_screen.dart
│   ├── real_estate_rent_listings_screen.dart
│   ├── real_estate_rent_subfilters_screen.dart
│   ├── real_estate_subfilters_screen.dart
│   ├── rooms/                            # Комнаты
│   │   ├── filters_room_rent_screen.dart
│   │   └── filters_room_sell_screen.dart
│   ├── seller_profile_screen.dart
│   └── real_estate_rent_listings_screen.dart
├── home_page.dart                        # Главная страница с объявлениями
├── my_purchases_screen.dart              # Мои покупки
├── profile_dashboard.dart                # Панель управления профилем
├── profile_menu_screen.dart              # Меню настроек
└── add_listing/                          # Создание объявлений
    ├── add_listing_screen.dart
    ├── category_selection_screen.dart
    ├── publication_success_screen.dart
    ├── publication_tariff_screen.dart
    ├── real_estate_apartments_screen.dart
    ├── real_estate_subcategories_screen.dart
    ├── apartments/
    │   ├── add_apartment_rent_screen.dart
    │   └── add_apartment_sell_screen.dart
    ├── commercial_property/
    │   ├── add_commercial_rent_screen.dart
    │   ├── add_commercial_sell_screen.dart
    │   ├── add_coworking_sell_screen.dart
    │   ├── add_office_sell_screen.dart
    │   └── real_estate_commercial_property_screen.dart
    ├── daily_rent/
    │   ├── add_apartment_daily_rent_screen.dart
    │   ├── add_daily_share_sell_screen.dart
    │   ├── add_hostel_bed_rent_screen.dart
    │   ├── add_hotel_resort_rent_screen.dart
    │   ├── add_room_daily_rent_screen.dart
    │   └── add_tour_operator_offer_screen.dart
    ├── foreign_real_estate/
    │   ├── add_apartment_abroad_long_rent_screen.dart
    │   ├── add_apartment_abroad_sell_screen.dart
    │   └── add_house_abroad_long_rent_screen.dart
    ├── garages/
    │   ├── add_garage_parking_long_rent_screen.dart
    │   └── add_garage_parking_sell_screen.dart
    ├── houses/
    │   ├── add_house_rent_screen.dart
    │   └── add_house_sell_screen.dart
    ├── land/
    │   ├── add_land_rent_screen.dart
    │   └── add_land_sell_screen.dart
    └── rooms/
        ├── add_room_rent_screen.dart
        └── add_room_sell_screen.dart
```

#  Сервисы и утилиты
```
lib/services/
├── api_service.dart     # Основной API клиент
│   ├── GET/POST/PUT/DELETE запросы
│   ├── Обработка ответов сервера
│   └── Управление токенами аутентификации
└── auth_service.dart    # Сервис аутентификации
    ├── Управление сессиями
    ├── Хранение токенов
    └── Проверка авторизации
```

# Переиспользуемые компоненты (Widgets)
```
lib/widgets/
├── cards/                         # Карточки и списки
│   ├── category_card.dart         # Карточка категории с поддержкой onTap для навигации
│   └── listing_card.dart          # Карточка объявления
├── components/                    # Формы и элементы управления
│   ├── custom_button.dart         # Кастомная кнопка
│   ├── custom_checkbox.dart       # Кастомный чекбокс
│   ├── custom_error_snackbar.dart # Кастомный снекбар ошибок
│   ├── custom_switch.dart         # Кастомный переключатель
│   ├── header.dart                # Заголовок приложения
│   └── search_bar.dart            # Панель поиска
├── dialogs/                       # Диалоги и модальные окна
│   ├── city_selection_dialog.dart # Выбор города
│   ├── complaint_dialog.dart      # Диалог жалоб
│   ├── offer_price_dialog.dart    # Диалог предложения цены
│   ├── phone_dialog.dart          # Диалог телефона
│   ├── selection_dialog.dart      # Общий диалог выбора
│   ├── sort_filter_dialog.dart    # Диалог сортировки/фильтров
│   ├── street_selection_dialog.dart # Выбор улицы
│   └── surcharge_dialog.dart      # Диалог доплат
├── navigation/                    # Навигация
│   └── bottom_navigation.dart     # Нижняя панель навигации
├── selectable_button.dart         # Выбираемая кнопка
└── skeletons/                     # Скелетоны загрузки
    ├── category_card_skeleton.dart # Скелетон карточки категории
    └── listing_card_skeleton.dart  # Скелетон карточки объявления
```

# Конфигурация и утилиты
```
lib/
├── main.dart            # Точка входа приложения
│   ├── Инициализация приложения
│   ├── Настройка зависимостей
│   └── Запуск главного виджета
├── constants.dart       # Константы и тема приложения
│   ├── Цветовая палитра
│   ├── Размеры и отступы
│   └── Текстовые стили
└── hive_service.dart    # Сервис локального хранения
    ├── Инициализация Hive
    ├── Управление боксами данных
    └── Кэширование данных
```

# Платформо-специфичные директории

# Android
```
android/
├── app/
│   ├── src/main/
│   │   ├── AndroidManifest.xml    # Конфигурация приложения
│   │   ├── res/                  # Ресурсы (иконки, строки)
│   │   └── java/                 # Нативный код (при необходимости)
│   └── build.gradle.kts          # Конфигурация сборки Android
└── gradle/                       # Система сборки Gradle
```

# iOS
```
ios/
├── Runner/
│   ├── AppDelegate.swift         # Точка входа iOS приложения
│   ├── Info.plist               # Конфигурация приложения
│   └── Assets.xcassets/         # Ассеты приложения
└── Flutter/                     # Конфигурация Flutter для iOS
```

# Web
```
web/
├── index.html          # HTML шаблон веб-приложения
├── manifest.json       # Манифест PWA
└── icons/             # Иконки для различных размеров
```

#Ресурсы приложения
```
assets/
├──  Графические элементы
│   ├── logo.png/logo.svg         # Логотипы приложения
│   ├── logo_app.png              # Иконка приложения
│   └── settings.svg              # Иконки настроек
├──  Категории товаров
│   └── categories/               # Иконки категорий
│       ├── auto.png, real_estate.png, electronics.png, etc.
├──  Навигация
│   └── BottomNavigation/         # Иконки нижней навигации
│       ├── home-02.png, heart-rounded.png, etc.
├──  Профиль
│   └── profile_dashboard/        # Элементы профиля
├──  Недвижимость
│   └── home_page/                # Иконки для недвижимости
└──  Специальные экраны
    ├── publication_success/      # Ассеты успешной публикации
    └── publication_tariff/       # Элементы тарифов
```

# Тесты
```
test/
├──  Unit тесты
│   ├── models_test.dart          # Тестирование моделей данных
│   ├── api_service_test.dart     # Тестирование API сервиса
│   └── auth_service_test.dart    # Тестирование аутентификации
├──  Widget тесты
│   ├── category_card_test.dart   # Тестирование карточек категорий
│   └── listing_card_test.dart    # Тестирование карточек объявлений
└──  Конфигурационные файлы
    ├── api_service_test.mocks.dart # Сгенерированные моки
    └── widget_test.dart          # Базовый тест приложения
```



# Архитектурные принципы

Проект следует **Clean Architecture** с четким разделением на слои:

1. ** Presentation Layer** (pages/, widgets/) - UI компоненты
2. ** Business Logic Layer** (blocs/) - Логика приложения
3. ** Data Layer** (services/, models/) - Доступ к данным

Каждый слой имеет четкую ответственность и зависит только от нижележащих слоев, обеспечивая:
-  **Тестируемость** - каждый компонент можно тестировать изолированно
-  **Поддерживаемость** - изменения в одном слое не затрагивают другие
-  **Масштабируемость** - легкое добавление новых функций
-  **Читаемость** - четкая структура 

# Стек технологий

| Framework | Language | State Management | Storage & Caching | UI & Styling | HTTP Communication | Testing | Linting |
| ---------- | -------- | ----------------- | ----------------- | ------------ | ------------------ | ------- | ------- |
| ![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white) | ![Dart](https://img.shields.io/badge/Dart-00B4AB?logo=dart&logoColor=white) | ![BLoC](https://img.shields.io/badge/BLoC-02569B?logo=flutter&logoColor=white) | ![Hive](https://img.shields.io/badge/Hive-02569B?logo=flutter&logoColor=white) | ![Material Design](https://img.shields.io/badge/Material%20Design-02569B?logo=flutter&logoColor=white) | ![HTTP](https://img.shields.io/badge/HTTP-02569B?logo=dart&logoColor=white) | ![Flutter Test](https://img.shields.io/badge/Flutter%20Test-02569B?logo=flutter&logoColor=white) | ![analysis_options](https://img.shields.io/badge/analysis_options-02569B?logo=dart&logoColor=white) | 

# Основные зависимости

Проект использует следующие ключевые пакеты Flutter:

# Core Dependencies
- **flutter_bloc**: ^8.1.6 - Управление состоянием приложения с использованием BLoC паттерна
- **hive**: ^2.2.3 + **hive_flutter**: ^1.1.0 - Локальная NoSQL база данных для кэширования
- **http**: ^1.2.1 - HTTP клиент для коммуникации с REST API
- **flutter_form_builder**: ^10.2.0 + **form_builder_validators**: ^11.0.0 - Формы и валидация

# UI & Media
- **flutter_svg**: ^2.0.10+1 - Поддержка SVG изображений
- **image_picker**: ^1.1.2 - Выбор изображений из галереи/камеры
- **carousel_slider**: ^5.1.1 - Карусель изображений
- **flutter_native_splash**: ^2.4.7 - Кастомный splash screen
- **cupertino_icons**: ^1.0.8 - Иконки в стиле iOS

# Utilities
- **path_provider**: ^2.1.3 - Доступ к файловой системе устройства
- **url_launcher**: ^6.3.0 - Открытие URL, email и телефонных звонков

# Development & Testing
- **mockito**: ^5.5.0 + **bloc_test**: ^9.1.7 - Моки и тестирование BLoC
- **flutter_lints**: ^5.0.0 - Статический анализ кода
- **flutter_launcher_icons**: ^0.14.4 - Генерация иконок приложения

# BLoC Components
- `AuthBloc`: Обрабатывает аутентификацию пользователей и управление сессиями
- `ListingsBloc`: Управляет данными объявлений маркетплейса
- `NavigationBloc`: Контролирует состояние нижней навигации
- `ProfileBloc`: Управляет данными профиля пользователя
- `PasswordRecoveryBloc`: Обрабатывает поток восстановления пароля

# Ключевые технологии

- **Flutter**: Кроссплатформенный мобильный фреймворк
- **Dart**: Язык программирования
- **BLoC Pattern**: Управление состоянием для предсказуемых обновлений UI
- **Hive**: NoSQL база данных для локального хранения данных
- **HTTP**: Коммуникация с REST API
- **Flutter SVG**: Поддержка векторной графики

# Поток данных

1. **UI слой** (Pages/Widgets) → Отправляет события в BLoC
2. **Слой бизнес-логики** (BLoC) → Обрабатывает события и обновляет состояние
3. **Слой данных** (Services/Models) → Обрабатывает API вызовы и хранение данных
4. **UI слой** → Реагирует на изменения состояния и перестраивается


# Тестирование

Проект включает комплексный набор тестов для обеспечения качества кода и функциональности.

# Типы тестов

- **Unit-тесты**: Тестирование отдельных компонентов (модели, сервисы)
- **Widget-тесты**: Тестирование UI компонентов и виджетов
- **Integration-тесты**: Тестирование потоков взаимодействия между компонентами

# Запуск тестов

**Запуск всех тестов:**
```bash
flutter test
```

**Запуск конкретного файла с тестами:**
```bash
flutter test test/models_test.dart
flutter test test/category_card_test.dart
flutter test test/listing_card_test.dart
```

**Запуск тестов с покрытием:**
```bash
flutter test --coverage
```

**Запуск тестов в verbose режиме:**
```bash
flutter test -v
```

# Структура тестов

```
test/
├── models_test.dart              # Unit-тесты для моделей данных (6 тестов)
├── api_service_test.dart         # Unit-тесты для API сервиса (4 теста)
├── auth_service_test.dart        # Unit-тесты для сервиса аутентификации (9 тестов)
├── category_card_test.dart       # Widget-тесты для карточки категории (8 тестов)
├── listing_card_test.dart        # Widget-тесты для карточки объявления (20 тестов)
└── widget_test.dart              # Базовый smoke тест приложения (1 тест)
```


Тесты охватывают следующие компоненты:

- **Модели данных**: `Category`, `Listing` - конструкторы, валидация данных
- **Сервисы**: `ApiService`, `AuthService` - конфигурация, сигнатуры методов
- **UI компоненты**: `CategoryCard`, `ListingCard` - рендеринг, стилизация, адаптивность
- **Приложение**: Базовый smoke тест для проверки запуска

# Недавние обновления

<<<<<<< HEAD
# Новые функции и улучшения (19.12.2025)

# Карта объявлений
- Добавлена интерактивная карта с функцией "Смотреть все" для просмотра объявлений на карте
- Улучшенная навигация и отображение геолокационных данных

# Скелетоны загрузки
- Реализованы скелетоны загрузки для карточек категорий и объявлений
- Улучшен пользовательский опыт при отсутствии интернет-соединения
- Плавные анимации загрузки данных

# Расширенные фильтры недвижимости
- Добавлены новые фильтры для категорий недвижимости:
  - Продажа и аренда гаражей/парковок (посуточная, почасовая, долгосрочная)
  - Объекты за рубежом (квартиры, дома)
  - Хостелы, отели и курорты
  - Комнаты, дома, коммерческая недвижимость
- Динамическая система фильтров с поддержкой статичных и интерактивных элементов

# Динамические интерфейсы
- Полностью динамический экран RealEstateApartmentsScreen
- Динамические кнопки на экранах подкатегорий недвижимости
- Улучшенная передача данных между экранами
- Оптимизированная навигация в RealEstateSubcategoriesScreen

# UI/UX улучшения
- Исправлены отступы и выравнивание элементов на экранах
- Удалена кнопка "Рассрочка" для упрощения интерфейса
- Добавлены новые диалоги: жалобы, предложения цены, телефон, доплаты

# Структура кода
- Обновлена организация виджетов с разделением на поддиректории (cards/, components/, dialogs/, skeletons/)
- Добавлены новые модели фильтров с поддержкой Freezed
- Расширена структура BLoC с отдельными файлами событий и состояний

# Исправление комментариев в файлах add_listing (12.12.2025)

В рамках улучшения кодовой базы были исправлены комментарии в файлах экранов добавления объявлений в папке `lib/pages/add_listing/`. Все комментарии теперь точно соответствуют назначению каждого экрана.

# Исправленные файлы:

1. **land/add_land_rent_screen.dart** - "Продажа земли" → "Аренда земли"
2. **houses/add_house_rent_screen.dart** - "Продажа домов" → "Аренда домов"
3. **garages/add_garage_parking_sell_screen.dart** - "Продажа земли" → "Продажа гаражей"
4. **garages/add_garage_parking_long_rent_screen.dart** - "Продажа земли" → "Долгосрочная аренда гаражей"
5. **daily_rent/add_tour_operator_offer_screen.dart** - "Продажа земли" → "Предложения туроператоров"
6. **daily_rent/add_hotel_resort_rent_screen.dart** - "Продажа земли" → "Аренда отелей и курортов"
7. **daily_rent/add_hostel_bed_rent_screen.dart** - "Продажа земли" → "Аренда мест в хостелах"
8. **daily_rent/add_daily_share_sell_screen.dart** - "Продажа земли" → "Продажа ежедневных долей"
9. **daily_rent/add_apartment_daily_rent_screen.dart** - "Продажа земли" → "Посуточная аренда квартир"
10. **commercial_property/add_commercial_rent_screen.dart** - "Продажа торговых помещений" → "Аренда торговых помещений"


Это улучшение повышает читаемость кода и помогает разработчикам быстрее ориентироваться в структуре приложения.
=======
=======
# Lidza Mob



## Getting started

To make it easy for you to get started with GitLab, here's a list of recommended next steps.

Already a pro? Just edit this README.md and make it your own. Want to make it easy? [Use the template at the bottom](#editing-this-readme)!

## Add your files

- [ ] [Create](https://docs.gitlab.com/ee/user/project/repository/web_editor.html#create-a-file) or [upload](https://docs.gitlab.com/ee/user/project/repository/web_editor.html#upload-a-file) files
- [ ] [Add files using the command line](https://docs.gitlab.com/ee/gitlab-basics/add-file.html#add-a-file-using-the-command-line) or push an existing Git repository with the following command:

```
cd existing_repo
git remote add origin http://git.1choices.com/root/lidza-mob.git
git branch -M main
git push -uf origin main
```

## Integrate with your tools

- [ ] [Set up project integrations](http://git.1choices.com/root/lidza-mob/-/settings/integrations)

## Collaborate with your team

- [ ] [Invite team members and collaborators](https://docs.gitlab.com/ee/user/project/members/)
- [ ] [Create a new merge request](https://docs.gitlab.com/ee/user/project/merge_requests/creating_merge_requests.html)
- [ ] [Automatically close issues from merge requests](https://docs.gitlab.com/ee/user/project/issues/managing_issues.html#closing-issues-automatically)
- [ ] [Enable merge request approvals](https://docs.gitlab.com/ee/user/project/merge_requests/approvals/)
- [ ] [Set auto-merge](https://docs.gitlab.com/ee/user/project/merge_requests/merge_when_pipeline_succeeds.html)

## Test and Deploy

Use the built-in continuous integration in GitLab.

- [ ] [Get started with GitLab CI/CD](https://docs.gitlab.com/ee/ci/quick_start/index.html)
- [ ] [Analyze your code for known vulnerabilities with Static Application Security Testing (SAST)](https://docs.gitlab.com/ee/user/application_security/sast/)
- [ ] [Deploy to Kubernetes, Amazon EC2, or Amazon ECS using Auto Deploy](https://docs.gitlab.com/ee/topics/autodevops/requirements.html)
- [ ] [Use pull-based deployments for improved Kubernetes management](https://docs.gitlab.com/ee/user/clusters/agent/)
- [ ] [Set up protected environments](https://docs.gitlab.com/ee/ci/environments/protected_environments.html)

***

# Editing this README

When you're ready to make this README your own, just edit this file and use the handy template below (or feel free to structure it however you want - this is just a starting point!). Thanks to [makeareadme.com](https://www.makeareadme.com/) for this template.

## Suggestions for a good README

Every project is different, so consider which of these sections apply to yours. The sections used in the template are suggestions for most open source projects. Also keep in mind that while a README can be too long and detailed, too long is better than too short. If you think your README is too long, consider utilizing another form of documentation rather than cutting out information.

## Name
Choose a self-explaining name for your project.

## Description
Let people know what your project can do specifically. Provide context and add a link to any reference visitors might be unfamiliar with. A list of Features or a Background subsection can also be added here. If there are alternatives to your project, this is a good place to list differentiating factors.

## Badges
On some READMEs, you may see small images that convey metadata, such as whether or not all the tests are passing for the project. You can use Shields to add some to your README. Many services also have instructions for adding a badge.

## Visuals
Depending on what you are making, it can be a good idea to include screenshots or even a video (you'll frequently see GIFs rather than actual videos). Tools like ttygif can help, but check out Asciinema for a more sophisticated method.

## Installation
Within a particular ecosystem, there may be a common way of installing things, such as using Yarn, NuGet, or Homebrew. However, consider the possibility that whoever is reading your README is a novice and would like more guidance. Listing specific steps helps remove ambiguity and gets people to using your project as quickly as possible. If it only runs in a specific context like a particular programming language version or operating system or has dependencies that have to be installed manually, also add a Requirements subsection.

## Usage
Use examples liberally, and show the expected output if you can. It's helpful to have inline the smallest example of usage that you can demonstrate, while providing links to more sophisticated examples if they are too long to reasonably include in the README.

## Support
Tell people where they can go to for help. It can be any combination of an issue tracker, a chat room, an email address, etc.

## Roadmap
If you have ideas for releases in the future, it is a good idea to list them in the README.

## Contributing
State if you are open to contributions and what your requirements are for accepting them.

For people who want to make changes to your project, it's helpful to have some documentation on how to get started. Perhaps there is a script that they should run or some environment variables that they need to set. Make these steps explicit. These instructions could also be useful to your future self.

You can also document commands to lint the code or run tests. These steps help to ensure high code quality and reduce the likelihood that the changes inadvertently break something. Having instructions for running tests is especially helpful if it requires external setup, such as starting a Selenium server for testing in a browser.

## Authors and acknowledgment
Show your appreciation to those who have contributed to the project.

## License
For open source projects, say how it is licensed.

## Project status
If you have run out of energy or time for your project, put a note at the top of the README saying that development has slowed down or stopped completely. Someone may choose to fork your project or volunteer to step in as a maintainer or owner, allowing your project to keep going. You can also make an explicit request for maintainers.
>>>>>>> gitlab/main
>>>>>>> a3e2797d990eba2ad136fcc550bcb7a355270527
