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

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Получаем абсолютный путь к скрипту обновления
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE_SCRIPT="$SCRIPT_DIR/update-repos.sh"

# Проверяем существование скрипта обновления
if [ ! -f "$UPDATE_SCRIPT" ]; then
    log_error "Скрипт обновления не найден: $UPDATE_SCRIPT"
    exit 1
fi

# Функция для добавления cron задачи
add_cron_job() {
    local interval=$1
    local description=$2
    
    log_info "Добавление cron задачи для $description..."
    
    # Создаем временный файл с текущими cron задачами
    crontab -l > /tmp/current_cron 2>/dev/null || true
    
    # Добавляем новую задачу
    echo "$interval $UPDATE_SCRIPT >> /var/log/update-repos.log 2>&1" >> /tmp/current_cron
    
    # Устанавливаем новые cron задачи
    crontab /tmp/current_cron
    
    # Удаляем временный файл
    rm /tmp/current_cron
    
    log_success "Cron задача добавлена: $description"
}

# Функция для удаления cron задач
remove_cron_jobs() {
    log_info "Удаление всех cron задач для обновления репозиториев..."
    
    # Создаем временный файл без задач обновления
    crontab -l 2>/dev/null | grep -v "$UPDATE_SCRIPT" > /tmp/clean_cron || true
    
    # Устанавливаем очищенные cron задачи
    crontab /tmp/clean_cron
    
    # Удаляем временный файл
    rm /tmp/clean_cron
    
    log_success "Cron задачи удалены"
}

# Функция для показа текущих cron задач
show_cron_jobs() {
    log_info "Текущие cron задачи для обновления репозиториев:"
    crontab -l 2>/dev/null | grep "$UPDATE_SCRIPT" || echo "Задачи не найдены"
}

# Функция для настройки логирования
setup_logging() {
    log_info "Настройка логирования..."
    
    # Создаем файл логов если его нет
    sudo touch /var/log/update-repos.log
    sudo chmod 644 /var/log/update-repos.log
    
    log_success "Логирование настроено: /var/log/update-repos.log"
}

# Показать справку
show_help() {
    echo "Использование: $0 [команда] [интервал]"
    echo ""
    echo "Команды:"
    echo "  add [интервал]     - Добавить cron задачу"
    echo "  remove             - Удалить все cron задачи"
    echo "  show               - Показать текущие cron задачи"
    echo "  setup-logging      - Настроить логирование"
    echo "  help               - Показать эту справку"
    echo ""
    echo "Интервалы (для команды add):"
    echo "  hourly             - Каждый час"
    echo "  daily              - Каждый день в 2:00"
    echo "  weekly             - Каждую неделю в воскресенье в 2:00"
    echo "  custom             - Пользовательский интервал"
    echo ""
    echo "Примеры:"
    echo "  $0 add hourly"
    echo "  $0 add daily"
    echo "  $0 add custom '*/30 * * * *'  # Каждые 30 минут"
    echo "  $0 remove"
    echo "  $0 show"
}

# Основная логика
main() {
    case "${1:-help}" in
        add)
            case "${2:-}" in
                hourly)
                    add_cron_job "0 * * * *" "каждый час"
                    ;;
                daily)
                    add_cron_job "0 2 * * *" "каждый день в 2:00"
                    ;;
                weekly)
                    add_cron_job "0 2 * * 0" "каждую неделю в воскресенье в 2:00"
                    ;;
                custom)
                    if [ -n "$3" ]; then
                        add_cron_job "$3" "пользовательский интервал"
                    else
                        log_error "Для custom интервала нужно указать cron выражение"
                        echo "Пример: $0 add custom '*/30 * * * *'"
                        exit 1
                    fi
                    ;;
                *)
                    log_error "Неизвестный интервал: $2"
                    echo "Доступные интервалы: hourly, daily, weekly, custom"
                    exit 1
                    ;;
            esac
            ;;
        remove)
            remove_cron_jobs
            ;;
        show)
            show_cron_jobs
            ;;
        setup-logging)
            setup_logging
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