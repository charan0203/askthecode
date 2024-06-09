# modules/spoke/outputs.tf

output "spoke_project_id" {
  value = module.spoke_project.project_id
}

output "spoke_network_name" {
  value = module.spoke_vpc.name
}
