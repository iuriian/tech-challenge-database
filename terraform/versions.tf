terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # bucket e prefix vem de environments/<ambiente>.gcs.tfbackend
  backend "gcs" {}
}

provider "google" {
  project = var.project_id
  region  = var.region
}