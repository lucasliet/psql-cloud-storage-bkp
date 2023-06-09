#!/bin/bash

DATABASE_URL=$1
DATABASE_USER=$2
export PGPASSWORD=$3
DATABASE_NAME=$4
BACKUP_BUCKET=$5
BACKUP_UNTIL_DATE=$6-$(date +%d)

if [[ -z "$DATABASE_URL" || -z "$DATABASE_USER" || -z "$PGPASSWORD" || -z "$DATABASE_NAME" || -z "$BACKUP_BUCKET" || -z "$BACKUP_UNTIL_DATE" ]]; then
  echo "Usage: ./backup.sh <DATABASE_URL eg: 11.111.111.111> <DATABASE_USER eg: 'user'> <DATABASE_PASSWORD eg: 'pass'> <DATABASE_NAME eg: 'db_name'> <BACKUP_BUCKET eg: 'backup-bucket'> <BACKUP_UNTIL_DATE eg: 2022-01>"
  exit 1
fi

echo "Starting $DATABASE_NAME backup"

CURRENT_DATE=$(date +%F)
TABLES=($(psql -h $DATABASE_URL -U $DATABASE_USER -w -d $DATABASE_NAME -c "\dt" | sed -n 's/^[^|]*| *\([^|]*\)|.*$/\1/p' | grep -v Name | xargs))
SCHEMA_FILE_NAME_PATH=gs://$BACKUP_BUCKET/$DATABASE_NAME-dump/$DATABASE_NAME-schema.sql.gz

echo "Tables to backup: ${TABLES[@]}"

pg_dump -h $DATABASE_URL -U $DATABASE_USER -w --schema-only $DATABASE_NAME \
| gzip | gsutil -q cp -z gzip \
- $SCHEMA_FILE_NAME_PATH

echo "$DATABASE_NAME schema has been backed up to $SCHEMA_FILE_NAME_PATH"
echo

for TABLE in ${TABLES[@]}; do
  echo "Backing up $TABLE table"
  while [ "$CURRENT_DATE" != "$BACKUP_UNTIL_DATE" ]; do
    START_TIME=$(date +%s)
    CURRENT_MONTH=$(date -d "$CURRENT_DATE" +%Y-%m)-01
    LAST_MONTH=$(date -d "$CURRENT_DATE -1 month" +%Y-%m)-01
    BACKUP_FILE_PATH=gs://$BACKUP_BUCKET/$DATABASE_NAME-dump/tables/$TABLE/$TABLE-$(date -d "$CURRENT_DATE -1 month" +%Y-%m).csv.gz

    if gsutil -q stat $BACKUP_FILE_PATH; then
      echo "File $BACKUP_FILE_PATH already exists, skipping backup"
      echo
      CURRENT_DATE=$(date -d "$CURRENT_DATE -1 month" +%F)
      continue
    fi 

    echo "Backing up $LAST_MONTH of table $TABLE"
    echo "WHERE created_at >= '$LAST_MONTH' AND created_at < '$CURRENT_MONTH'"
    echo "Destination file $BACKUP_FILE_PATH"
    
    psql -h $DATABASE_URL -U $DATABASE_USER -w -d $DATABASE_NAME \
    -c "COPY (SELECT * FROM $TABLE WHERE created_at >= '$LAST_MONTH' AND created_at < '$CURRENT_MONTH') TO STDOUT WITH (DELIMITER ';', FORMAT CSV);" \
    | gzip | gsutil -q cp -z gzip -s archive \
    - $BACKUP_FILE_PATH

    BACKUP_FILE_SIZE=$(gsutil du $BACKUP_FILE_PATH | awk '{print $1}')

    echo "Backup took $(($(date +%s) - $START_TIME)) seconds with $BACKUP_FILE_SIZE bytes"
    echo

    CURRENT_DATE=$(date -d "$CURRENT_DATE -1 month" +%F)
  done
  CURRENT_DATE=$(date +%F)
done

echo "Finished dump to gs://$BACKUP_BUCKET/$DATABASE_NAME-dump"