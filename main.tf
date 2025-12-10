provider "google" {
  project = var.project_id
  region  = var.region
}

# -- APIs --

# Enable the Firestore API automatically
resource "google_project_service" "firestore" {
  project            = var.project_id
  service            = "firestore.googleapis.com"
  disable_on_destroy = false
}

# Enable Secret Manager API
resource "google_project_service" "secret_manager" {
  project            = var.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# Enable Cloud Run & Cloud Build APIs
resource "google_project_service" "cloud_run" {
  project            = var.project_id
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloud_build" {
  project            = var.project_id
  service            = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

# Enable Artifact Registry API
resource "google_project_service" "artifact_registry" {
  project            = var.project_id
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

# Enable IAM API
resource "google_project_service" "iam" {
  project            = var.project_id
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}

# -- Services --

# Create the Firestore Native Database
resource "google_firestore_database" "database" {
  project                     = var.project_id
  name                        = "(default)"
  location_id                 = var.region
  type                        = "FIRESTORE_NATIVE"
  concurrency_mode            = "OPTIMISTIC"
  app_engine_integration_mode = "DISABLED"

  depends_on = [google_project_service.firestore]
}

# Create the Luca's Artifact Registry Repository
resource "google_artifact_registry_repository" "repository" {
  provider     = google
  location     = var.region
  repository_id = var.luca_artifact_registry_name
  description  = "Artifact Registry for Cloud Run service images"
  format       = "DOCKER"
  mode         = "STANDARD"

  depends_on = [google_project_service.artifact_registry]
}

# Create a Secret Manager secret to store sensitive configuration
resource "google_secret_manager_secret" "luca_config_secret" {
  secret_id = var.luca_secret_name
  replication {
    auto {}
  }
  depends_on = [google_project_service.secret_manager]
}

# Luca's Github Actions Service Account
resource "google_service_account" "github_actions_sa" {
  account_id   = var.luca_github_actions_sa_name
  display_name = "Luca Github Actions Service Account"

  depends_on = [google_project_service.iam]
}

# Grant IAM roles to the Service Account
resource "google_project_iam_member" "github_actions_sa_roles" {
  for_each = toset(var.luca_github_actions_sa_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_actions_sa.email}"
}