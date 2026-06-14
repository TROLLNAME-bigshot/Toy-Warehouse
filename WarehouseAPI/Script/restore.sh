
source .env
BACKUP_DIR="./backups"

echo "db_backup_20260610_143000.sql"
read BACKUP_FILE

# Восстановление базы данных
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME < $BACKUP_DIR/$BACKUP_FILE

# Восстановление медиа-файлов (если есть)
if [ -f "$BACKUP_DIR/uploads_backup_*.tar.gz" ]; then
    tar -xzf $BACKUP_DIR/uploads_backup_*.tar.gz -C ./
fi

echo "Восстановление завершено"