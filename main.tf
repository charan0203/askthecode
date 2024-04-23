
# Create a new folder inside the 'nbss-main' folder


# Hub Project with Standard VPC
module "hub_project" {
  source            = "../../../modules/project"
  prefix            = var.prefix
  name              = "hub-project"
  parent            = data.google_folder.my_folder_info.folder
  billing_account   = var.billing_account_id
  services          = concat(var.project_services, ["dns.googleapis.com"])

  
}


module "hub_vpc" {
  source      = "../../../modules/net-vpc"
  project_id  = module.hub_project.project_id
  name        = "hub-vpc"
  subnets     = [
    {
      name                = "hub-subnet"
      ip_cidr_range       = "10.0.0.0/24"
      region              = "europe-west3"
      // Add any additional required properties here based on module's variables.tf
    },
  ]
  // Add any additional required variables here based on module's variables.tf
}


# Spoke Projects
module "spoke1_project" {
  source              = "../../../modules/project"
  prefix = var.prefix
  name                = "spoke1-project"
  parent = data.google_folder.my_folder_info.folder
  billing_account     = var.billing_account_id
  services        = concat(var.project_services, ["dns.googleapis.com","container.googleapis.com"])
  
  shared_vpc_host_config = {
    enabled = true
   
  }
  iam = {
    "roles/owner" = var.owners_host
  }
 
#   iam = {
#   "roles/owner"                    = var.owners_host
#   "roles/container.hostServiceAgentUser" = var.owners_host
#   "roles/container.hostServiceAgentUser" = [
#     "serviceAccount:service-${module.spoke1_project.number}@container-engine-robot.iam.gserviceaccount.com",
#     "serviceAccount:${module.spoke1_project.number}@cloudservices.gserviceaccount.com",
#     "serviceAccount:service-${module.service_project1_for_spoke1.number}@container-engine-robot.iam.gserviceaccount.com",
#     "serviceAccount:${module.spoke1_project.number}-compute@developer.gserviceaccount.com"
#   ]
#   "roles/container.serviceAgent"   = [
#     "serviceAccount:service-${module.spoke1_project.number}@container-engine-robot.iam.gserviceaccount.com"
#   ]
#   "roles/compute.networkUser"     = [
#     "serviceAccount:service-${module.spoke1_project.number}@container-engine-robot.iam.gserviceaccount.com",
#     "serviceAccount:service-${module.spoke1_project.number}@cloudservices.gserviceaccount.com"
#   ]
#   "roles/compute.instanceAdmin"   = [
#     "serviceAccount:service-${module.spoke1_project.number}@container-engine-robot.iam.gserviceaccount.com"
#   ]
# }

  
}

# module "spoke2_project" {
#   source              = "terraform-google-modules/project-factory/google"
#   name                = "spoke2-project"
#   random_project_id   = true
#   folder_id           = module.new_folder.id
#   billing_account     = var.billing_account
#   services        = concat(var.project_services, ["dns.googleapis.com"])
#   shared_vpc_host_config = {
#     enabled = true
#   }
#   iam = {
#     "roles/owner" = var.owners_host
#   }
# }

# Service Projects for Spoke 1
module "service_project1_for_spoke1" {
  source              = "../../../modules/project"
  prefix = var.prefix
  name                = "service-project1-spoke1"
  parent = data.google_folder.my_folder_info.folder
  billing_account     = var.billing_account_id
  services        = concat(var.project_services, ["dns.googleapis.com", "container.googleapis.com"])
  // Shared VPC host project ID
  shared_vpc_service_config = {
    host_project = module.spoke1_project.project_id
    service_identity_iam = {
      "roles/container.hostServiceAgentUser" = ["container-engine"]
      "roles/compute.networkUser"            = ["container-engine"]
    }
  
  }
}
resource "google_project_iam_member" "service_project1_host_service_agent_user" {
  project = module.service_project1_for_spoke1.project_id
  role    = "roles/container.hostServiceAgentUser"
  member  = "serviceAccount:service-${module.service_project1_for_spoke1.number}@container-engine-robot.iam.gserviceaccount.com"
}
module "service_project2_for_spoke1" {
  source              = "../../../modules/project"
  prefix = var.prefix
  name                = "service-project2-spoke1"
 parent = data.google_folder.my_folder_info.folder 
  billing_account     = var.billing_account_id
  services        = concat(var.project_services, ["dns.googleapis.com"])
  auto_create_network = false
  shared_vpc_service_config = {
    host_project = module.spoke1_project.project_id
    service_identity_iam = {
      "roles/container.hostServiceAgentUser" = ["container-engine"]
      "roles/compute.networkUser"            = ["container-engine"]
    }
  }
}

