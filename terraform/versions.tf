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

  backend "gcs" {
    bucket = "tech-challenge-507123-tfstate"
    prefix = "tech-challenge/database/staging"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}