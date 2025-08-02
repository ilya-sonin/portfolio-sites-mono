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

# Функция для обновления submodules
update_submodules() {
    log_info "Обновление Git submodules..."
    
    # Проверяем, есть ли изменения в удаленных репозиториях
    git submodule foreach git fetch origin
    
    local blog_updated=false
    local russiankisa_updated=false
    
    # Проверяем blog submodule
    if [ -d "blog" ] && [ -f "blog/.git" ]; then
        cd blog
        local current_branch=$(git branch --show-current)
        local remote_commit=$(git rev-parse origin/$current_branch 2>/dev/null)
        local local_commit=$(git rev-parse HEAD)
        
        if [ "$remote_commit" != "$local_commit" ]; then
            log_info "Найдены изменения в blog submodule, обновляем..."
            git pull origin $current_branch
            blog_updated=true
            log_success "Blog submodule обновлен"
        else
            log_info "Blog submodule уже актуален"
        fi
        cd ..
    fi
    
    # Проверяем russiankisa submodule
    if [ -d "russiankisa" ] && [ -f "russiankisa/.git" ]; then
        cd russiankisa
        local current_branch=$(git branch --show-current)
        local remote_commit=$(git rev-parse origin/$current_branch 2>/dev/null)
        local local_commit=$(git rev-parse HEAD)
        
        if [ "$remote_commit" != "$local_commit" ]; then
            log_info "Найдены изменения в russiankisa submodule, обновляем..."
            git pull origin $current_branch
            russiankisa_updated=true
            log_success "Russiankisa submodule обновлен"
        else
            log_info "Russiankisa submodule уже актуален"
        fi
        cd ..
    fi
    
    # Возвращаем информацию об обновлениях
    if [ "$blog_updated" = true ] || [ "$russiankisa_updated" = true ]; then
        return 0
    else
        return 1
    fi
}

# Основная функция обновления
main() {
    log_info "Начинаем проверку обновлений submodules..."
    
    # Обновляем submodules
    update_submodules
    local update_result=$?
    
    local blog_updated=false
    local russiankisa_updated=false
    
    # Проверяем, какие submodules были обновлены
    if [ $update_result -eq 0 ]; then
        # Если были обновления, определяем какие именно
        if [ -d "blog" ] && [ -f "blog/.git" ]; then
            cd blog
            local current_branch=$(git branch --show-current)
            local remote_commit=$(git rev-parse origin/$current_branch 2>/dev/null)
            local local_commit=$(git rev-parse HEAD)
            if [ "$remote_commit" != "$local_commit" ]; then
                blog_updated=true
            fi
            cd ..
        fi
        
        if [ -d "russiankisa" ] && [ -f "russiankisa/.git" ]; then
            cd russiankisa
            local current_branch=$(git branch --show-current)
            local remote_commit=$(git rev-parse origin/$current_branch 2>/dev/null)
            local local_commit=$(git rev-parse HEAD)
            if [ "$remote_commit" != "$local_commit" ]; then
                russiankisa_updated=true
            fi
            cd ..
        fi
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
        
        # Пересобираем только обновленные сервисы последовательно
        if [ "$blog_updated" = true ]; then
            log_info "Пересборка blog..."
            $compose_cmd build blog
            if [ $? -ne 0 ]; then
                log_error "Ошибка при сборке blog"
                exit 1
            fi
        fi
        
        if [ "$russiankisa_updated" = true ]; then
            log_info "Пересборка russiankisa..."
            $compose_cmd build russiankisa
            if [ $? -ne 0 ]; then
                log_error "Ошибка при сборке russiankisa"
                exit 1
            fi
        fi
        
        # Перезапускаем контейнеры
        log_info "Перезапуск контейнеров..."
        $compose_cmd up -d
        
        log_success "Контейнеры перезапущены с обновлениями"
    else
        log_info "Обновлений не найдено"
    fi
}

# Запуск скрипта
main "$@" 