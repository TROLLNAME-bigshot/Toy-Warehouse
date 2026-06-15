#!/usr/bin/env bash
# =============================================================================
# backup.sh — Скрипт автоматизированного резервного копирования
#             системы Toy-Warehouse (PostgreSQL + uploads)
#
# Использование:
#   ./scripts/backup.sh
#
# Для запуска по расписанию добавьте в crontab (crontab -e):
#   0 2 * * * /opt/warehouse/scripts/backup.sh >> /opt/warehouse/backups/backup.log 2>&1
#
# Требования:
#   - pg_dump (из пакета postgresql-client)
#   - Переменные окружения из ../.env
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log()       { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2"; }
log_info()  { log "${BLUE}INFO${NC} " "$1"; }
log_ok()    { log "${GREEN}OK${NC}   " "$1"; }
log_warn()  { log "${YELLOW}WARN${NC} " "$1"; }
log_error() { log "${RED}ERROR${NC}" "$1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${PROJECT_DIR}/backups"
DB_BACKUP_DIR="${BACKUP_DIR}/db"
UPLOADS_BACKUP_DIR="${BACKUP_DIR}/uploads"
RETENTION_DAYS=7

# Загрузка .env
ENV_FILE="${PROJECT_DIR}/WarehouseAPI/.env"
if [[ -f "$ENV_FILE" ]]; then
    log_info "Загрузка конфигурации из ${ENV_FILE}"
    set -a; source "$ENV_FILE"; set +a
else
    log_warn "Файл .env не найден: ${ENV_FILE}. Используются переменные среды."
fi

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-warehouse_db}"
DB_USER="${DB_USER:-postgres}"

if [[ -z "${DB_PASSWORD:-}" ]]; then
    log_error "Переменная DB_PASSWORD не задана. Резервное копирование невозможно."
    exit 1
fi

export PGPASSWORD="$DB_PASSWORD"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
DB_DUMP_FILE="${DB_BACKUP_DIR}/warehouse_db_${TIMESTAMP}.sql.gz"
UPLOADS_ARCHIVE="${UPLOADS_BACKUP_DIR}/uploads_${TIMESTAMP}.tar.gz"
UPLOADS_DIR="${PROJECT_DIR}/uploads"

mkdir -p "$DB_BACKUP_DIR" "$UPLOADS_BACKUP_DIR"

log_info "========================================================"
log_info "  Toy-Warehouse — Резервное копирование"
log_info "  Дата: $(date '+%Y-%m-%d %H:%M:%S')"
log_info "========================================================"
log_info "Начало резервного копирования PostgreSQL..."
log_info "  Источник: ${DB_USER}@${DB_HOST}:${DB_PORT}/${DB_NAME}"

if pg_dump --host="$DB_HOST" --port="$DB_PORT" --username="$DB_USER" \
           --dbname="$DB_NAME" --format=plain --no-password 2>/dev/null \
           | gzip > "$DB_DUMP_FILE"; then
    DUMP_SIZE=$(du -sh "$DB_DUMP_FILE" | cut -f1)
    log_ok "Дамп БД создан: ${DB_DUMP_FILE} (${DUMP_SIZE})"
else
    log_error "ОШИБКА: не удалось создать дамп базы данных!"
    exit 1
fi

if [[ -d "$UPLOADS_DIR" ]]; then
    if tar -czf "$UPLOADS_ARCHIVE" -C "$(dirname "$UPLOADS_DIR")" \
              "$(basename "$UPLOADS_DIR")" 2>/dev/null; then
        log_ok "Архив медиа-файлов создан: ${UPLOADS_ARCHIVE}"
    else
        log_warn "Не удалось создать архив uploads/."
    fi
else
    log_warn "Директория uploads/ не найдена. Пропускаем архивацию медиа-файлов."
fi

log_info "Ротация резервных копий старше ${RETENTION_DAYS} дней..."
DELETED=0
while IFS= read -r f; do rm -f "$f"; log_info "  Удалён: $(basename "$f")"; ((DELETED++)); done \
    < <(find "$DB_BACKUP_DIR" -name "*.sql.gz" -mtime +"$RETENTION_DAYS")
while IFS= read -r f; do rm -f "$f"; ((DELETED++)); done \
    < <(find "$UPLOADS_BACKUP_DIR" -name "*.tar.gz" -mtime +"$RETENTION_DAYS" 2>/dev/null)
[[ $DELETED -eq 0 ]] && log_info "  Устаревших копий не найдено." || log_ok "  Удалено: ${DELETED}"

TOTAL=$(find "$DB_BACKUP_DIR" -name "*.sql.gz" | wc -l)
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
log_info "========================================================"
log_ok "Резервное копирование завершено успешно!"
log_info "  Дампов БД хранится: ${TOTAL} | Размер backups/: ${TOTAL_SIZE}"
log_info "========================================================"
unset PGPASSWORD
exit 0
