

# variable "project_id" {
#   description = "The Google Cloud project ID"
#   type        = string
# }



# variable "parent_folder_id" {
#   description = "The parent folder ID in Google Cloud"
#   type        = string
# }

variable "org_id" {
  description = "The organization ID in Google Cloud"
  type        = string
}

variable "billing_account_id" {
  description = "The billing account ID in Google Cloud"
  type        = string
}

variable "owners_host" {
  description = "List of owners for the project"
  type        = list(string)
}


variable "spoke1_network_name" {
  description = "The network name for Spoke 1"
  type        = string
}

# variable "spoke2_network_name" {
#   description = "The network name for Spoke 2"
#   type        = string
# }




variable "ip_ranges" {
  description = "Subnet IP CIDR ranges."
  type        = map(string)
  default = {
    gce = "10.0.16.0/24"
    gke = "10.0.32.0/24"
  }
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
  description = "GCE project owners, in IAM format."
  type        = list(string)
  default     = []
}

variable "owners_gke" {
  description = "GKE project owners, in IAM format."
  type        = list(string)
  default     = []
}


variable "region" {
  description = "Region used."
  type        = string
  default     = "europe-west3"
}

variable "project_services" {
  description = "Service APIs enabled by default in new projects."
  type        = list(string)
  default = [
    "container.googleapis.com",
    "stackdriver.googleapis.com",
  ]
}


variable "root_node" {
  description = "Hierarchy node where projects will be created, 'organizations/org_id' or 'folders/folder_id'."
  type        = string
}

variable "folder_display_name" {
  type        = string
  description = "The display name of the folder."
}

variable "cluster_create" {
  description = "Create GKE cluster and nodepool."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Prevent Terraform from destroying data storage resources (storage buckets, GKE clusters, CloudSQL instances) in this blueprint. When this field is set in Terraform state, a terraform destroy or terraform apply that would delete data storage resources will fail."
  type        = bool
  default     = false
  nullable    = false
}

variable "prefix" {
  description = "Prefix used for resource names."
  type        = string
}

