#!/bin/bash

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Функции для логирования
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

# Проверка наличия Docker и Docker Compose
check_dependencies() {
    log_info "Проверка зависимостей..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker не установлен"
        exit 1
    fi
    
    # Проверяем поддержку docker compose (встроенная команда)
    if ! docker compose version &> /dev/null; then
        # Если встроенная команда не работает, проверяем отдельную установку
        if ! command -v docker-compose &> /dev/null; then
            log_error "Docker Compose не установлен"
            exit 1
        fi
    fi
    
    log_success "Все зависимости установлены"
}

# Обновление репозиториев
update_repositories() {
    log_info "Обновление репозиториев..."
    
    if [ -d "blog" ]; then
        log_info "Обновление blog репозитория..."
        cd blog
        git pull origin main || git pull origin master
        cd ..
    fi
    
    if [ -d "russiankisa" ]; then
        log_info "Обновление russiankisa репозитория..."
        cd russiankisa
        git pull origin main || git pull origin master
        cd ..
    fi
    
    log_success "Репозитории обновлены"
}

# Определение команды Docker Compose
get_docker_compose_cmd() {
    if docker compose version &> /dev/null; then
        echo "docker compose"
    elif command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    else
        log_error "Docker Compose не найден"
        exit 1
    fi
}

# Сборка и запуск контейнеров
deploy() {
    log_info "Запуск деплоя..."
    
    local compose_cmd=$(get_docker_compose_cmd)
    
    $compose_cmd down
    $compose_cmd build --no-cache
    $compose_cmd up -d
    
    log_success "Деплой завершен"
}

# Остановка контейнеров
stop() {
    log_info "Остановка контейнеров..."
    local compose_cmd=$(get_docker_compose_cmd)
    $compose_cmd down
    log_success "Контейнеры остановлены"
}

# Перезапуск контейнеров
restart() {
    log_info "Перезапуск контейнеров..."
    local compose_cmd=$(get_docker_compose_cmd)
    $compose_cmd restart
    log_success "Контейнеры перезапущены"
}

# Просмотр логов
logs() {
    local service=${1:-""}
    local compose_cmd=$(get_docker_compose_cmd)
    if [ -n "$service" ]; then
        $compose_cmd logs -f "$service"
    else
        $compose_cmd logs -f
    fi
}

# Статус контейнеров
status() {
    log_info "Статус контейнеров:"
    local compose_cmd=$(get_docker_compose_cmd)
    $compose_cmd ps
}

# Очистка неиспользуемых ресурсов
cleanup() {
    log_info "Очистка неиспользуемых ресурсов..."
    docker system prune -f
    docker volume prune -f
    log_success "Очистка завершена"
}

# Обновление и деплой
update_and_deploy() {
    update_repositories
    deploy
}

# Показать справку
show_help() {
    echo "Использование: $0 [команда]"
    echo ""
    echo "Команды:"
    echo "  deploy              - Сборка и запуск контейнеров"
    echo "  update              - Обновление репозиториев"
    echo "  update-deploy       - Обновление репозиториев и деплой"
    echo "  stop                - Остановка контейнеров"
    echo "  restart             - Перезапуск контейнеров"
    echo "  logs [service]      - Просмотр логов (опционально указать сервис)"
    echo "  status              - Статус контейнеров"
    echo "  cleanup             - Очистка неиспользуемых ресурсов"
    echo "  help                - Показать эту справку"
    echo ""
    echo "Примеры:"
    echo "  $0 deploy"
    echo "  $0 logs blog"
    echo "  $0 update-deploy"
}

# Основная логика
main() {
    check_dependencies
    
    case "${1:-help}" in
        deploy)
            deploy
            ;;
        update)
            update_repositories
            ;;
        update-deploy)
            update_and_deploy
            ;;
        stop)
            stop
            ;;
        restart)
            restart
            ;;
        logs)
            logs "$2"
            ;;
        status)
            status
            ;;
        cleanup)
            cleanup
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Неизвестная команда: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@" 