# PostgreSQL Patch Updater 

## Оглавление
- [Обзор проекта](#обзор-проекта)
- [Структура проекта](#структура-проекта)
- [Предварительные требования](#предварительные-требования)
- [Сборка image](#сборка-image)
- [Сборка контейнера](#сборка-контейнера)
- [Пример конфигурации](#пример-конфигурации)
- [Решение проблем](#решение-проблем)

## Обзор проекта

Этот проект автоматически применяет SQL-патчи для PostgreSQL через Docker. Можно собирать image вручную либо через Teamcity. Сборка контейнера делается через docker-compose или вручную.

## Структура проекта

```text
pgsqlpatchupdater/
├── docker/
│   ├── Dockerfile.PgSQLPatchUpdater
│   └── entrypoint.sh
├── docker-compose.yml
└── .env
```

**Репозиторий:** `http://10.17.0.86:8100/ansible/pgsqlpatchupdater.git`

## Предварительные требования

-  Установленный Git на системе
-  Установленный и запущенный Docker
-  Установленный Docker Compose
-  Доступ к GitLab репозиторию

##  Сборка image

### Локальный запуск
### 1. Клонирование проекта
```bash
git clone http://10.17.0.86:8100/ansible/pgsqlpatchupdater.git
cd pgsqlpatchupdater
```
### 2. Настройка .env

Отредактируйте DB_HOST, DB_NAME, DB_USER, DB_PASS, VERSION, BRANCH, GIT_TOKEN, SEED

VERSION режимы:

| Значение | Действие |
|----------|----------|
| `пустая строка` | Все новые патчи по порядку |
| `191` | Только `patch191.sql` |
| `190,192,198` | Несколько патчей последовательно |

SEED режимы:
`true` - дополнительно применится seed__adm_system_service_info.sql

### 3. Запустите docker-compose.yml
```bash
docker compose up --build
```

### Запуск через TeamCity
1. Джоба: `SETUP Build Container` по ссылке `http://10.15.0.135:8000/viewType.html?buildTypeId=Deploy_SetupBuildContainer`
2. Параметры:
action=Обновлять публичный репозиторий по тегу?
branch=release #можно также выбрать ветку master
service=PgSQLPatchUpdater
stage=agent-docker-stage
tag=latest # можно указать любой

### 3. Запустите джобу

## Сборка контейнера
Если у вас нет образа локально то сделайте pull (возможно перед этим потребуется выполнить docker login):
docker pull swr.ru-moscow-1.hc.sbercloud.ru/transport.crr/pgsqlpatchupdater:latest

Запустите контейнер с параметрами:

```bash
docker run --rm --name pgsqlpatchupdater -e DB_HOST=10.17.1.199 -e DB_NAME=rnis -e DB_PASS=your_password_here -e DB_PORT=5432 -e DB_USER=admin -e VERSION=202 -e SEED=true pgsqlpatchupdater:latest
```

SEED можно не указывать если не требуется применение seed__adm_system_service_info.sql

## Пример конфигурации

```text
.env
DB_HOST=192.168.100.200
DB_PORT=5432
DB_NAME=db
DB_USER=admin
DB_PASS=password
VERSION=190,191,192 # последовательное применение патчей 190,191 и 192
SEED=true
BRANCH=master
GIT_TOKEN=xxxxxxxxx
```

## Решение проблем

| Ошибка | Решение |
|--------|---------|
| `patch191.sql не найден` | Проверьте `Transport/versioningDb/` |
| `Connection refused` | Проверьте `DB_HOST:DB_PORT` |
| `no password supplied` | `.pgpass` права `600` |