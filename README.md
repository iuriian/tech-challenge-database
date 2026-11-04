# tech-challenge-database

Infraestrutura do PostgreSQL gerenciado (Cloud SQL) do Tech Challenge.

Este repositório provisiona **o banco e o acesso de rede a ele**. O schema não
mora aqui: as tabelas são criadas e versionadas pelo Flyway da aplicação, junto
do código que depende delas.

## Ambientes

| Branch | Ambiente | GitHub Environment | Backend (prefixo no bucket) | Variáveis |
|---|---|---|---|---|
| `release/**` | Homologação | `staging` | `tech-challenge/database/staging` | `environments/staging.tfvars` |
| `main` | Produção | `production` | `tech-challenge/database/production` | `environments/production.tfvars` |

Fluxo: `develop` → `release/x.y` (deploy em homologação) → merge na `main` (deploy em produção).

| Diferença | Homologação | Produção |
|---|---|---|
| `deletion_protection` | `false` | `true` |
| Backups automáticos | não | sim |
| Desligamento automático às 02:00 | sim | não |

⚠️ **Produção precisa de projeto GCP (ou VPC) próprio.** O peering do
`servicenetworking` é único por VPC: um segundo peering na VPC de homologação
sobrescreveria a faixa reservada dela. Preencha `project_id` e
`app_ci_service_account_email` em `environments/production.tfvars` antes do
primeiro deploy (o workflow recusa o placeholder `PREENCHER`).

## Onde este repositório se encaixa

| Ordem | Repositório | Responsabilidade |
|---|---|---|
| 1 | `Tech-Challenge` (`terraform/`) | VPC `default`, cluster GKE, SA do CI da app, segredo `tech-challenge-staging-db-password` |
| 2 | **`tech-challenge-database`** | Peering privado, instância Cloud SQL, banco `oficina`, usuário `oficina_app`, segredo `db-auth-password` |
| 3 | `tech-challenge-auth` | Cloud Run + API Gateway, role `auth_ro` (`sql/auth_ro.sql`) |
| 4 | `Tech-Challenge` (app) | Schema via Flyway, incluindo as views `cliente` e `funcionario` lidas pelo auth |

**Aplique na ordem da tabela.** Este repositório lê a VPC e o segredo da senha
criados pelo passo 1, e o auth lê o segredo `db-auth-password` criado aqui.

## O que é criado

| Recurso | Nome | Observação |
|---|---|---|
| APIs | `sqladmin`, `servicenetworking` | |
| Faixa reservada (PSA) | `tech-challenge-staging-psa-range` | /20 na VPC `default`, para o IP privado do Cloud SQL |
| Peering | `servicenetworking.googleapis.com` | Liga a VPC `default` à rede gerenciada do Google |
| Instância | `tech-challenge-staging-pg` | PostgreSQL 16, Enterprise, `db-f1-micro` |
| Banco | `oficina` | Vazio: o Flyway da app cria o schema |
| Usuário | `oficina_app` | Dono das tabelas. A senha é lida do segredo do passo 1 |
| Segredo | `db-auth-password` | Senha do role `auth_ro`, gerada aqui e usada pelo auth |
| IAM | `roles/cloudsql.viewer` | Para a SA do CI da app descobrir o IP e checar se a instância está ligada |

### O que **não** é criado aqui, e por quê

- **VPC e subnet:** pertencem ao repositório da app, junto do GKE. Aqui são lidas como `data`.
- **Role `auth_ro`:** é criado por SQL (`sql/auth_ro.sql` do auth), não por `google_sql_user`. Usuários criados pela API do Cloud SQL entram no grupo `cloudsqlsuperuser`, o que anularia o `GRANT` por coluna que restringe o auth.
- **Schema:** fica com o Flyway da app.

## Configuração de menor custo

| Decisão | Motivo |
|---|---|
| `db-f1-micro` (shared-core) | Menor tier do Cloud SQL Enterprise, ~US$ 0,0105/h |
| `edition = ENTERPRISE` explícito | Para Postgres 16+, o padrão pode ser Enterprise Plus, mais cara e sem shared-core |
| Zonal, sem HA | HA dobra o custo de instância e disco |
| HDD de 10 GB, sem autoresize | Mínimo permitido; o disco nunca cresce sozinho na fatura |
| Sem backups | O ambiente é recriável e o Flyway reconstrói o schema |
| Somente IP privado | Sem exposição na internet e sem custo de IP |
| **Desligada quando não está em uso** | Desligada, cobra só o disco |

