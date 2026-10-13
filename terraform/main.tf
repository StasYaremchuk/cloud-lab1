# 1. Реєстр для Docker-образів
resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = "cloud-lab1-repo"
  format        = "DOCKER"
  description   = "Docker repository for cloud-lab1"
}

# 2. Інстанс Cloud SQL (Postgres)
resource "google_sql_database_instance" "db" {
  name             = "cloud-lab1-db"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier = "db-f1-micro" # Найдешевший і найпростіший тариф
  }

  deletion_protection = false # Дозволяємо видалення через terraform destroy
}

# 3. Користувач для бази даних
resource "google_sql_user" "db_user" {
  name     = "appuser"
  instance = google_sql_database_instance.db.name
  password = var.db_password
}

# 4. База даних (наприклад, planesdb)
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

    containers {
      # Образ з нашого Artifact Registry
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.repo.repository_id}/cloud-lab1-app:latest"

      env {
        name  = "DATABASE_URL"
        value = "postgres://appuser:${var.db_password}@localhost/planesdb?host=/cloudsql/${google_sql_database_instance.db.connection_name}"
      }
      env {
        name  = "PORT"
        value = "3000"
      }
    }

    # Підключення Cloud SQL через вбудований механізм Cloud Run
    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.db.connection_name]
      }
    }
  }
}

# 8. Дозволяємо публічний доступ до нашого сервісу
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  location = google_cloud_run_v2_service.app.location
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}