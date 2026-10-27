output "instance_name" {
  value = google_sql_database_instance.main.name
}

output "private_ip" {
  description = "Host usado pela app (DB_HOST)"
  value       = google_sql_database_instance.main.private_ip_address
}

output "connection_name" {
  description = "Para Cloud SQL Auth Proxy, se um dia for usado"
  value       = google_sql_database_instance.main.connection_name
}

output "database" {
  value = google_sql_database.app.name
}

output "user" {
  value = google_sql_user.app.name
}

output "auth_db_url" {
  description = "Valor da variable DB_URL do Environment staging no repo auth"
  value       = "jdbc:postgresql://${google_sql_database_instance.main.private_ip_address}:5432/${google_sql_database.app.name}?sslmode=require"
}

output "auth_db_secret" {
  value = google_secret_manager_secret.db_auth.secret_id
}