# Service Projects for Spoke 2
# module "service_project1_for_spoke2" {
#   source              = "terraform-google-modules/project-factory/google"
#   name                = "service-project1-spoke2"
#   random_project_id   = true
#   org_id              = var.org_id
#   folder_id           = module.new_folder.id
#   billing_account     = var.billing_account
#   auto_create_network = false
#   activate_apis       = ["compute.googleapis.com"]
#   shared_vpc_service_config = {
#     host_project = module.spoke2_project.project_id
#     service_identity_iam = {
#       "roles/container.hostServiceAgentUser" = ["container-engine"]
#       "roles/compute.networkUser"            = ["container-engine"]
#     }
#   }
# }

# module "service_project2_for_spoke2" {
#   source              = "terraform-google-modules/project-factory/google"
#   name                = "service-project2-spoke2"
#   random_project_id   = true
#   org_id              = var.org_id
#   folder_id           = module.new_folder.id
#   billing_account     = var.billing_account
#   auto_create_network = false
#   activate_apis       = ["compute.googleapis.com"]
#   shared_vpc_service_config = {
#     host_project = module.spoke2_project.project_id
#     service_identity_iam = {
#       "roles/container.hostServiceAgentUser" = ["container-engine"]
#       "roles/compute.networkUser"            = ["container-engine"]
#     }
#   }
# }


# Spoke1 vpc
module "spoke1-shared-vpc" {
  source     = "../../../modules/net-vpc"
  project_id = module.spoke1_project.project_id
  name       = "spoke1-shared-vpc"
  subnets = [
    {
      ip_cidr_range = var.ip_ranges.gce
      name          = "gce"
      region        = var.region
      iam = {
        "roles/compute.networkUser" = concat(var.owners_gce, [
          "serviceAccount:${module.service_project1_for_spoke1.service_accounts.cloud_services}",
          "serviceAccount:${module.service_project1_for_spoke1.service_accounts.robots.container-engine}"
        ])
      }
    },
    {
      ip_cidr_range = var.ip_ranges.gke
      name          = "gke"
      region        = var.region
      secondary_ip_ranges = {
        pods     = var.ip_secondary_ranges.gke-pods
        services = var.ip_secondary_ranges.gke-services
      }
      iam = {
        "roles/compute.networkUser" = concat(var.owners_gke, [
          "serviceAccount:${module.spoke1_project.number}@cloudservices.gserviceaccount.com",
          "serviceAccount:${module.service_project1_for_spoke1.service_accounts.cloud_services}",
          "serviceAccount:${module.service_project1_for_spoke1.service_accounts.robots.container-engine}",
          "serviceAccount:service-${module.service_project1_for_spoke1.number}@container-engine-robot.iam.gserviceaccount.com",
          "serviceAccount:${module.service_project1_for_spoke1.number}@cloudservices.gserviceaccount.com",
          "serviceAccount:service-${module.service_project1_for_spoke1.number}@compute-system.iam.gserviceaccount.com"
        ]),
        "roles/compute.networkViewer" = var.owners_host
        "roles/compute.securityAdmin" = [
          "serviceAccount:${module.service_project1_for_spoke1.service_accounts.robots.container-engine}",
        ],
        "roles/compute.networkUser" = [
          "serviceAccount:service-${module.service_project1_for_spoke1.number}@container-engine-robot.iam.gserviceaccount.com",
          "serviceAccount:${module.service_project1_for_spoke1.number}@cloudservices.gserviceaccount.com"]
      }
    }
  ]
}

