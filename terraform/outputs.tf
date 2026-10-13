output "service_url" {
  description = "The URL of the deployed Cloud Run service"
  value       = google_cloud_run_v2_service.app.uri
}

output "artifact_registry_url" {
  description = "URL of the Artifact Registry repository"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.repo.repository_id}"
}