locals {
  vm-instances = [
    module.hub_vm.instance,
    module.vm-spoke-1.instance
  ]
  vm-startup-script = join("\n", [
    "#! /bin/bash",
    "apt-get update && apt-get install -y bash-completion dnsutils kubectl"
  ])
}
###############################################################################
#                        HUB, Host and service projects                       #
###############################################################################

# Hub Project with Standard VPC
module "hub_project" {
  source            = "../../../modules/project"
  prefix            = var.prefix
  name              = "hub-project"
  parent            = data.google_folder.my_folder_info.folder
  billing_account   = var.billing_account_id
  services          = concat(var.project_services, ["dns.googleapis.com"])

iam = {
    "roles/container.clusterViewer" = [
      "serviceAccount:${module.hub_project.number}-compute@developer.gserviceaccount.com"
    ]
    "roles/container.hostServiceAgentUser" = [
      "serviceAccount:service-${module.service_project1_for_spoke1.number}@container-engine-robot.iam.gserviceaccount.com"
    ]
     "roles/container.admin" = [
      "serviceAccount:${module.hub_project.number}-compute@developer.gserviceaccount.com"
    ]
    "roles/compute.osAdminLogin" = var.owners_gce
    "roles/owner"                = var.owners_gce
    "roles/iam.serviceAccountUser"= var.owners_host
  }
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
    "roles/iam.serviceAccountUser"= var.owners_host

  }
}

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
iam = merge(
    {
      "roles/container.developer" = [module.hub_vm.service_account_iam_email]
      "roles/owner"               = var.owners_gke
      "roles/container.clusterViewer" = [
      "serviceAccount:${module.hub_project.number}-compute@developer.gserviceaccount.com"
    ]
    },
    var.cluster_create
    ? {
      "roles/logging.logWriter"       = [module.cluster-1-nodepool-1.0.service_account_iam_email]
      "roles/monitoring.metricWriter" = [module.cluster-1-nodepool-1.0.service_account_iam_email]
    }
    : {}
  )
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



################################################################################
#                                  Networking                                  #
################################################################################

module "hub_vpc" {
  source      = "../../../modules/net-vpc"
  project_id  = module.hub_project.project_id
  name        = "hub-vpc"
  subnets     = [
    {
      name                = "hub-subnet"
      ip_cidr_range       = var.ip_ranges.hub
      region              = "europe-west3"
    
    },
  ]
 
}

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

          #################################### fix the project names #################
          "roles/compute.networkUser" = concat(var.owners_gke, [
          "serviceAccount:${module.service_project1_for_spoke1.service_accounts.cloud_services}",
          "serviceAccount:${module.service_project1_for_spoke1.service_accounts.robots.container-engine}",
        ])
        "roles/compute.securityAdmin" = [
          "serviceAccount:${module.service_project1_for_spoke1.service_accounts.robots.container-engine}",
        ]
      }
    }
  ]
}

# Firewall Rules for the Hub Network using net-vpc-firewall module

module "vpc-hub-firewall" {
  source     = "../../../modules/net-vpc-firewall"
  project_id = module.hub_project.project_id
  network    = module.hub_vpc.name
  default_rules_config = {
    admin_ranges = values(var.ip_ranges)
  }
}
# module "hub_firewall_rules" {
#   source     = "../../../modules/net-vpc-firewall"
#   project_id = module.hub_project.project_id
#   network    = module.hub_vpc.name

#   ingress_rules = {
#     "allow-ssh-rdp-icmp-to-hub" = {
#       description        = "Allow SSH, RDP, and ICMP to hub"
#       priority           = 1000
#       source_ranges      = [var.ip_ranges.gce, var.ip_ranges.gke] # Replace with the actual IP ranges of the spokes
#       rules = [
#         {
#           protocol = "tcp"
#           ports    = ["22", "3389"]
#         },
#         {
#           protocol = "icmp"
#         }
#       ]
#     },
#     # "deny-all-ingress-to-hub" = {
#     #   description        = "Deny all ingress to hub"
#     #   priority           = 1100
#     #   source_ranges      = ["0.0.0.0/0"]
#     #   rules = [
#     #     {
#     #       protocol = "tcp"
#     #     },
#     #     {
#     #       protocol = "udp"
#     #     },
#     #     {
#     #       protocol = "icmp"
#     #     }
#     #   ]
#     # }
#   }
#   // Add any egress rules if you have them, structured similarly
# }