# #spoke2 vpc
# module "spoke2-shared-vpc" {
#   source     = "../../../modules/net-vpc"
#   project_id = module.spoke2_project.project_id
#   name       = "shared-vpc"
#   subnets = [
#     {
#       ip_cidr_range = var.ip_ranges.gce
#       name          = "gce"
#       region        = var.region
#       iam = {
#         "roles/compute.networkUser" = concat(var.owners_gce, [
#           "serviceAccount:${module.project-svc-gce.service_accounts.cloud_services}",
#         ])
#       }
#     },
#     {
#       ip_cidr_range = var.ip_ranges.gke
#       name          = "gke"
#       region        = var.region
#       secondary_ip_ranges = {
#         pods     = var.ip_secondary_ranges.gke-pods
#         services = var.ip_secondary_ranges.gke-services
#       }
#       iam = {
#         "roles/compute.networkUser" = concat(var.owners_gke, [
#           "serviceAccount:${module.service_project1_for_spoke2.service_accounts.cloud_services}",
#           "serviceAccount:${module.service_project1_for_spoke2.service_accounts.robots.container-engine}",
#         ])
#         "roles/compute.securityAdmin" = [
#           "serviceAccount:${module.service_project1_for_spoke2.service_accounts.robots.container-engine}",
#         ]
#       }
#     }
#   ]
# }


# Firewall Rules for the Hub Network using net-vpc-firewall module
module "hub_firewall_rules" {
  source     = "../../../modules/net-vpc-firewall"
  project_id = module.hub_project.project_id
  network    = module.hub_vpc.name

  ingress_rules = {
    "allow-ssh-rdp-icmp-to-hub" = {
      description        = "Allow SSH, RDP, and ICMP to hub"
      priority           = 1000
      source_ranges      = [var.ip_ranges.gce, var.ip_ranges.gke] # Replace with the actual IP ranges of the spokes
      rules = [
        {
          protocol = "tcp"
          ports    = ["22", "3389"]
        },
        {
          protocol = "icmp"
        }
      ]
    },
    "deny-all-ingress-to-hub" = {
      description        = "Deny all ingress to hub"
      priority           = 1000
      source_ranges      = ["0.0.0.0/0"]
      rules = [
        {
          protocol = "tcp"
        },
        {
          protocol = "udp"
        },
        {
          protocol = "icmp"
        }
      ]
    }
  }
  // Add any egress rules if you have them, structured similarly
}


module "spoke1_firewall_rules" {
  source     = "../../../modules/net-vpc-firewall"
  project_id = module.spoke1_project.project_id
  network    = module.spoke1-shared-vpc.name

  egress_rules = {
    "allow-traffic-to-hub" = {
      description        = "Allow traffic to hub network"
      priority           = 1000
      destination_ranges = ["10.0.0.0/24"] # Replace with the IP range of the hub network
      rules = [
        {
          protocol = "tcp"
          ports    = ["22"]
        },
        {
          protocol = "udp"
          ports    = ["53"]
        },
        {
          protocol = "icmp"
        }
      ]
    },
    "block-direct-traffic-between-spokes-egress" = {
      description        = "Block direct egress traffic between spokes"
      priority           = 1000
      destination_ranges = ["10.20.0.0/24"] # Correct the IP range if necessary
      deny               = true
      rules = [
        {
          protocol = "tcp"
        },
        {
          protocol = "udp"
        },
        {
          protocol = "icmp"
        }
      ]
    }
  }

