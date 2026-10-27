resource "random_password" "auth_ro" {
  length  = 32
  special = false # evita escaping em URL JDBC e em shell
}

resource "google_secret_manager_secret" "db_auth" {
  secret_id = "db-auth-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_auth" {
  secret      = google_secret_manager_secret.db_auth.id
  secret_data = random_password.auth_ro.result
}