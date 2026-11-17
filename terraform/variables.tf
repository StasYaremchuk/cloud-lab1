variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "project-27c06a2f-1267-4018-aa3" 
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-central2" # Варшава
}

variable "db_password" {
  description = "Password for the database user"
  type        = string
  sensitive   = true 
}

variable "is_night" {
  description = "Toggle for day/night scaling"
  type        = bool
  default     = false
}