module "spoke1_firewall_rules" {
  source     = "../../../modules/net-vpc-firewall"
  project_id = module.spoke1_project.project_id
  network    = module.spoke1-shared-vpc.name
 default_rules_config = {
    admin_ranges = values(var.ip_ranges)
  }
}
#   egress_rules = {
#     "allow-traffic-to-hub" = {
#       description        = "Allow traffic to hub network"
#       priority           = 900  # Higher priority (lower number)
#       destination_ranges = ["10.0.0.0/24"]  # Replace with the IP range of the hub network
#       rules = [
#         {
#           protocol = "tcp"
#           ports    = ["22"]
#         },
#         {
#           protocol = "udp"
#           ports    = ["53"]
#         },
#         {
#           protocol = "icmp"
#         }
#       ]
#     },
#     # "block-direct-traffic-between-spokes-egress" = {
#     #   description        = "Block direct egress traffic between spokes"
#     #   priority           = 950  # Slightly lower priority than the allow rule
#     #   destination_ranges = ["10.20.0.0/24"]  # Correct the IP range if necessary
#     #   deny               = true
#     #   rules = [
#     #     {
#     #       protocol = "tcp"
#     #     },
#     #     {
#     #       protocol = "udp"
#     #     },
#     #     {
#     #       protocol = "icmp"
#     #     }
#     #   ]
#     # }
#   }

#   ingress_rules = {
#     # "block-direct-traffic-between-spokes-ingress" = {
#     #   description   = "Block direct ingress traffic between spokes"
#     #   priority      = 970  # Lower priority than the specific allows but higher than general deny
#     #   source_ranges = ["10.20.0.0/24"]  # Correct the IP range if necessary
#     #   deny          = true
#     #   rules = [
#     #     {
#     #       protocol = "tcp"
#     #     },
#     #     {
#     #       protocol = "udp"
#     #     },
#     #     {
#     #       protocol = "icmp"
#     #     }
#     #   ]
#     # },
#     # "deny-all-other-ingress-spoke" = {
#     #   description   = "Deny all other ingress to the spoke"
#     #   priority      = 990  # Lowest priority for broad deny rules
#     #   source_ranges = ["0.0.0.0/0"]
#     #   deny          = true
#     #   rules = [
#     #     {
#     #       protocol = "all"
#     #     }
#     #   ]
#     # },
#     "allow-icmp-from-hub" = {
#       description   = "Allow ICMP from Hub VPC"
#       priority      = 960   # Higher priority to ensure it is processed before most denies
#       source_ranges = ["10.0.0.0/24"]  # IP range of the hub network
#       rules = [
#         {
#           protocol = "icmp"
#         }
#       ]
#     },
#     "allow-gke-api-from-hub" = {
#       description   = "Allow traffic to GKE API from Hub VPC"
#       priority      = 1000   # Set a priority that makes sense for your rules
#       source_ranges = ["10.0.0.0/24"]  # IP range of your hub network
#       rules = [
#         {
#           protocol = "tcp"
#           ports    = ["443"]
#         }
#       ]
#     }

#   }
# }


module "hub_to_spoke1_peering" {
  source  = "../../../modules/net-vpc-peering"
  local_network   = "projects/${module.hub_project.project_id}/global/networks/${module.hub_vpc.name}"
  peer_network    = "projects/${module.spoke1_project.project_id}/global/networks/${module.spoke1-shared-vpc.name}"  # Replace with the resource link of the Spoke 1 network

  routes_config = {
    local = { export = true, import = false }
    peer  = { export = false, import = true }
  }
}

module "spoke1_cloud_nat" {
  source           = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/net-cloudnat"
  project_id       = module.hub_project.project_id
  region           = var.region
  name             = "hub-cloud-nat"
  router_network   = module.hub_vpc.name
  router_create    = true  // Indicates that the module should create the router
}

################################################################################
#                                     DNS                                      #
################################################################################

module "spoke1_private_dns" {
  source      = "../../../modules/dns"
  project_id  = module.spoke1_project.project_id
  name        = "spoke1-private-zone"
  description = "Private DNS zone for Spoke 1"
  zone_config = {
    domain = "gke1.mcs-paas-dev.gcp.t-systems.net."
    private = {
      client_networks = [module.spoke1-shared-vpc.self_link]
    }
  }
    recordsets = {
    "A localhost" = { records = ["127.0.0.1"] }
    "A bastion"   = { records = [module.hub_vm.internal_ip] }
  }
}

################################################################################
#                                     VM                                      #
################################################################################
# module "hub_vm" {
#   source     = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/compute-vm"
#   project_id = module.hub_project.project_id
#   zone       = "europe-west3-b"
#   name         = "hub-vm"
#   network_interfaces = [{
#     network    = module.hub_vpc.self_link
#     subnetwork = module.hub_vpc.subnets["europe-west3/hub-subnet"].self_link  
#     nat        = false
#     addresses  = null
#   }]
#   service_account = {
#      auto_create = true
#   }
#   metadata = {
#    startup-script = join("\n", [
#       "#! /bin/bash",
#       "apt-get update",
#       "apt-get install -y bash-completion kubectl dnsutils tinyproxy",
#       "grep -qxF 'Allow localhost' /etc/tinyproxy/tinyproxy.conf || echo 'Allow localhost' >> /etc/tinyproxy/tinyproxy.conf",
#       "service tinyproxy restart"
#     ])
#   }
#    tags = ["ssh", "ssh1"]
# }

