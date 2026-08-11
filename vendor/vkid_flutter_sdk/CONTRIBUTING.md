# Contributing

## ⏳ Подготовка к разработке
Склонируйте репозиторий и перейдите в созданную директорию.

```bash

git clone git@github.com:VKCOM/vkid-flutter-sdk.git
cd vkid-flutter-sdk
```
Или можно сделать fork репозитория и склонировать его.

После этого установите git hook на форматирование кода с помощью dart format.
```bash
./scripts/install-git-hooks.sh
```

## 🪵 Создание ветки

Ветки создаются от `develop`.

Для названия веток используется специальный шаблон:

```
{task_type}/{issue_number}/{description}

Где:
- {task_type} - "fix", если это испарвление бага и "task", если это полноценная доработка
- {issue_number} - VKIDSDK-XXX для разработчиков VK и ISSUE-XXX для внешних контрибьютеров
- {description} - Краткое описание проделанной работы
```

Пример:
```bash
git checkout develop
git pull
git checkout -b task/ISSUE-0000/some-issue
```

## 📝 Создание коммита

Сообщение в коммите должно соответствовать шаблону:

```
{issue_number}: {commit_description} 

Где:
- {issue_number} - VKIDSDK-XXX для разработчиков VK и ISSUE-XXX для внешних контрибьютеров
- {commit_description} - Краткое описание коммита на английском языке
```


Пример:
```bash
git checkout master
git add -A
git commit -m "ISSUE-0000: some commit description"
```

## 🔧 Подготовка к пушу ветки

Перед пушем ветки убедитесь, что обновлён публичный API модулей и перетянуты зависимости.
```bash
./gradlew allDependencies --write-locks
git commit -m "ISSUE-XXX: Update dependency locks"
./gradlew apiDump
git commit -m "ISSUE-XXX: Update public api"
git push
```
Обратите внимание, что в коммитах нужно указать номер issue, в рамках которой будет сделан Pull Request.

## 😸 Подготовка Pull Request

Cделайте заголовок PR по шаблону:
```
{issue_number}: {commit_description} 

Где:
- {issue_number} - VKIDSDK-XXX для разработчиков VK и ISSUE-XXX для внешних контрибьютеров
- {commit_description} - Краткое описание коммита на английском языке
```

Пример:
```
ISSUE-000: Some issue description
```
