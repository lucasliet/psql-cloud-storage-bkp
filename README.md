# Backup CloudSQL

Script criado para realização de backup de bancos postgreSQL no Google Cloud Storage

## Pacotes requisitados
- bash
- date
- psql e pg_dump
- gsutil e gcloud

## Utilização
- Criar um bucket no Google Cloud Storage
- Authenticar-se no Google Cloud com uma conta que tenha acesso ao bucket `gsutil auth login --project <project_id>`
- Conectar-se a VPN de utilização do banco de dados
- Executar o script passando os parametros necessários `./backup.sh <DATABASE_URL eg: 11.111.111.111> <DATABASE_USER eg: 'user'> <DATABASE_PASSWORD eg: 'pass'> <DATABASE_NAME eg: 'db_name'> <BACKUP_BUCKET eg: 'backup-bucket'> <BACKUP_UNTIL_DATE eg: 1970-01>`

## Estrutura de pastas de backup
após execução do script a seguinte estrutura de pastas será criada no bucket de backup:
```
<BACKUP_BUCKET>
    └── <DATABASE_NAME>-dump
            ├── <DATABASE_NAME>-schema.sql.gz
            └── tables
                    ├── <TABLE_NAME_1>
                    │       ├── <TABLE_NAME_1>-<MONTH-1>.csv.gz
                    │       ├── <TABLE_NAME_1>-<MONTH-2>.csv.gz
                    │       ...
                    ├── <TABLE_NAME_2>
                    │       ├── <TABLE_NAME_2>-<MONTH-1>.csv.gz
                    │       ├── <TABLE_NAME_2>-<MONTH-2>.csv.gz
                    │       ...
                    ...
```
