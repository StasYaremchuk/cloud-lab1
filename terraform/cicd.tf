# 1. Сервісний акаунт для GitHub Actions
resource "google_service_account" "github_actions_sa" {
  account_id   = "github-actions-sa"
  display_name = "Service Account for GitHub Actions"
}

# 2. Надаємо цьому SA необхідні права
resource "google_project_iam_member" "github_actions_roles" {
  for_each = toset([
    "roles/artifactregistry.writer",
    "roles/run.admin",
    "roles/iam.serviceAccountUser",
  ])
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.github_actions_sa.email}"
}

# 3. Пул Workload Identity
resource "google_iam_workload_identity_pool" "github_pool" {
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Identity pool for GitHub Actions"
}

# 4. Провайдер Workload Identity для GitHub OIDC
resource "google_iam_workload_identity_pool_provider" "github_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Provider"
  attribute_condition = "assertion.repository == 'StasYaremchuk/cloud-lab1'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }
}

# 5. Дозволяємо GitHub видавати себе за цей SA
resource "google_service_account_iam_member" "github_actions_workload_identity" {
  service_account_id = google_service_account.github_actions_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/*"
}