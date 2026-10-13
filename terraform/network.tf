# 1. Кастомний VPC (не Default VPC — вимога методички)
resource "google_compute_network" "vpc" {
  name                    = "cloud-lab1-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# 2. Приватна підмережа
resource "google_compute_subnetwork" "private" {
  name          = "cloud-lab1-private"
  ip_cidr_range = "10.10.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id

  private_ip_google_access = true
}

# 3. Діапазон IP для Private Services (Cloud SQL)
resource "google_compute_global_address" "private_ip_range" {
  name          = "cloud-lab1-private-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 20
  network       = google_compute_network.vpc.id
}

# 4. Приватне з'єднання з Google (для Cloud SQL private IP)
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]

  deletion_policy = "ABANDON"
}

# 5. Serverless VPC Access Connector (щоб Cloud Run бачив VPC)
resource "google_vpc_access_connector" "connector" {
  name          = "cloud-lab1-connector"
  region        = var.region
  ip_cidr_range = "10.10.0.0/28"
  network       = google_compute_network.vpc.name

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

# 6. Firewall rule: дозволяємо PostgreSQL тільки з connector'а
resource "google_compute_firewall" "allow_cloudsql_from_connector" {
  name    = "cloud-lab1-allow-postgres-from-connector"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  source_ranges = ["10.10.0.0/28"]  # тільки з VPC connector
  target_tags   = ["cloud-sql"]

  direction = "INGRESS"
  priority  = 1000
}