variable "spoke_number" {
  description = "The number of the spoke."
  type        = string
}

# variable "parent_folder_id" {
#   description = "The ID of the parent folder."
#   type        = string
# }


variable "spoke_name" {
  description = "The name of the spoke."
  type        = string
}

variable "prefix" {
  description = "The prefix for naming resources."
  type        = string
}

variable "billing_account_id" {
  description = "The billing account ID."
  type        = string
}

variable "region" {
  description = "The region where resources are deployed."
  type        = string
}

variable "ip_secondary_ranges" {
  description = "Secondary IP CIDR ranges."
  type        = map(string)
  default = {
    gke-pods     = "10.128.0.0/18"
    gke-services = "172.16.0.0/24"
  }
}



variable "owners_gce" {
  description = "List of GCE owners."
  type        = list(string)
}

variable "owners_host" {
  description = "List of host owners."
  type        = list(string)
}

variable "owners_gke" {
  description = "List of GKE owners."
  type        = list(string)
}

variable "cluster_create" {
  description = "Flag to determine if the GKE cluster should be created."
  type        = bool
}

variable "project_services" {
  description = "Service APIs enabled by default in new projects."
  type        = list(string)
  default = [
    "container.googleapis.com",
    "stackdriver.googleapis.com",
  ]
}

variable "deletion_protection" {
  description = "Prevent Terraform from destroying data storage resources (storage buckets, GKE clusters, CloudSQL instances) in this blueprint. When this field is set in Terraform state, a terraform destroy or terraform apply that would delete data storage resources will fail."
  type        = bool
  default     = false
  nullable    = false
}

variable "ip_ranges" {
  description = "Subnet IP CIDR ranges."
  type        = map(string)
  default = {
    hub = "10.0.0.0/24"
    gce = "10.0.16.0/24"
    gke = "10.0.32.0/24"
  }
}


variable "private_service_ranges" {
  description = "Private service IP CIDR ranges."
  type        = map(string)
  default = {
    cluster-1 = "192.168.0.0/28"
  }
}

variable "bgp_peer_addresses" {
  type = map(string)
  description = "A map of BGP peer addresses for each VPN connection"
}

variable "bgp_session_ranges" {
  type = map(string)
  description = "A map of BGP session ranges for each VPN connection"
}

# variable "bgp_peer_addresses" {
#   type = map(string)
#   default = {
#     "hub_remote_0" = "169.254.1.1"
#     "hub_remote_1" = "169.254.2.1"
#     "spoke_2_remote_0" = "169.254.1.2"
#     "spoke_2_remote_1" = "169.254.2.2"
#   }
# }

# variable "bgp_session_ranges" {
#   type = map(string)
#   default = {
#     "hub_remote_0" = "169.254.1.2/30"
#     "hub_remote_1" = "169.254.2.2/30"
#     "spoke_2_remote_0" = "169.254.1.1/30"
#     "spoke_2_remote_1" = "169.254.2.1/30"
#   }
# }
