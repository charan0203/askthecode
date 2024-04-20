output "networking_folder_id" {
  value = google_folder.network_folder.id
  description = "The ID of the folder created for the Networking folder"
}

# outputs in spoke1-shared-vpc module


# output "subnet_self_links" {
#   value = { for subnet in google_compute_subnetwork.subnets : subnet.name => subnet.self_link }
# }
output "project_id" {
  value = module.spoke1_project.project_id
}

output "project_number" {
  value = module.service_project1_for_spoke1
}
