prefix = "myapp1"
org_id                = "my-org-id"
billing_account_id    = "01FCA4-71D093-F908FB"
owners_host           = ["user:charan.sai@mcs-paas-dev.gcp.t-systems.net"]
spoke1_network_name   = "spoke1-vpc"
#spoke2_network_name   = "spoke2-vpc"
region                = "europe-west3"
folder_display_name   = "Nw-test1"

ip_ranges = {
  gce = "10.0.16.0/24"
  gke = "10.0.32.0/24"
}

ip_secondary_ranges = {
  "gke-pods"     = "10.128.0.0/18"
  "gke-services" = "172.16.0.0/24"
}

owners_gce = [
  "user:charan.sai@mcs-paas-dev.gcp.t-systems.net"
]

owners_gke = [
  "user:charan.sai@mcs-paas-dev.gcp.t-systems.net"
]

project_services = [
  "container.googleapis.com",
  "stackdriver.googleapis.com",
  "dns.googleapis.com" // If you also want to enable the DNS API by default
]



root_node = "folders/974534450826" // Replace with your organization or folder ID
cluster_create = true
