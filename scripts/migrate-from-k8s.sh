#!/usr/bin/env bash
#
# Copia UNICA dos dados do Postgres que roda no GKE para o Cloud SQL.
# Rode ANTES do primeiro deploy da app apontando para o Cloud SQL; se o Flyway
# rodar antes, ele cria tabelas vazias e o restore conflita.
#
# Pre-requisitos: kubectl no cluster, Cloud SQL ligado, terraform apply feito.
#
set -euo pipefail

NS="${NAMESPACE:-tech-challenge-staging}"
INSTANCE="${INSTANCE:-tech-challenge-staging-pg}"
SECRET="${SECRET:-tech-challenge-staging-db-password}"
OLD_USER="${OLD_USER:-user}"
NEW_USER="${NEW_USER:-oficina_app}"
DB="${DB:-oficina}"

IP=$(gcloud sql instances describe "$INSTANCE" --format="value(ipAddresses[0].ipAddress)")
PASS=$(gcloud secrets versions access latest --secret="$SECRET")

echo "==> Parando a app (ninguem escreve durante a copia)"
kubectl delete hpa app -n "$NS" --ignore-not-found
kubectl scale deploy/app -n "$NS" --replicas=0

echo "==> Copiando $DB: pod postgres -> Cloud SQL $IP"
# --no-owner/--no-acl: o dono antigo ("user") nao existe no Cloud SQL.
kubectl exec -n "$NS" deploy/postgres -- sh -c \
  "pg_dump -U '$OLD_USER' -d '$DB' --no-owner --no-acl \
   | PGPASSWORD='$PASS' PGSSLMODE=require psql -h '$IP' -U '$NEW_USER' -d '$DB' -v ON_ERROR_STOP=1 -q"

echo "==> Conferindo historico do Flyway no destino"
kubectl exec -n "$NS" deploy/postgres -- sh -c \
  "PGPASSWORD='$PASS' PGSSLMODE=require psql -h '$IP' -U '$NEW_USER' -d '$DB' \
   -c 'select version, description, success from flyway_schema_history order by installed_rank'"

echo ""
echo "Proximo passo: deploy da app (push em release/**)."
echo "Depois de validar: kubectl delete deploy/postgres svc/postgres pvc/postgres-data configmap/postgres-initdb -n $NS"