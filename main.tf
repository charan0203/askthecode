terraform {
  backend "gcs" {}
} 

#The above terraform backend block is to get rid of the error when we run terragrunt init, we just have to include it, it doesn't effect the remote state

data "terraform_remote_state" "hub" {
  backend = "gcs"
  config = {
    bucket = "tf_states_bucket"
    prefix = "hub"
  }
}
locals {
  vm-instances = [
    module.spoke_vm.instance
  ]
  vm_startup_script = join("\n", [
    "#! /bin/bash",
    "apt-get update && apt-get install -y bash-completion dnsutils kubectl"
  ])
}
module "spoke_project" {
  source              = "../project"
  prefix              = var.prefix
  name                = "spoke${var.spoke_number}"
  parent              = data.terraform_remote_state.hub.outputs.folder_id
  billing_account     = var.billing_account_id
  services            = concat(var.project_services, ["dns.googleapis.com", "container.googleapis.com"])
  
  shared_vpc_host_config = {
    enabled = true
  }

  iam = {
    "roles/owner" = var.owners_host
    "roles/iam.serviceAccountUser" = var.owners_host
  }
}

module "service_project" {
  source              = "../project"
  prefix              = var.prefix
  name                = "svc-spoke${var.spoke_number}"
  parent              = data.terraform_remote_state.hub.outputs.folder_id
  billing_account     = var.billing_account_id
  services            = concat(var.project_services, ["dns.googleapis.com", "container.googleapis.com"])
  
  shared_vpc_service_config = {
    host_project = module.spoke_project.project_id
    service_identity_iam = {
      "roles/container.hostServiceAgentUser" = ["container-engine"]
      "roles/compute.networkUser"            = ["container-engine"]
    }
  }

  iam = merge(
    {
      "roles/container.developer" = ["serviceAccount:${data.terraform_remote_state.hub.outputs.hub_vm_service_account_email}"]
      "roles/owner"               = var.owners_gke
      "roles/container.clusterViewer" = [
        "serviceAccount:${data.terraform_remote_state.hub.outputs.hub_project_number}-compute@developer.gserviceaccount.com"
      ]
    },
    var.cluster_create
    ? {
      "roles/logging.logWriter"       = [module.cluster_nodepool[0].service_account_iam_email]
      "roles/monitoring.metricWriter" = [module.cluster_nodepool[0].service_account_iam_email]
    }
    : {}
  )
}

module "spoke_vpc" {
  source     = "../net-vpc"
  project_id = module.spoke_project.project_id
  name       = "${var.spoke_name}-shared-vpc"
  subnets    = [
    {
      ip_cidr_range = var.ip_ranges.gce
      name          = "gce"
      region        = var.region
      iam           = {
        "roles/compute.networkUser" = concat(var.owners_gce, [
          "serviceAccount:${module.service_project.service_accounts.cloud_services}",
          "serviceAccount:${module.service_project.service_accounts.robots.container-engine}"
        ])
      }
    },
    {
      ip_cidr_range = var.ip_ranges.gke
      name          = "gke"
      region        = var.region
      secondary_ip_ranges = {
      pods     = var.ip_secondary_ranges.gke_pods
      services = var.ip_secondary_ranges.gke_services
      }
      iam = {
        "roles/compute.networkUser" = concat(var.owners_gke, [
          "serviceAccount:${module.spoke_project.number}@cloudservices.gserviceaccount.com",
          "serviceAccount:${module.service_project.service_accounts.cloud_services}",
          "serviceAccount:${module.service_project.service_accounts.robots.container-engine}",
          "serviceAccount:service-${module.service_project.number}@container-engine-robot.iam.gserviceaccount.com",
          "serviceAccount:${module.service_project.number}@cloudservices.gserviceaccount.com",
          "serviceAccount:service-${module.service_project.number}@compute-system.iam.gserviceaccount.com"
        ])
      }
    }
  ]
}

module "spoke1_firewall_rules" {
  source     = "../net-vpc-firewall"
  project_id = module.spoke_project.project_id
  network    = module.spoke_vpc.name
 default_rules_config = {
    admin_ranges = values(var.ip_ranges)
  }
}


module "spoke_private_dns" {
  source      = "../dns"
  project_id  = module.spoke_project.project_id
  name        = "${var.spoke_name}-private-zone"
  description = "Private DNS zone for ${var.spoke_number}"
  zone_config = {
    domain    = "gke${var.spoke_number}.mcs-paas-dev.gcp.t-systems.net."
    private   = {
      client_networks = [module.spoke_vpc.self_link]
    }
  }
  recordsets = {
    "A localhost" = { records = ["127.0.0.1"] }
    "A bastion"   = { records = [data.terraform_remote_state.hub.outputs.hub_vm_internal_ip] }
  }
}

module "spoke_vm" {
  source     = "../compute-vm"
  project_id = module.spoke_project.project_id
  zone       = "${var.region}-b"
  name       = "${var.prefix}-${var.spoke_number}"
  network_interfaces = [{
    network    = module.spoke_vpc.self_link
    subnetwork = module.spoke_vpc.subnet_self_links["${var.region}/gke"]
    nat        = false
    addresses  = null
  }]
  metadata = { startup-script = local.vm_startup_script }
  service_account = {
    auto_create = true
  }
  tags = ["ssh"]
}

