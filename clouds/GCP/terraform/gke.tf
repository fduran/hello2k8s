resource "google_service_account" "default" {
  account_id   = "service-account-id"
  display_name = "Service Account"
}

resource "google_container_cluster" "primary" {
  name               = "hello-gke"
  location           = var.region
  initial_node_count = 1
  
  # node_config {
  #   # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
  #   service_account = google_service_account.default.email
  #   oauth_scopes = [
  #     "https://www.googleapis.com/auth/cloud-platform"
  #   ]
  # }
}