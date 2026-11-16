resource "google_monitoring_notification_channel" "email_channel" {
  display_name = "Email Alerts"
  type         = "email"
  labels = {
    email_address = "jaremchuk.stanislav1@gmail.com" 
  }
}

resource "google_monitoring_alert_policy" "high_cpu_alert" {
  display_name = "High CPU Utilization Alert"
  combiner     = "OR"
  
  conditions {
    display_name = "CPU > 40%"
    condition_threshold {
      filter          = "metric.type=\"run.googleapis.com/container/cpu/utilizations\" resource.type=\"cloud_run_revision\" resource.label.\"service_name\"=\"cloud-lab1-app\""
      duration        = "120s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.4
      
      trigger {
        count = 1
      }
      
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_PERCENTILE_95"
      }
    }
  }
  
  notification_channels = [google_monitoring_notification_channel.email_channel.id]
}