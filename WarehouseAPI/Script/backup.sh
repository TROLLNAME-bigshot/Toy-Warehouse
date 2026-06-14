
source .env
BACKUP_DIR="./backups"
DATE=$(date +"%Y%m%d_%H%M%S")

mkdir -p $BACKUP_DIR

# Дамп базы данных
PGPASSWORD=$DB_PASSWORD pg_dump -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME > $BACKUP_DIR/db_backup_$DATE.sql

# Архив медиа-файлов (если есть)
if [ -d "./uploads" ]; then
    tar -czf $BACKUP_DIR/uploads_backup_$DATE.tar.gz ./uploads
fi

echo "Бэкап создан: $BACKUP_DIR/db_backup_$DATE.sql"