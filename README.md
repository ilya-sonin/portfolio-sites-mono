# Система деплоя для Nuxt проектов

Эта система обеспечивает автоматический деплой и управление двумя Nuxt проектами:
- **blog** (домен: ilya-sonin.ru)
- **russiankisa** (домен: russiankisadesign.ru)

## Архитектура

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Nginx Proxy   │────│   Blog App      │    │ Russiankisa App │
│   (Port 80)     │    │   (Port 3000)   │    │   (Port 3000)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Требования

- Docker (версия 20.10+)
- Docker Compose (встроенный в Docker CLI или отдельная установка)
- Git
- Bash

## Быстрый старт

1. **Запустите установку (репозитории клонируются автоматически):**
```bash
./install.sh
```

2. **Настройте переменные окружения для blog (если необходимо):**
```bash
cp blog/env.example blog/.env
# Отредактируйте blog/.env с реальными значениями
```

3. **Система готова к работе!**

## Управление системой

### Основные команды

```bash
# Деплой проектов
./deploy.sh deploy

# Обновление репозиториев
./deploy.sh update

# Обновление и деплой
./deploy.sh update-deploy

# Остановка контейнеров
./deploy.sh stop

# Перезапуск контейнеров
./deploy.sh restart

# Просмотр логов
./deploy.sh logs [service]

# Статус контейнеров
./deploy.sh status

# Очистка ресурсов
./deploy.sh cleanup
```

### Автоматическое обновление

#### Настройка cron для автоматического обновления:

```bash
# Настройка логирования
./setup-cron.sh setup-logging

# Добавление cron задачи (выберите один из вариантов)
./setup-cron.sh add hourly    # Каждый час
./setup-cron.sh add daily     # Каждый день в 2:00
./setup-cron.sh add weekly    # Каждую неделю в воскресенье в 2:00
./setup-cron.sh add custom '*/30 * * * *'  # Каждые 30 минут

# Просмотр текущих cron задач
./setup-cron.sh show

# Удаление cron задач
./setup-cron.sh remove
```

#### Ручное обновление:

```bash
# Обновление с автоматическим перезапуском контейнеров
./update-repos.sh
```

## Структура проекта

```
portfolio-sites-mono/
├── blog/                    # Проект blog
│   ├── Dockerfile          # Dockerfile для blog
│   ├── .env               # Переменные окружения (создается автоматически)
│   └── ...
├── russiankisa/            # Проект russiankisa
│   ├── Dockerfile          # Dockerfile для russiankisa
│   └── ...
├── nginx/                  # Конфигурация Nginx
│   ├── nginx.conf         # Основная конфигурация
│   └── conf.d/
│       └── default.conf   # Конфигурация доменов
├── ssl/                   # SSL сертификаты (опционально)
├── docker-compose.yml     # Docker Compose конфигурация
├── deploy.sh             # Основной скрипт управления
├── update-repos.sh       # Скрипт обновления репозиториев
├── setup-cron.sh         # Скрипт настройки cron
└── .dockerignore         # Исключения для Docker
```

## Конфигурация доменов

Система настроена для работы со следующими доменами:

- **ilya-sonin.ru** → проект blog
- **russiankisadesign.ru** → проект russiankisa

### Настройка DNS

Убедитесь, что DNS записи указывают на ваш сервер:

```
A    ilya-sonin.ru         → <IP-адрес-сервера>
A    www.ilya-sonin.ru     → <IP-адрес-сервера>
A    russiankisadesign.ru  → <IP-адрес-сервера>
A    www.russiankisadesign.ru → <IP-адрес-сервера>
```

## SSL сертификаты

Для настройки HTTPS:

1. Поместите сертификаты в папку `ssl/`
2. Обновите конфигурацию nginx в `nginx/conf.d/default.conf`
3. Перезапустите контейнеры: `./deploy.sh restart`

## Мониторинг и логи

### Просмотр логов

```bash
# Все логи
./deploy.sh logs

# Логи конкретного сервиса
./deploy.sh logs blog
./deploy.sh logs russiankisa
./deploy.sh logs nginx

# Логи обновлений (если настроен cron)
tail -f /var/log/update-repos.log
```

### Статус системы

```bash
# Статус контейнеров
./deploy.sh status

# Использование ресурсов
docker stats
```

## Устранение неполадок

### Проблемы с деплоем

1. **Проверьте зависимости:**
```bash
docker --version
docker compose version
```

2. **Очистите кэш Docker:**
```bash
./deploy.sh cleanup
```

3. **Пересоберите образы:**
```bash
docker compose build --no-cache
```

### Проблемы с доменами

1. **Проверьте DNS настройки**
2. **Убедитесь, что порт 80 открыт на сервере**
3. **Проверьте конфигурацию nginx:**
```bash
docker compose exec nginx nginx -t
```

### Проблемы с обновлениями

1. **Проверьте права доступа к репозиториям**
2. **Убедитесь, что git настроен правильно**
3. **Проверьте cron задачи:**
```bash
./setup-cron.sh show
```

### Проблемы с .env файлом

Если возникает ошибка "env file not found":

1. **Проверьте наличие файла:**
```bash
ls -la blog/.env
```

2. **Создайте файл вручную:**
```bash
cp blog/env.example blog/.env
# или
touch blog/.env
```

3. **Добавьте необходимые переменные в blog/.env:**
```bash
NODE_ENV=production
NITRO_HOST=0.0.0.0
NITRO_PORT=3000
```

## Безопасность

- Все контейнеры запускаются с непривилегированными пользователями
- Переменные окружения хранятся в отдельных файлах
- Nginx настроен с базовыми заголовками безопасности
- Используется последняя стабильная версия Node.js

## Производительность

- Multi-stage Docker builds для оптимизации размера образов
- Кэширование зависимостей pnpm
- Gzip сжатие в nginx
- Оптимизированные настройки nginx для Nuxt приложений

## Совместимость

Система поддерживает как новую команду `docker compose` (встроенную в Docker CLI), так и старую `docker-compose` (отдельную установку). Автоматически определяется доступная версия.

## Поддержка

При возникновении проблем:

1. Проверьте логи: `./deploy.sh logs`
2. Убедитесь в корректности конфигурации
3. Проверьте статус контейнеров: `./deploy.sh status`
4. При необходимости перезапустите систему: `./deploy.sh restart` 