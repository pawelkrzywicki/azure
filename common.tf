locals {
  account_data               = fileexists("${path.module}/../../account.json") ? jsondecode(file("${path.module}/../../account.json")) : jsondecode(file("/etc/megazord/account.json")) # currently set to dev
  tenant_id                  = "b7be7686-6f97-4db7-9081-a23cf09a96b5"
  subscription_name          = local.account_data.account_name
  subscription_id            = local.account_data.cloud_account_id
  storage_account_name       = lower(replace(local.account_data.account_name, "-", ""))
  environment                = local.account_data.environment_type
  environment_prefix         = local.environment
  location                   = local.account_data.cloud_region
  firewall_private_ip        = "10.86.80.4"
  domain_name                = "neftexaz.com" 
  storage_containers = [
    "clientdata",
    "cms",
    "essdatabackup",
    "fairwayfinder",
    "geopointpindrop",
    "geoservercache",
    "gssync",
    "mssqlbackuprestore",
    "productdownload",
    "spotfireresources",
    "webmapconfig",
    "webmapdownload"
  ]
  #environment_prefix          = var.environment ## Thsi is only added if there is no variable like this already there...
  admin_username              = "local_admin"
  dns_zone                    = "${lower(replace(local.account_data.account_name, "-", ""))}.${local.account_data.ad_domain}"
  sig_subscription            = "D-AZ-LMK-ICT-DEV-01"
  sig_subscription_id         = "b6d99780-0697-4975-aae9-24c6867a0dc1"
  sig_gallery_name            = "ICT_BASE_IMAGES"
  sig_resource_group_name     = "${local.sig_subscription}-SIG"
  sig_image_version           = "latest"
  sig_centos_7_image_name     = "com.lgc.centos7.base"
  sig_windows_2019_image_name = "com.lgc.windows2019.base"
  sig_windows_sql_image_name  = "com.lgc.windows2019.sql2016"
  crf_id                      = local.account_data.crf_id
  customer_name               = local.account_data.company
  environment_type            = local.account_data.environment_type
  subnet_name                 = "${local.account_data.account_name}-core"
  os_windows                  = "windows"
  os_linux                    = "linux"
  maintenance_window          = local.account_data.maintenance_window
  ad_domain                   = local.account_data.ad_domain
  # Non-overlapping with workspace subnets; confirm against live VNet allocations before apply.
  entra_domain_subnet_cidr = "10.86.81.128/28"
  cloud_provider           = "azure"
  ops_automator_task_list  = "n/a"
  tags = {
    crf_id           = local.crf_id
    customer_name    = local.customer_name
    environment      = local.environment
    environment_type = local.environment_type
    tenant_name      = local.subscription_name
    cloud_provider   = local.cloud_provider
    managed_by       = "terraform"
  }
  PatchRing = (local.environment == "development" || local.environment == "integration" || local.environment == "qa" ? 1 : (
    local.environment == "validation" || local.environment == "preprod" ? 2 : (
      local.environment == "demo" || local.environment == "poc" || local.environment == "production" ? 3 : null
    )
    )
  )
  TZ          = local.account_data.TZ
  PatchWindow = local.account_data.PatchWindow

  sql_mi_aad_admin_login_name     = data.azurerm_user_assigned_identity.D_AZ_LMK_NFX_DEV_01_msi_provisioner.name
  sql_mi_aad_admin_object_id      = data.azurerm_user_assigned_identity.D_AZ_LMK_NFX_DEV_01_msi_provisioner.principal_id
  sql_mi_aad_admin_principal_type = "Application"

  # # B_Standard_B2ms = 2 vCores / 4 GiB RAM
  db_memory_db_psql01_dev            = 8 * 1024 * 1024
  psql01_dev_shared_buffers_kb       = floor(local.db_memory_db_psql01_dev * 0.25)
  psql01_dev_effective_cache_size_kb = floor(local.db_memory_db_psql01_dev * 0.75)
  psql01_dev_maintenance_work_mem_kb = floor(local.db_memory_db_psql01_dev * 0.05)
  psql01_dev_max_worker_processes    = 4

  allowed_ips_db = [
    "107.22.231.94/32", # US-EAST-1
    "108.128.57.38/32",
    "185.230.235.32/28",
    "5.158.229.64/29",
    "54.155.21.195/32",
    "54.155.221.55/32",
    "79.135.50.112/32",
    "54.87.55.150/32", #Gitlab Runner Access 
    "54.80.4.23/32",   # gitlab runner 1
    "10.86.80.0/22"
  ]

  allowed_ips_aks = [
    "134.132.0.0/16",
    "185.230.235.32/28",
    "185.55.61.160/28",
    "46.249.196.208/28",
    "5.158.229.64/29",
    "79.135.50.112/32"

  ]

  workspaces = [
    "63.33.154.114/32"
  ]

  allowed_ips_storage = [
    "108.128.57.38/32",
    "134.132.0.0/16",
    "3.74.90.60/32",
    "5.158.229.64/29",
    "54.155.21.195/32",
    "54.155.221.55/32",
    "86.139.188.149/32"

  ]
}

