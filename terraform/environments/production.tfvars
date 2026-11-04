# Producao precisa de um projeto GCP (ou VPC) proprio: o peering do
# servicenetworking e unico por VPC, e um segundo na mesma VPC de staging
# sobrescreveria a faixa reservada de staging.
#
# PREENCHER: os valores abaixo vem do repositorio de infra aplicado em producao.

project_id                   = "PREENCHER-projeto-producao"
environment                  = "production"
name_prefix                  = "tech-challenge-production"
network                      = "default"
db_password_secret_id        = "tech-challenge-production-db-password"
app_ci_service_account_email = "PREENCHER-sa-ci-da-app@PREENCHER-projeto-producao.iam.gserviceaccount.com"
deletion_protection          = true
backup_enabled               = true
