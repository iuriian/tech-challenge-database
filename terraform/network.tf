data "google_compute_network" "vpc" {
  name = var.network
}

resource "google_compute_global_address" "private_services" {
  name          = "${var.name_prefix}-psa-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 20
  network       = data.google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_services" {
  network                 = data.google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services.name]
  deletion_policy         = "ABANDON"

  depends_on = [google_project_service.servicenetworking]
}