data "azurerm_client_config" "current" {}

data "azurerm_key_vault" "myvault" {
  name                = "KV-D-AZ-LMK-NFX-DEV-01"
  resource_group_name = "D-AZ-LMK-NFX-DEV-01-SVRG"
}

data "azurerm_user_assigned_identity" "D_AZ_LMK_NFX_DEV_01_msi_provisioner" {
  name                = "D-AZ-LMK-NFX-DEV-01-msi-provisioner"
  resource_group_name = "D-AZ-LMK-NFX-DEV-01-WLRG"
}


data "azurerm_user_assigned_identity" "D_AZ_LMK_NFX_DEV_01_msi_aks_network" {
  name                = "D-AZ-LMK-NFX-DEV-01-msi-aks-network"
  resource_group_name = "D-AZ-LMK-NFX-DEV-01-WLRG"
}


data "azurerm_user_assigned_identity" "D_AZ_LMK_NFX_DEV_01_msi_aks_kubelet" {
  name                = "D-AZ-LMK-NFX-DEV-01-msi-aks-kubelet"
  resource_group_name = "D-AZ-LMK-NFX-DEV-01-WLRG"
}


data "azurerm_user_assigned_identity" "D_AZ_LMK_NFX_DEV_01_msi_keyvault_read" {
  name                = "D-AZ-LMK-NFX-DEV-01-msi-keyvault-read"
  resource_group_name = "D-AZ-LMK-NFX-DEV-01-WLRG"
}

data "azurerm_user_assigned_identity" "D_AZ_LMK_NFX_DEV_01_msi_aks_control_plane" {
  name                = "D-AZ-LMK-NFX-DEV-01-msi-aks-control-plane"
  resource_group_name = "D-AZ-LMK-NFX-DEV-01-WLRG"
}

data "azurerm_user_assigned_identity" "D_AZ_LMK_NFX_DEV_01_msi_dns" {
  name                = "D-AZ-LMK-NFX-DEV-01-msi-dns"
  resource_group_name = "D-AZ-LMK-NFX-DEV-01-WLRG"
}


data "azurerm_key_vault" "KV_D_AZ_LMK_NFX_DEV_01" {
  name                = "KV-D-AZ-LMK-NFX-DEV-01"
  resource_group_name = "D-AZ-LMK-NFX-DEV-01-SVRG"
}

# Subnet
data "azurerm_subnet" "AzureFirewallSubnet" {
  name                 = "AzureFirewallSubnet"
  virtual_network_name = "D-AZ-LMK-NFX-DEV-01-VNET"
  resource_group_name  = "D-AZ-LMK-NFX-DEV-01-SVRG"
}

data "azurerm_subnet" "AzureBastionSubnet" {
  name                 = "AzureBastionSubnet"
  virtual_network_name = "D-AZ-LMK-NFX-DEV-01-VNET"
  resource_group_name  = "D-AZ-LMK-NFX-DEV-01-SVRG"
}

data "azurerm_subnet" "App_GW" {
  name                 = "App-GW"
  virtual_network_name = "D-AZ-LMK-NFX-DEV-01-VNET"
  resource_group_name  = "D-AZ-LMK-NFX-DEV-01-SVRG"
}

data "azurerm_subnet" "awx_db" {
  name                 = "awx-db"
  virtual_network_name = "D-AZ-LMK-NFX-DEV-01-VNET"
  resource_group_name  = "D-AZ-LMK-NFX-DEV-01-SVRG"
}

# Subnet
data "azurerm_subnet" "mgmt" {
  name                 = "mgmt"
  virtual_network_name = "D-AZ-LMK-NFX-DEV-01-VNET"
  resource_group_name  = "D-AZ-LMK-NFX-DEV-01-SVRG"
}

data "azurerm_virtual_network" "main" {
  name                = "${local.subscription_name}-VNET"
  resource_group_name = "${local.subscription_name}-SVRG"
}
