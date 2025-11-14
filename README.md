<<<<<<< HEAD
# LIDLE

LIDLE - современное мобильное приложение маркетплейса на базе Flutter, предназначенное для покупки и продажи автомобилей и недвижимости. Приложение предоставляет удобный интерфейс для просмотра объявлений, управления профилями пользователей и обработки потоков аутентификации.

# Возможности

- **Система аутентификации**: Вход, регистрация, восстановление пароля с email верификацией
- **Объявления маркетплейса**: Просмотр объявлений об автомобилях и недвижимости с подробной информацией
- **Профили пользователей**: Управление личной панелью с избранным и объявлениями
- **Поиск и категории**: Продвинутый функционал поиска и категоризированный просмотр
- **Локальное хранилище**: Оффлайн хранение данных с использованием Hive
- **Адаптивный дизайн**: Оптимизирован для мобильных устройств с кастомными UI компонентами

# Установка

# Предварительные требования

- Flutter SDK (^3.9.2)
- Dart SDK (включен во Flutter)
- Android Studio или VS Code для разработки
- Android/iOS устройство или эмулятор

# Настройка

1. **Установите зависимости:**
   ```bash
   flutter pub get
   ```

2. **Запустите приложение:**
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

```
lib/
├── blocs/              # BLoC компоненты для управления состоянием
│   ├── auth/          # Логика аутентификации
│   ├── listings/      # Логика объявлений маркетплейса
│   ├── navigation/    # Логика нижней навигации
│   ├── profile/       # Логика профиля пользователя
│   └── password_recovery/  # Логика восстановления пароля
├── models/            # Модели данных
├── pages/             # UI экраны/страницы
├── services/          # Сервисы API и бизнес-логики
├── widgets/           # Переиспользуемые UI компоненты
├── constants.dart     # Константы приложения и теминг
├── hive_service.dart  # Сервис локального хранения
└── main.dart         # Точка входа в приложение
```

# Ключевые технологии

- **Flutter**: Кроссплатформенный мобильный фреймворк
- **BLoC Pattern**: Управление состоянием для предсказуемых обновлений UI
- **Hive**: NoSQL база данных для локального хранения данных
- **HTTP**: Коммуникация с REST API
- **Flutter SVG**: Поддержка векторной графики
- **Carousel Slider**: Функционал карусели изображений
- **Form Builder**: Продвинутая валидация форм

# Управление состоянием

Приложение использует множественные BLoC для управления различными аспектами состояния приложения:

- `AuthBloc`: Обрабатывает аутентификацию пользователей и управление сессиями
- `ListingsBloc`: Управляет данными объявлений маркетплейса
- `NavigationBloc`: Контролирует состояние нижней навигации
- `ProfileBloc`: Управляет данными профиля пользователя
- `PasswordRecoveryBloc`: Обрабатывает поток восстановления пароля

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