module "cluster" {
  source     = "../gke-cluster-standard"
  count      = var.cluster_create ? 1 : 0
  name       = "cluster-1"
  project_id = module.service_project.project_id
  location   = "${var.region}-b"
  vpc_config = {
    network    = module.spoke_vpc.self_link
    subnetwork = module.spoke_vpc.subnet_self_links["${var.region}/gke"]
    master_ipv4_cidr_block = var.private_service_ranges.cluster_1
    secondary_range_names = {
      #pods     = var.ip_secondary_ranges["gke_pods"]
      #services = var.ip_secondary_ranges["gke_services"]
    }
    master_authorized_ranges = {
      "CorpNet" = "10.0.0.0/24"
    }
  }
  max_pods_per_node = 32
  private_cluster_config = {
    enable_private_endpoint = true
    master_global_access    = true
    peering_config = {
      project_id = module.spoke_project.project_id 
      export_routes = true
      import_routes = false
    }
  }
  labels = {
    environment = "test"
  }
  deletion_protection = var.deletion_protection
}

module "cluster_nodepool" {
  source       = "../gke-nodepool"
  count        = var.cluster_create ? 1 : 0
  name         = "nodepool-${var.spoke_name}"
  project_id   = module.service_project.project_id
  location     = module.cluster[0].location
  cluster_name = module.cluster[0].name
  cluster_id   = module.cluster[0].id
  service_account = {
    create = true
  }
}

###vpn - peering####

locals {
  unique_id = formatdate("YYYYMMDDHHmmss", timestamp())
}

module "hub_to_spoke_peering" {
  source        = "../net-vpc-peering"
  local_network = "projects/${data.terraform_remote_state.hub.outputs.hub_project_id}/global/networks/${data.terraform_remote_state.hub.outputs.hub_network_name}"
  peer_network  = "projects/${module.spoke_project.project_id}/global/networks/${module.spoke_vpc.name}"
  routes_config = {
    local = { export = true, import = false }
    peer  = { export = false, import = true }
  }
}

module "vpn_hub" {
  source     = "../net-vpn-ha"
  project_id = data.terraform_remote_state.hub.outputs.hub_project_id
  region     = var.region
  network    = data.terraform_remote_state.hub.outputs.hub_network_name
  name = "${var.prefix}-hub-${local.unique_id}"
  peer_gateways = {
    default = { gcp = module.vpn_spoke.self_link }
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
        address = var.bgp_peer_addresses["hub_remote_0"]
        #address = "169.254.1.1"
        asn     = 64515
      }
      bgp_session_range     = var.bgp_session_ranges["hub_remote_0"]
      #bgp_session_range     = "169.254.1.2/30"
      vpn_gateway_interface = 0
    }
    remote-1 = {
      bgp_peer = {
        address = var.bgp_peer_addresses["hub_remote_1"]
        #address = "169.254.2.1"
        asn     = 64515
      }
      bgp_session_range     = var.bgp_session_ranges["hub_remote_1"]
      #bgp_session_range     = "169.254.2.2/30"
      vpn_gateway_interface = 1
    }
  }
}

module "vpn_spoke" {
  source     = "../net-vpn-ha"
  #project_id = data.terraform_remote_state.spoke.outputs.spoke_project_id
  project_id = module.spoke_project.project_id
  region     = var.region
  #network    = data.terraform_remote_state.spoke.outputs.spoke_network_name
  network = module.spoke_vpc.name
  name = "${var.prefix}-spoke-${local.unique_id}"
  router_config = {
    asn = 64515
    custom_advertise = {
      all_subnets          = true
      all_vpc_subnets      = true
      all_peer_vpc_subnets = true
      ip_ranges = {
        "10.0.0.0/8"                                  = "default"
        "${var.private_service_ranges.cluster_1}" = "access to control plane"
      }
    }
  }
  peer_gateways = {
    default = { gcp = module.vpn_hub.self_link }
  }
  tunnels = {
    remote-0 = {
      bgp_peer = {
        address = var.bgp_peer_addresses["spoke_remote_0"]
        #address = "169.254.1.2"
        asn     = 64516
      }
      bgp_session_range     = var.bgp_session_ranges["spoke_remote_0"]
      #bgp_session_range     = "169.254.1.1/30"
      shared_secret         = module.vpn_hub.random_secret
      vpn_gateway_interface = 0
    }
    remote-1 = {
      bgp_peer = {
        address = var.bgp_peer_addresses["spoke_remote_1"]
        #address = "169.254.2.2"
        asn     = 64516
      }
      bgp_session_range     = var.bgp_session_ranges["spoke_remote_1"]
      #bgp_session_range     = "169.254.2.1/30"
      shared_secret         = module.vpn_hub.random_secret
      vpn_gateway_interface = 1
    }
  }
}
