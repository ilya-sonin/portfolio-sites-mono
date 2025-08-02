#!/bin/bash

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Проверка операционной системы
check_os() {
    log_info "Проверка операционной системы..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$NAME
            VER=$VERSION_ID
        else
            log_error "Не удалось определить операционную систему"
            exit 1
        fi
    else
        log_error "Этот скрипт предназначен только для Linux"
        exit 1
    fi
    
    log_success "Операционная система: $OS $VER"
}

# Установка Docker
install_docker() {
    log_info "Установка Docker..."
    
    if command -v docker &> /dev/null; then
        log_warning "Docker уже установлен"
        return 0
    fi
    
    # Установка зависимостей
    sudo apt-get update
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Добавление GPG ключа Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Добавление репозитория Docker
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Установка Docker
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    
    # Добавление пользователя в группу docker
    sudo usermod -aG docker $USER
    
    log_success "Docker установлен"
    log_warning "Перезагрузите систему или выполните 'newgrp docker' для применения изменений группы"
}

# Проверка Docker Compose
check_docker_compose() {
    log_info "Проверка Docker Compose..."
    
    # Проверяем поддержку docker compose (встроенная команда)
    if docker compose version &> /dev/null; then
        log_success "Docker Compose поддерживается"
        return 0
    fi
    
    # Если встроенная команда не работает, проверяем отдельную установку
    if command -v docker-compose &> /dev/null; then
        log_success "Docker Compose установлен отдельно"
        return 0
    fi
    
    log_error "Docker Compose не найден. Установите Docker Compose отдельно"
    log_info "Выполните: sudo curl -L 'https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)' -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose"
    exit 1
}

# Настройка firewall
setup_firewall() {
    log_info "Настройка firewall..."
    
    if command -v ufw &> /dev/null; then
        sudo ufw allow 22/tcp
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp
        sudo ufw --force enable
        log_success "Firewall настроен"
    else
        log_warning "UFW не найден, настройте firewall вручную"
    fi
}

# Создание необходимых директорий
create_directories() {
    log_info "Создание необходимых директорий..."
    
    mkdir -p nginx/conf.d ssl
    log_success "Директории созданы"
}

# Настройка переменных окружения
setup_environment() {
    log_info "Настройка переменных окружения..."
    
    if [ -f "blog/env.example" ] && [ ! -f "blog/.env" ]; then
        cp blog/env.example blog/.env
        log_warning "Файл blog/.env создан из примера. Отредактируйте его с реальными значениями"
    elif [ ! -f "blog/.env" ]; then
        log_warning "Файл blog/.env не найден. Создайте его вручную с необходимыми переменными окружения"
        # Создаем минимальный .env файл
        cat > blog/.env << EOF
# Основные настройки
NODE_ENV=production
NITRO_HOST=0.0.0.0
NITRO_PORT=3000

# Добавьте другие необходимые переменные окружения ниже
EOF
        log_info "Создан базовый файл blog/.env"
    fi
    
    log_success "Переменные окружения настроены"
}

# Инициализация и обновление submodules
setup_submodules() {
    log_info "Настройка Git submodules..."
    
    # Инициализируем submodules если это первый запуск
    if [ ! -f ".gitmodules" ]; then
        log_info "Создание .gitmodules файла..."
        cat > .gitmodules << EOF
[submodule "blog"]
	path = blog
	url = https://github.com/ilya-sonin/blog.git
[submodule "russiankisa"]
	path = russiankisa
	url = https://github.com/ilya-sonin/russiankisa.git
EOF
        log_success ".gitmodules файл создан"
    fi
    
    # Добавляем submodules если они еще не добавлены
    if [ ! -d "blog" ] || [ ! -f "blog/.git" ]; then
        log_info "Добавление blog submodule..."
        git submodule add https://github.com/ilya-sonin/blog.git blog
        if [ $? -eq 0 ]; then
            log_success "Blog submodule добавлен"
        else
            log_error "Ошибка при добавлении blog submodule"
            exit 1
        fi
    fi
    
    if [ ! -d "russiankisa" ] || [ ! -f "russiankisa/.git" ]; then
        log_info "Добавление russiankisa submodule..."
        git submodule add https://github.com/ilya-sonin/russiankisa.git russiankisa
        if [ $? -eq 0 ]; then
            log_success "Russiankisa submodule добавлен"
        else
            log_error "Ошибка при добавлении russiankisa submodule"
            exit 1
        fi
    fi
    
    # Инициализируем и обновляем submodules
    log_info "Инициализация submodules..."
    git submodule init
    
    log_info "Обновление submodules..."
    git submodule update --init --recursive
    
    log_success "Submodules настроены и обновлены"
}

