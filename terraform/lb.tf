# 1. Глобальна IP-адреса для Load Balancer
resource "google_compute_global_address" "lb_ip" {
  name = "cloud-lab1-lb-ip"
}

# 2. Serverless NEG — вказує на Cloud Run
resource "google_compute_region_network_endpoint_group" "cloud_run_neg" {
  name                  = "cloud-lab1-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_run {
    service = google_cloud_run_v2_service.app.name
  }
}

# 3. Health check 
resource "google_compute_health_check" "app_health" {
  name               = "cloud-lab1-health-check"
  check_interval_sec = 10
  timeout_sec        = 5

  http_health_check {
    port         = 80
    request_path = "/health"
  }
}

# 4. Backend Service
resource "google_compute_backend_service" "backend" {
  name                  = "cloud-lab1-backend"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL_MANAGED"


  backend {
    group = google_compute_region_network_endpoint_group.cloud_run_neg.id
  }
}

# 5. URL Map
resource "google_compute_url_map" "url_map" {
  name            = "cloud-lab1-url-map"
  default_service = google_compute_backend_service.backend.id
}

# 6. Target HTTP Proxy
resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "cloud-lab1-http-proxy"
  url_map = google_compute_url_map.url_map.id
}

# 7. Global Forwarding Rule (frontend)
resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  name       = "cloud-lab1-forwarding-rule"
  target     = google_compute_target_http_proxy.http_proxy.id
  port_range = "80"
  ip_address = google_compute_global_address.lb_ip.address
}