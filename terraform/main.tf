# 1. Реєстр для Docker-образів
resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = "cloud-lab1-repo"
  format        = "DOCKER"
  description   = "Docker repository for cloud-lab1"
}

# 2. Інстанс Cloud SQL (Postgres) — тільки приватний IP
resource "google_sql_database_instance" "db" {
  name             = "cloud-lab1-db"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier = "db-f1-micro"

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
    }
  }

  deletion_protection = false

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

# 3. Користувач для бази даних
resource "google_sql_user" "db_user" {
  name     = "appuser"
  instance = google_sql_database_instance.db.name
  password = var.db_password
}

# 4. База даних
resource "google_sql_database" "database" {
  name     = "planesdb"
  instance = google_sql_database_instance.db.name
}

# 5. Service Account для Cloud Run, щоб він міг підключатися до Cloud SQL
resource "google_service_account" "cloud_run_sa" {
  account_id   = "cloud-run-sa"
  display_name = "Cloud Run Service Account"
}

# 6. Надаємо цьому Service Account права на підключення до Cloud SQL
resource "google_project_iam_member" "cloud_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# 7. Сервіс Cloud Run, який запускає наш контейнер
resource "google_cloud_run_v2_service" "app" {
  name     = "cloud-lab1-app"
  location = var.region

  template {
    service_account = google_service_account.cloud_run_sa.email

    # Підключення до VPC через connector (для private IP Cloud SQL)
    vpc_access {
      connector = google_vpc_access_connector.connector.id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.repo.repository_id}/cloud-lab1-app:latest"

      env {
        name  = "DATABASE_URL"
        value = "postgres://appuser:${var.db_password}@${google_sql_database_instance.db.private_ip_address}:5432/planesdb"
      }
    }
  }

  depends_on = [google_vpc_access_connector.connector]
}
# 8. Дозволяємо публічний доступ до нашого сервісу
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  location = google_cloud_run_v2_service.app.location
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}