  ingress_rules = {
    "block-direct-traffic-between-spokes-ingress" = {
      description   = "Block direct ingress traffic between spokes"
      priority      = 1000
      source_ranges = ["10.20.0.0/24"] # Correct the IP range if necessary
      deny          = true
      rules = [
        {
          protocol = "tcp"
        },
        {
          protocol = "udp"
        },
        {
          protocol = "icmp"
        }
      ]
    },
    "deny-all-other-ingress-spoke" = {
      description   = "Deny all other ingress to the spoke"
      priority      = 1000
      source_ranges = ["0.0.0.0/0"]
      deny          = true
      rules = [
        {
          protocol = "all"
        }
      ]
    }
  }
}


# module "spoke2_firewall_rules" {
#   source      = "terraform-google-modules/network/google//modules/firewall-rules"
#   project_id  = module.spoke1_project.project_id
#   network     = "<SPOKE_NETWORK_NAME>"

#   rules = [
#     {
#       name               = "allow-traffic-to-hub"
#       direction          = "EGRESS"
#       action             = "allow"
#       destination_ranges = ["<HUB_NETWORK_IP_RANGE>"]  # Replace with the IP range of the hub network
#       ranges             = ["tcp:<PORT>", "udp:<PORT>", "icmp"]  # Replace <PORT> with actual ports
#     },
#     {
#       name               = "block-direct-traffic-between-spokes"
#       direction          = "INGRESS"
#       action             = "deny"
#       sources            = ["<OTHER_SPOKE_NETWORK_IP_RANGES>"]
#       ranges             = ["tcp", "udp", "icmp"]
#     },
#     {
#       name               = "block-direct-traffic-between-spokes"
#       direction          = "EGRESS"
#       action             = "deny"
#       destination_ranges = ["<OTHER_SPOKE_NETWORK_IP_RANGES>"]
#       ranges             = ["tcp", "udp", "icmp"]
#     },
#     {
#       name        = "deny-all-other-ingress-spoke"
#       direction   = "INGRESS"
#       action      = "deny"
#       sources     = ["0.0.0.0/0"]
#       priority    = 1000
#     },
#   ]
# }

module "hub_to_spoke1_peering" {
  source  = "../../../modules/net-vpc-peering"

  local_network   = "projects/${module.hub_project.project_id}/global/networks/${module.hub_vpc.name}"
  peer_network    = "projects/${module.spoke1_project.project_id}/global/networks/${module.spoke1-shared-vpc.name}"  # Replace with the resource link of the Spoke 1 network
  // Include other optional variables if needed
}




# module "hub_to_spoke2_peering" {
#   source  = "terraform-google-modules/network/google//modules/vpc-peering"
#   version = "~> 3.0"

#   project_id       = module.hub_project.project_id
#   network          = module.hub_vpc.network_name
#   peer_project_id  = module.spoke2_project.project_id
#   peer_network     = "<SPOKE2_NETWORK_NAME>"  # Replace with the Spoke 2 network name
# }

module "spoke1_private_dns" {
  source      = "../../../modules/dns"
  project_id  = module.service_project1_for_spoke1.project_id
  name        = "spoke1-private-zone"
  description = "Private DNS zone for Spoke 1"
  zone_config = {
    domain = "gke.mcs-paas-dev.gcp.t-systems.net."
    peering = {
      client_networks = [module.spoke1-shared-vpc.self_link]
      peer_network    = module.hub_vpc.self_link
    }
  }
}




# module "spoke1_cloud_nat" {
#   source      = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/net-cloudnat"
#   project_id  = module.spoke1_project.project_id
#   region      = var.region
#   network     = module.spoke1_shared_vpc.network
#   router      = "spoke1-nw"  // Specify the existing router name
#   name        = "spoke1-cloud-nat"

#   nat_ips = {
#     num_addresses_per_subnet = {
#       "europe-west3" = 1  // Adjust according to the subnets and their locations
#     }
#   }
# }

