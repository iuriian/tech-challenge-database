variable "project_id" {
  description = "ID do projeto GCP"
  type        = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "zone" {
  description = "Mesma zona dos nos do GKE: menor latencia e trafego gratuito"
  type        = string
  default     = "us-central1-a"
}

variable "network" {
  description = "VPC do GKE (criada pelo repositorio de infra)"
  type        = string
  default     = "default"
}

variable "name_prefix" {
  type    = string
  default = "tech-challenge-staging"
}

variable "db_tier" {
  description = "db-f1-micro: 25 conexoes, ~US$ 0,0105/h. Alternativa: db-g1-small"
  type        = string
  default     = "db-f1-micro"
}

variable "db_name" {
  type    = string
  default = "oficina"
}

variable "db_user" {
  description = "Deve casar com o POSTGRES_USER do cd-staging.yml da app"
  type        = string
  default     = "oficina_app"
}

variable "db_password_secret_id" {
  description = "Segredo criado pelo repositorio de infra (secrets.tf)"
  type        = string
  default     = "tech-challenge-staging-db-password"
}

variable "app_ci_service_account_email" {
  description = "SA do GitHub Actions da app (output ci_service_account_email do repo de infra)"
  type        = string
}