#!/bin/bash
set -e

PGPASSWORD=1qaz2wsx psql -v ON_ERROR_STOP=1 --username hub <<-EOSQL
    CREATE DATABASE airflow;
    CREATE USER airflow WITH ENCRYPTED PASSWORD 'airflow';
    GRANT ALL PRIVILEGES ON DATABASE airflow TO airflow;
EOSQL