module "spoke1_cloud_nat" {
  source           = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/net-cloudnat"
  project_id       = module.spoke1_project.project_id
  region           = var.region
  name             = "spoke1-cloud-nat"
  router_network   = module.spoke1-shared-vpc.name
  router_create    = true  // Indicates that the module should create the router


  // Define subnetworks to enable NAT on them.
  // The 'all' variable set to true means all subnetworks in the region are NAT-ed.
  config_source_subnetworks = {
    all = true
  }

  // Optionally set a filter for the NAT logging.
  // If you want to enable logging, set 'logging_filter' to one of the allowed values.
  // Leave it as null if you do not want to enable logging.
  logging_filter = null

  
}

# module "spoke1_cloud_nat" {
#   source      = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/net-cloudnat"
#   project_id  = module.spoke1_project.project_id
#   region      = var.region
#   name        = "spoke1-cloud-nat"
  
#   // The 'router_network' variable should be the name of the VPC, not the network self link.
#   router_network = module.spoke1-shared-vpc.name

#   // If you are creating a new router for this NAT, set 'router_create' to true.
#   // If you're using an existing router, set 'router_create' to false and provide 'router_name'.
#   router_create = false
#   router_name   = "spoke1-nw"  // The name of the existing router.

#   // Define external IP addresses if you have any. Otherwise, this will default to an empty list.
#   addresses = []

#   // 'config_source_subnetworks' defines the subnetworks for NAT.
#   // 'all' being true means all subnetworks in the region are NAT-ed.
#   config_source_subnetworks = {
#     all = true
#   }

#   // If you want to enable logging, set 'logging_filter' to one of the allowed values.
#   // Leave it as null if you do not want to enable logging.
#   logging_filter = null
# }

##############################GKE Configuration####################################
module "cluster-1" {
  source     = "../../../modules/gke-cluster-standard"
  count      = var.cluster_create ? 1 : 0
  name       = "cluster-1"
  project_id = module.service_project1_for_spoke1.project_id
  location   = "${var.region}-b"
  vpc_config = {
    network    = module.spoke1-shared-vpc.self_link
    subnetwork = module.spoke1-shared-vpc.subnet_self_links["${var.region}/gke"]
    master_ipv4_cidr_block = var.private_service_ranges.cluster-1
    secondary_range_names = {
      #pods     = var.secondary_range_names["pods"]
      #services = var.secondary_range_names["services"]
    }

    master_authorized_ranges = {
      "CorpNet" = "192.168.100.0/24"  # Adjust this CIDR block as necessary for your network
    }
  }
  max_pods_per_node = 32
  private_cluster_config = {
    enable_private_endpoint = true
    master_global_access    = true
  }
  labels = {
    environment = "test"
  }
  deletion_protection = var.deletion_protection
}



module "cluster-1-nodepool-1" {
  source       = "../../../modules/gke-nodepool"
  count        = var.cluster_create ? 1 : 0
  name         = "nodepool-1"
  project_id   = module.service_project1_for_spoke1.project_id
  location     = module.cluster-1.0.location
  cluster_name = module.cluster-1.0.name
  cluster_id   = module.cluster-1.0.id
  service_account = {
    create = true
  }
}

###### Hub-VM #####
module "hub_vm" {
  source     = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/compute-vm"
  project_id = module.hub_project.project_id
  zone       = "europe-west3-c"

  name         = "hub-vm"
  instance_type = "e2-medium"
  
  boot_disk = {
    initialize_params = {
      image = "projects/debian-cloud/global/images/family/debian-10"
    }
  }

  network_interfaces = [{
    network    = module.hub_vpc.self_link
    subnetwork = module.hub_vpc.subnets["europe-west3/hub-subnet"].self_link  # Adjust the key to match the subnet name
    access_config = {}
  }]

  service_account = {
    email  = "default"
    scopes = ["cloud-platform"]
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  tags = ["hub-vm", "test-environment"]
}




