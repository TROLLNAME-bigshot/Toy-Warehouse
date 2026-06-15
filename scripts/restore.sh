#!/usr/bin/env bash
# =============================================================================
# restore.sh — Скрипт восстановления системы Toy-Warehouse «из нуля»
#
# Использование:
#   ./scripts/restore.sh <путь_к_дампу.sql.gz>
#
# Пример:
#   ./scripts/restore.sh backups/db/warehouse_db_2026-06-14_02-00-00.sql.gz
#
# ВНИМАНИЕ: Скрипт ПЕРЕСОЗДАЁТ базу данных — все текущие данные будут удалены!
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log()       { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2"; }
log_info()  { log "${BLUE}INFO${NC} " "$1"; }
log_ok()    { log "${GREEN}OK${NC}   " "$1"; }
log_warn()  { log "${YELLOW}WARN${NC} " "$1"; }
log_error() { log "${RED}ERROR${NC}" "$1"; }

if [[ $# -lt 1 ]]; then
    log_error "Не указан путь к файлу дампа."
    echo ""
    echo "  Использование: $0 <путь_к_дампу.sql.gz>"
    echo "  Доступные дампы:"
    find "$(dirname "$0")/../backups/db" -name "*.sql.gz" 2>/dev/null | sort -r | head -10 | sed 's/^/    /'
    exit 1
fi

DUMP_FILE="$1"
[[ ! -f "$DUMP_FILE" ]] && { log_error "Файл дампа не найден: ${DUMP_FILE}"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

ENV_FILE="${PROJECT_DIR}/WarehouseAPI/.env"
if [[ -f "$ENV_FILE" ]]; then
    set -a; source "$ENV_FILE"; set +a
fi

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-warehouse_db}"
DB_USER="${DB_USER:-postgres}"

[[ -z "${DB_PASSWORD:-}" ]] && { log_error "DB_PASSWORD не задан."; exit 1; }
export PGPASSWORD="$DB_PASSWORD"

log_warn "========================================================"
log_warn "  ВНИМАНИЕ! Полное восстановление БД '${DB_NAME}'!"
log_warn "  Источник: $(basename "$DUMP_FILE")"
log_warn "  Цель:     ${DB_USER}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
log_warn "========================================================"
read -rp "Введите 'yes' для подтверждения: " CONFIRM
[[ "$CONFIRM" != "yes" ]] && { log_info "Отменено."; exit 0; }

log_info "Завершение активных подключений к БД..."
psql --host="$DB_HOST" --port="$DB_PORT" --username="$DB_USER" --dbname="postgres" \
     --no-password --quiet \
     --command="SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${DB_NAME}' AND pid <> pg_backend_pid();" \
     > /dev/null 2>&1 || true

log_info "Удаление базы данных '${DB_NAME}'..."
dropdb --host="$DB_HOST" --port="$DB_PORT" --username="$DB_USER" --if-exists --no-password "$DB_NAME"
log_info "Создание новой базы данных '${DB_NAME}'..."
createdb --host="$DB_HOST" --port="$DB_PORT" --username="$DB_USER" --no-password "$DB_NAME"

log_info "Восстановление из дампа: $(basename "$DUMP_FILE")"
if gunzip -c "$DUMP_FILE" | psql --host="$DB_HOST" --port="$DB_PORT" \
    --username="$DB_USER" --dbname="$DB_NAME" --no-password --quiet > /dev/null 2>&1; then
    log_ok "Данные восстановлены успешно!"
else
    log_error "ОШИБКА при восстановлении!"; exit 1
fi

UPLOADS_BACKUP_DIR="${PROJECT_DIR}/backups/uploads"
if [[ -d "$UPLOADS_BACKUP_DIR" ]]; then
    LATEST=$(find "$UPLOADS_BACKUP_DIR" -name "*.tar.gz" | sort -r | head -1)
    if [[ -n "$LATEST" ]]; then
        log_info "Восстановление uploads/ из: $(basename "$LATEST")"
        mkdir -p "${PROJECT_DIR}/uploads"
        tar -xzf "$LATEST" -C "$(dirname "${PROJECT_DIR}/uploads")" 2>/dev/null || true
        log_ok "Медиа-файлы восстановлены."
    fi
fi

unset PGPASSWORD
log_info "========================================================"
log_ok "Восстановление завершено успешно!"
log_info "  Запустите API: cd WarehouseAPI && dotnet run"
log_info "  Swagger: http://localhost:5023/swagger"
log_info "========================================================"
exit 0
