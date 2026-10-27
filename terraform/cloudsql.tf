data "google_secret_manager_secret_version" "db_password" {
  secret = var.db_password_secret_id
}

resource "google_sql_database_instance" "main" {
  name                = "${var.name_prefix}-pg"
  database_version    = "POSTGRES_16"
  region              = var.region
  deletion_protection = false # staging descartavel

  settings {
    edition           = "ENTERPRISE" # explicito: Enterprise Plus nao aceita db-f1-micro
    tier              = var.db_tier
    availability_type = "ZONAL"
    disk_type         = "PD_HDD"
    disk_size         = 10
    disk_autoresize   = false

    location_preference {
      zone = var.zone
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = data.google_compute_network.vpc.id
      ssl_mode        = "ENCRYPTED_ONLY"
    }

    backup_configuration {
      enabled = false # o Flyway reconstroi o schema
    }

    user_labels = {
      environment = "staging"
      managed-by  = "terraform"
      repository  = "tech-challenge-database"
    }
  }

  lifecycle {
    ignore_changes = [settings[0].activation_policy]
  }

  depends_on = [
    google_service_networking_connection.private_services,
    google_project_service.sqladmin,
  ]
}

resource "google_sql_database" "app" {
  name     = var.db_name
  instance = google_sql_database_instance.main.name
}

resource "google_sql_user" "app" {
  name            = var.db_user
  instance        = google_sql_database_instance.main.name
  password        = data.google_secret_manager_secret_version.db_password.secret_data
  deletion_policy = "ABANDON"
}