variable "project_id" {
  description = "The GCP Project ID"
  type        = string
}

variable "region" {
  description = "The region for resources"
  type        = string
  default     = "us-east4"
}

variable "luca_artifact_registry_name" {
  description = "The name of the Artifact Registry repository"
  type        = string
  default     = "luca-artifact-repo"
}

variable "luca_secret_name" {
  description = "The name of the Secret Manager secret for Luca"
  type        = string
  default     = "luca-secret"
}

variable "luca_github_actions_sa_name" {
  description = "The name of the Service Account for GitHub actionss"
  type        = string
  default     = "luca-github-actions-sa"
}

variable "luca_github_actions_sa_roles" {
  description = "The roles to assign to the GitHub Actions Service Account"
  type        = list(string)
  default = [
    "roles/run.admin",
    "roles/iam.serviceAccountUser",
    "roles/iam.serviceAccountTokenCreator",
    "roles/artifactregistry.writer",
    "roles/secretmanager.secretAccessor",
    "roles/secretmanager.secretVersionAdder",
  ]
}