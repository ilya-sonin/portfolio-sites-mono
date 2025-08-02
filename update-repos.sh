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

# Функция для обновления одного репозитория
update_repo() {
    local repo_path=$1
    local repo_name=$2
    
    if [ ! -d "$repo_path" ]; then
        log_error "Директория $repo_path не найдена"
        return 1
    fi
    
    log_info "Обновление $repo_name..."
    
    cd "$repo_path"
    
    # Проверяем, есть ли изменения в удаленном репозитории
    git fetch origin
    
    local current_branch=$(git branch --show-current)
    local remote_commit=$(git rev-parse origin/$current_branch)
    local local_commit=$(git rev-parse HEAD)
    
    if [ "$remote_commit" != "$local_commit" ]; then
        log_info "Найдены изменения в $repo_name, обновляем..."
        git pull origin $current_branch
        log_success "$repo_name обновлен"
        return 0
    else
        log_info "$repo_name уже актуален"
        return 1
    fi
}

# Основная функция обновления
main() {
    log_info "Начинаем проверку обновлений репозиториев..."
    
    local blog_updated=false
    local russiankisa_updated=false
    
    # Обновляем blog
    if update_repo "blog" "blog"; then
        blog_updated=true
    fi
    
    # Обновляем russiankisa
    if update_repo "russiankisa" "russiankisa"; then
        russiankisa_updated=true
    fi
    
    # Если были обновления, перезапускаем контейнеры
    if [ "$blog_updated" = true ] || [ "$russiankisa_updated" = true ]; then
        log_info "Обнаружены обновления, перезапускаем контейнеры..."
        
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
        
        # Пересобираем только обновленные сервисы
        if [ "$blog_updated" = true ]; then
            log_info "Пересборка blog..."
            $compose_cmd build blog
        fi
        
        if [ "$russiankisa_updated" = true ]; then
            log_info "Пересборка russiankisa..."
            $compose_cmd build russiankisa
        fi
        
        # Перезапускаем контейнеры
        $compose_cmd up -d
        
        log_success "Контейнеры перезапущены с обновлениями"
    else
        log_info "Обновлений не найдено"
    fi
}

# Запуск скрипта
main "$@" 