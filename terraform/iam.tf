resource "google_project_iam_member" "app_ci_cloudsql_viewer" {
  project = var.project_id
  role    = "roles/cloudsql.viewer"
  member  = "serviceAccount:${var.app_ci_service_account_email}"
}