# Настройка прав доступа
setup_permissions() {
    log_info "Настройка прав доступа..."
    
    chmod +x deploy.sh
    chmod +x update-repos.sh
    chmod +x setup-cron.sh
    
    log_success "Права доступа настроены"
}

# Первоначальный деплой
initial_deploy() {
    log_info "Выполнение первоначального деплоя..."
    
    # Определение команды Docker Compose
    local compose_cmd
    if docker compose version &> /dev/null; then
        compose_cmd="docker compose"
    elif command -v docker-compose &> /dev/null; then
        compose_cmd="docker-compose"
    else
        log_error "Docker Compose не найден"
        exit 1
    fi
    
    # Выполняем деплой напрямую с последовательной сборкой
    log_info "Остановка существующих контейнеров..."
    $compose_cmd down 2>/dev/null || true
    
    log_info "Последовательная сборка образов..."
    
    log_info "Сборка blog..."
    $compose_cmd build --no-cache blog
    if [ $? -ne 0 ]; then
        log_error "Ошибка при сборке blog"
        exit 1
    fi
    
    log_info "Сборка russiankisa..."
    $compose_cmd build --no-cache russiankisa
    if [ $? -ne 0 ]; then
        log_error "Ошибка при сборке russiankisa"
        exit 1
    fi
    
    log_info "Запуск контейнеров..."
    $compose_cmd up -d
    
    log_success "Первоначальный деплой завершен"
}

# Показать справку
show_help() {
    echo "Использование: $0 [опции]"
    echo ""
    echo "Опции:"
    echo "  --skip-docker        - Пропустить установку Docker"
    echo "  --skip-firewall      - Пропустить настройку firewall"
    echo "  --skip-deploy        - Пропустить первоначальный деплой"
    echo "  --help              - Показать эту справку"
    echo ""
    echo "Примеры:"
    echo "  $0                    # Полная установка"
    echo "  $0 --skip-docker      # Пропустить установку Docker"
    echo "  $0 --skip-deploy      # Только настройка, без деплоя"
}

# Основная функция установки
main() {
    local skip_docker=false
    local skip_firewall=false
    local skip_deploy=false
    
    # Парсинг аргументов
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-docker)
                skip_docker=true
                shift
                ;;
            --skip-firewall)
                skip_firewall=true
                shift
                ;;
            --skip-deploy)
                skip_deploy=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Неизвестная опция: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    log_info "Начинаем установку системы деплоя..."
    
    check_os
    
    if [ "$skip_docker" = false ]; then
        install_docker
        check_docker_compose
    fi
    
    if [ "$skip_firewall" = false ]; then
        setup_firewall
    fi
    
    create_directories
    setup_environment
    setup_submodules
    setup_permissions
    
    if [ "$skip_deploy" = false ]; then
        initial_deploy
    fi
    
    log_success "Установка завершена!"
    echo ""
    echo "Следующие шаги:"
    echo "1. Отредактируйте blog/.env с реальными значениями"
    echo "2. Настройте DNS записи для доменов:"
    echo "   - ilya-sonin.ru → $(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')"
    echo "   - russiankisadesign.ru → $(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')"
    echo "3. Для автоматического обновления выполните:"
    echo "   ./setup-cron.sh add daily"
    echo ""
    echo "Команды управления:"
    echo "  ./deploy.sh status    - Статус контейнеров"
    echo "  ./deploy.sh logs      - Просмотр логов"
    echo "  ./deploy.sh restart   - Перезапуск контейнеров"
}

main "$@" 