module "hub_vm" {
  source     = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/compute-vm"
  project_id = module.hub_project.project_id
  zone       = "${var.region}-b"
  name       = "${var.prefix}-hub"
  network_interfaces = [{
    network    = module.hub_vpc.self_link
    subnetwork = module.hub_vpc.subnets["europe-west3/hub-subnet"].self_link 
    #subnetwork = module.hub_vpc.subnet_self_links["${var.region}/${var.prefix}-hub-1"]
    nat        = false
    addresses  = null
  }]
  metadata = { startup-script = local.vm-startup-script }
  service_account = {
      auto_create = true
   }
  tags = ["ssh"]
}



module "vm-spoke-1" {
  source     = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/compute-vm"
  project_id = module.spoke1_project.project_id
  zone       = "${var.region}-b"
  name       = "${var.prefix}-spoke-1"
  network_interfaces = [{
    network    = module.spoke1-shared-vpc.self_link
     subnetwork = module.spoke1-shared-vpc.subnet_self_links["${var.region}/gke"]
   # subnetwork = module.spoke1-shared-vpc.subnet_self_links["${var.region}/${var.prefix}-spoke-1-1"]
    nat        = false
    addresses  = null
  }]
  metadata = { startup-script = local.vm-startup-script }
 service_account = {
     auto_create = true
  }
  tags = ["ssh"]
}

module "service-account-gce" {
  source     = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/iam-service-account"
  project_id = module.spoke1_project.project_id
  name       = "${var.prefix}-gce-test"
  iam_project_roles = {
    (var.project_id) = [
      "roles/container.developer",
      "roles/logging.logWriter",
      "roles/monitoring.metricWriter",
      "roles/iam.serviceAccountUser"
    ]
  }
}

resource "google_project_iam_member" "service_account_user" {
  project = module.spoke1_project.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${var.prefix}-gce-test@${var.prefix}-spoke1-project.iam.gserviceaccount.com"
}



################################################################################
#                                     GKE                                      #
################################################################################

module "cluster-1" {
  source     = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/gke-cluster-standard"
  count      = var.cluster_create ? 1 : 0
  name       = "cluster-1"
  #project_id = module.service_project1_for_spoke1.project_id
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
      "CorpNet" = "10.0.0.0/24"  # Adjust this CIDR block as necessary for your network
    }
  }
  max_pods_per_node = 32
  private_cluster_config = {
    enable_private_endpoint = true
    master_global_access    = true
       peering_config = {
        project_id = module.spoke1_project.project_id 
      export_routes = true
      import_routes = false
   }
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





################################################################################
#                               GKE peering VPN                                #
################################################################################

module "vpn-hub" {
  source     = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/net-vpn-ha"
  project_id = module.hub_project.project_id
  region     = var.region
  network    = module.hub_vpc.name
  name       = "${var.prefix}-hub"
  peer_gateways = {
    default = { gcp = module.vpn-spoke-2.self_link }
  }
  router_config = {
    asn = 64516
    custom_advertise = {
      all_subnets          = true
      all_vpc_subnets      = true
      all_peer_vpc_subnets = true
      ip_ranges = {
        "10.0.0.0/8" = "default"
      }
    }
  }
  tunnels = {
    remote-0 = {
      bgp_peer = {
        address = "169.254.1.1"
        asn     = 64515
      }
      bgp_session_range     = "169.254.1.2/30"
      vpn_gateway_interface = 0
    }
    remote-1 = {
      bgp_peer = {
        address = "169.254.2.1"
        asn     = 64515
      }
      bgp_session_range     = "169.254.2.2/30"
      vpn_gateway_interface = 1
    }
  }
}


module "vpn-spoke-2" {
  source     = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/net-vpn-ha"
  project_id = module.spoke1_project.project_id
  region     = var.region
  network    = module.spoke1-shared-vpc.name
  name       = "${var.prefix}-spoke-2"
  router_config = {
    asn = 64515
    custom_advertise = {
      all_subnets          = true
      all_vpc_subnets      = true
      all_peer_vpc_subnets = true
      ip_ranges = {
        "10.0.0.0/8"                                      = "default"
        "${var.private_service_ranges.cluster-1}" = "access to control plane"
      }
    }
  }
  peer_gateways = {
    default = { gcp = module.vpn-hub.self_link }
  }
  tunnels = {
    remote-0 = {
      bgp_peer = {
        address = "169.254.1.2"
        asn     = 64516
      }
      bgp_session_range     = "169.254.1.1/30"
      shared_secret         = module.vpn-hub.random_secret
      vpn_gateway_interface = 0
    }
    remote-1 = {
      bgp_peer = {
        address = "169.254.2.2"
        asn     = 64516
      }
      bgp_session_range     = "169.254.2.1/30"
      shared_secret         = module.vpn-hub.random_secret
      vpn_gateway_interface = 1
    }
  }
}
