terraform {
  required_version = ">= 1.11.3"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  backend "gcs" {
    bucket = "practice-terraform-2025-a-terraform-state"
    prefix = "artifact-registry"
  }
}

provider "google" {
  project = local.project_id
  region  = local.region
}

# NPMパッケージ用のArtifact Registryリポジトリを作成
resource "google_artifact_registry_repository" "npm_repo" {
  project       = local.project_id
  location      = local.region
  repository_id = "${local.name}-npm-packages"
  description   = "NPM package repository for ${local.name}"
  format        = "NPM"
}

# GitHub Actionsからのアクセス権を付与
resource "google_artifact_registry_repository_iam_binding" "npm_writers" {
  project    = local.project_id
  location   = google_artifact_registry_repository.npm_repo.location
  repository = google_artifact_registry_repository.npm_repo.name
  role       = "roles/artifactregistry.writer"

  members = [
    "serviceAccount:${google_service_account.github_service_account.email}"
  ]
}

# GitHubが利用するサービスアカウント
resource "google_service_account" "github_service_account" {
  account_id   = "github-actions-sa"
  display_name = "GitHub Actions Service Account"
}

# Workload Identity Poolの設定
resource "google_iam_workload_identity_pool" "github_pool" {
  project                   = local.project_id
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Workload Identity Pool"
  description               = "Allows GitHub Actions to authenticate to Google Cloud"
}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  project                            = local.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Provider"
  description                        = "Provider for GitHub Actions"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }

  attribute_condition = "attribute.repository == \"${local.github_org}/${local.github_repository}\""
}

# サービスアカウントのIAM設定
resource "google_service_account_iam_binding" "github_sa_binding" {
  for_each = toset([
    "roles/iam.workloadIdentityUser",
    # "roles/artifactregistry.writer"
  ])
  service_account_id = google_service_account.github_service_account.name
  role               = each.value

  members = [
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository/${local.github_org}/${local.github_repository}"
  ]
}

# GitHubサービスアカウントにArtifact Registryの権限を付与
resource "google_project_iam_member" "github_sa_ar_writer" {
  project = local.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.github_service_account.email}"
}