| Cenário | Custo aproximado/mês |
|---|---|
| Desligada o mês inteiro | ~US$ 0,90 |
| Ligada ~40 h no mês | ~US$ 1,30 |
| Esquecida ligada o mês todo | ~US$ 8,60 |

Valores de referência em `us-central1`. Confirme no
[Google Cloud Pricing Calculator](https://cloud.google.com/products/calculator)
e configure um **alerta de orçamento** no Billing.

## Conectividade

A instância tem **apenas IP privado**, alcançável pela VPC `default` via peering.

| Consumidor | Como alcança o banco | Usuário |
|---|---|---|
| App (GKE) | Pods VPC-native acessam o IP privado diretamente | `oficina_app` |
| Auth (Cloud Run) | Direct VPC egress na subnet `default`, `--vpc-egress=private-ranges-only` | `auth_ro` (somente leitura, por coluna) |
| Você (debug) | Túnel por um pod no GKE: `./scripts/cloudsql.sh tunnel` | qualquer um |

Todas as conexões exigem TLS (`ssl_mode = ENCRYPTED_ONLY`): use `sslmode=require` no JDBC.

⚠️ **Cuidado com o Cloud NAT:** no Cloud Run, mantenha `private-ranges-only`. Com
`all-traffic`, toda saída para a internet passa pela VPC e exige Cloud NAT, que
custa mais que a própria instância.

### Limite de conexões

A `db-f1-micro` aceita 25 conexões, com 3 reservadas para administração.

| Consumidor | Cálculo | Conexões |
|---|---|---|
| App | 3 pods (HPA) × pool 4 | 12 |
| Auth | 3 instâncias × pool 2 | 6 |
| **Total** | | **18 de ~22** |

Ao aumentar réplicas, pools ou instâncias, refaça essa conta ou suba o tier
para `db-g1-small` (50 conexões) em `var.db_tier`.

## Estrutura

```
.github/workflows/
  terraform-ci.yml       # PR: fmt, validate e plan (PR p/ main -> produção; demais -> homologação)
  terraform-cd.yml       # release/** -> homologação, main -> produção (plan + apply)
  cloudsql-power.yml     # homologação: liga/desliga manual + desligamento automático às 02:00 (Brasília)
terraform/
  versions.tf            # providers e backend GCS (parcial: bucket/prefix no .tfbackend)
  variables.tf
  apis.tf
  network.tf             # faixa PSA + peering
  cloudsql.tf            # instância, banco e usuário oficina_app
  secrets.tf             # db-auth-password
  iam.tf                 # cloudsql.viewer para o CI da app
  outputs.tf
  environments/
    staging.tfvars             staging.gcs.tfbackend      # homologação
    production.tfvars          production.gcs.tfbackend   # produção
scripts/
  cloudsql.sh            # on | off | status | tunnel
  migrate-from-k8s.sh    # cópia única do Postgres que rodava no GKE
```

## Pré-requisitos

- Passo 1 (repositório da app, `terraform/`) já aplicado: VPC `default` e segredo `tech-challenge-staging-db-password` existem.
- Bucket de state `tech-challenge-507123-tfstate` criado, com versionamento.
- Terraform >= 1.9, `gcloud` e, para o túnel, `kubectl` apontando para o cluster.

## Bootstrap (uma vez)

Service account do pipeline deste repositório:

```bash
PROJECT=tech-challenge-507123
SA=github-actions-database@${PROJECT}.iam.gserviceaccount.com

gcloud iam service-accounts create github-actions-database \
  --project "$PROJECT" --display-name "GitHub Actions - tech-challenge-database"

for ROLE in \
  roles/cloudsql.admin \
  roles/compute.networkAdmin \
  roles/servicenetworking.networksAdmin \
  roles/serviceusage.serviceUsageAdmin \
  roles/secretmanager.admin \
  roles/resourcemanager.projectIamAdmin; do
  gcloud projects add-iam-policy-binding "$PROJECT" \
    --member "serviceAccount:$SA" --role "$ROLE" --condition=None
done

# State: acesso só ao bucket, não ao projeto inteiro
gcloud storage buckets add-iam-policy-binding gs://${PROJECT}-tfstate \
  --member "serviceAccount:$SA" --role roles/storage.objectAdmin

# Chave para o GitHub (apague o arquivo depois de cadastrar)
gcloud iam service-accounts keys create sa-key.json --iam-account "$SA"
```

| Papel | Para quê |
|---|---|
| `cloudsql.admin` | instância, banco, usuário, liga/desliga |
| `compute.networkAdmin` | faixa reservada |
| `servicenetworking.networksAdmin` | peering |
| `serviceUsageAdmin` | habilitar APIs |
| `secretmanager.admin` | criar `db-auth-password` e ler a senha do `oficina_app` |
| `projectIamAdmin` | conceder `cloudsql.viewer` ao CI da app |

Para produção, repita o bootstrap no projeto de produção (mesmos papéis) e dê
à SA de produção `roles/storage.objectAdmin` no bucket de state.

### GitHub: Environments `staging` e `production`

Crie os dois Environments com os mesmos nomes de secret/variable, cada um com a
chave e o projeto do seu ambiente.

| Tipo | Nome | Valor |
|---|---|---|
| secret | `GCP_SA_KEY` | conteúdo do `sa-key.json` |
| variable | `GCP_PROJECT_ID` | `tech-challenge-507123` |

Configure **Required reviewers** no Environment `production` para que o deploy
em produção peça aprovação. Como o CI também usa o Environment do alvo do PR,
PRs para a `main` também vão pedir aprovação para rodar o `plan`.

## Uso

| Ação | Local | GitHub |
|---|---|---|
| Init | `terraform -chdir=terraform init -reconfigure -backend-config=environments/<amb>.gcs.tfbackend` | — |
| Plano | `terraform -chdir=terraform plan -var-file=environments/<amb>.tfvars` | abrir PR |
| Aplicar em homologação | `terraform -chdir=terraform apply -var-file=environments/staging.tfvars` | push em `release/**` |
| Aplicar em produção | `terraform -chdir=terraform apply -var-file=environments/production.tfvars` | merge na `main` |
| Ligar | `./scripts/cloudsql.sh on` | Actions → Cloud SQL - Liga/Desliga → `on` |
| Desligar | `./scripts/cloudsql.sh off` | idem → `off` (e automaticamente às 02:00) |
| Estado | `./scripts/cloudsql.sh status` | idem → `status` |
| Túnel de debug | `./scripts/cloudsql.sh tunnel` → `localhost:5433` | — |
| Migração inicial | `./scripts/migrate-from-k8s.sh` | — |

**Ligue a instância antes de um `apply` local.** Com ela desligada, o Terraform
não consegue atualizar o banco nem o usuário. O `terraform-cd.yml` faz isso
sozinho e restaura o estado original ao final. Ele planeja antes de ligar: se o
`plan` não acusa mudança, a instância nem é acordada.

Use `-reconfigure` ao trocar de ambiente localmente: sem ele, o Terraform
continua apontando para o state do ambiente anterior.

Pela mesma razão, a app e o auth ficam indisponíveis enquanto a instância está
desligada. O `cd-staging.yml` da app falha com uma mensagem clara nesse caso.

## Outputs

| Output | Usado por |
|---|---|
| `instance_name` | scripts e workflows |
| `private_ip` | app: `DB_HOST` (o `cd-staging.yml` descobre sozinho) |
| `auth_db_url` | auth: variable `DB_URL` do Environment `staging` |
| `auth_db_secret` | auth: nome do segredo da senha do `auth_ro` |
| `connection_name` | reservado para Cloud SQL Auth Proxy |
| `database`, `user` | conferência |

## Depois do primeiro `apply`

1. Deploy da app (push em `release/**`): o Flyway cria as tabelas e as views `cliente` e `funcionario`.
2. Criar o role `auth_ro`, a partir do repositório **auth**:
   ```bash
   # terminal 1 (este repositório)
   ./scripts/cloudsql.sh tunnel

   # terminal 2 (repositório tech-challenge-auth)
   PGPASSWORD="$(gcloud secrets versions access latest --secret=tech-challenge-staging-db-password)" \
   psql "host=localhost port=5433 dbname=oficina user=oficina_app sslmode=require" \
     -v senha="$(gcloud secrets versions access latest --secret=db-auth-password)" \
     -f sql/auth_ro.sql
   ```
3. Configurar `DB_URL` (output `auth_db_url`) no Environment do auth e fazer o deploy.

## Limitações e próximos passos

- [ ] Trocar a chave de SA (`GCP_SA_KEY`) por Workload Identity Federation
- [ ] Alerta de orçamento no Billing
- [ ] Backups automáticos, caso o ambiente passe a guardar dados que não possam ser recriados
- [ ] `db-f1-micro` não tem SLA: em produção, usar tier dedicado e `availability_type = REGIONAL`