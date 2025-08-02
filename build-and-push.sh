#!/bin/bash

# Скрипт для локальной сборки и загрузки dist-ов на сервер

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции логирования
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка аргументов
if [ $# -eq 0 ]; then
    log_error "Укажите адрес сервера"
    echo "Использование: $0 <user@server-ip>"
    echo "Пример: $0 user@192.168.1.100"
    echo "Пример: $0 root@192.168.1.100"
    exit 1
fi

# Парсим SSH адрес
SSH_ADDRESS=$1
if [[ $SSH_ADDRESS == *"@"* ]]; then
    SSH_USER=$(echo $SSH_ADDRESS | cut -d@ -f1)
    SERVER_IP=$(echo $SSH_ADDRESS | cut -d@ -f2)
else
    log_error "Неверный формат адреса. Используйте: user@server-ip"
    echo "Пример: $0 user@192.168.1.100"
    exit 1
fi

REMOTE_PATH="/home/$SSH_USER/portfolio-sites-mono"

log_info "Начинаем сборку и загрузку на сервер $SSH_ADDRESS..."

# Проверяем наличие проектов
if [ ! -d "blog" ]; then
    log_error "Папка blog не найдена"
    exit 1
fi

if [ ! -d "russiankisa" ]; then
    log_error "Папка russiankisa не найдена"
    exit 1
fi

# Сборка blog
log_info "Сборка blog..."
cd blog
if [ ! -f "package.json" ]; then
    log_error "package.json не найден в blog"
    exit 1
fi

# Устанавливаем зависимости если нужно
if [ ! -d "node_modules" ]; then
    log_info "Установка зависимостей blog..."
    pnpm install
fi

# Собираем проект
log_info "Сборка blog..."
pnpm build
cd ..

# Сборка russiankisa
log_info "Сборка russiankisa..."
cd russiankisa
if [ ! -f "package.json" ]; then
    log_error "package.json не найден в russiankisa"
    exit 1
fi

# Устанавливаем зависимости если нужно
if [ ! -d "node_modules" ]; then
    log_info "Установка зависимостей russiankisa..."
    pnpm install
fi

# Собираем проект
log_info "Сборка russiankisa..."
pnpm build
cd ..

# Проверяем что сборка прошла успешно
if [ ! -d "blog/.output" ]; then
    log_error "Сборка blog не удалась - папка .output не найдена"
    exit 1
fi

if [ ! -d "russiankisa/.output" ]; then
    log_error "Сборка russiankisa не удалась - папка .output не найдена"
    exit 1
fi

log_success "Локальная сборка завершена"

# Создаем архив с готовыми dist-ами
log_info "Создание архива с готовыми dist-ами..."
tar -czf dists.tar.gz blog/.output russiankisa/.output

# Загружаем на сервер
log_info "Загрузка на сервер $SSH_ADDRESS..."
scp dists.tar.gz $SSH_ADDRESS:$REMOTE_PATH/

# Распаковываем на сервере
log_info "Распаковка на сервере..."
ssh $SSH_ADDRESS "cd $REMOTE_PATH && tar -xzf dists.tar.gz && rm dists.tar.gz"

# Запускаем деплой готовых dist-ов
log_info "Запуск деплоя готовых dist-ов на сервере..."
ssh $SSH_ADDRESS "cd $REMOTE_PATH && ./deploy.sh deploy-ready-dists"

# Очищаем локальный архив
rm dists.tar.gz

log_success "Сборка и деплой завершены успешно!"
log_info "Проекты доступны по адресам:"
log_info "  - http://ilya-sonin.ru"
log_info "  - http://russiankisadesign.ru" 