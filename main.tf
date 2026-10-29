data "azurerm_resource_group" "workload" {
  name = "${local.subscription_name}-WLRG"
}

data "azurerm_log_analytics_workspace" "this" {
  name                = "default-ws"
  resource_group_name = "D-AZ-LMK-NFX-DEV-01-SVRG"
}

# -----------------------------------------------------------------------------
# Storage Account
# -----------------------------------------------------------------------------

module "keyvault_secrets" {
  source = "git::https://gitlab.com/ds365ai/neftex/terraform-modules/azure/terraform-az-nfx-secret?ref=v0.0.8"

  vault_id = data.azurerm_key_vault.myvault.id

  accounts = {
    databases = {
      psql01-dev  = { username = "psql_admin" }
      mssql01-dev = { username = "mssql_admin" }
    }
    applications = {
      geoserver = { username = "geoserver_admin" }
    }
    application_accounts = {
      myapp = { username = "myapp_admin" }
    }
    service_accounts = {
      myservice = { username = "myservice_admin" }
    }
    admin_accounts   = {}
    server_specific  = {}
    network_specific = {}
    sshkeys = {
      wks-dev = { username = local.admin_username }
    }
  }
}

data "azurerm_key_vault_secret" "workstation_ssh_public_key" {
  name         = "sshkeys--wks-dev"
  key_vault_id = data.azurerm_key_vault.myvault.id

  depends_on = [module.keyvault_secrets]
}

#--------------------------------------------------------------------------------------
module "psql01dev" {
  source = "git::https://gitlab.com/ds365ai/neftex/terraform-modules/azure/terraform-az-nfx-postgresql?ref=v0.0.10"

  instance_identifier = "psql01-dev"
  resource_group_name = azurerm_resource_group.shared_data.name
  location            = local.location
  environment         = local.environment

  sku_name       = "B_Standard_B2ms"
  engine_version = "17"
  storage_mb     = 1048576

  # VNet integration (private access)
  delegated_subnet_id           = azurerm_subnet.databases-psql-01.id
  private_dns_zone_id           = azurerm_private_dns_zone.postgresql.id
  public_network_access_enabled = false


  create_network_security_group = true
  network_resource_group_name   = "${local.subscription_name}-WLRG"
  allowed_client_cidr_ranges    = local.allowed_ips_db

  active_directory_auth_enabled = true
  tenant_id                     = local.tenant_id
  password_auth_enabled         = true

  active_directory_administrator_object_id      = data.azurerm_user_assigned_identity.D_AZ_LMK_NFX_DEV_01_msi_provisioner.principal_id
  active_directory_administrator_principal_name = data.azurerm_user_assigned_identity.D_AZ_LMK_NFX_DEV_01_msi_provisioner.name
  active_directory_administrator_principal_type = "ServicePrincipal"

  create_geodata_parameter_group = true
  shared_buffers                 = local.psql01_dev_shared_buffers_kb
  effective_cache_size_kb        = local.psql01_dev_effective_cache_size_kb
  maintenance_work_mem_kb        = local.psql01_dev_maintenance_work_mem_kb
  max_worker_processes           = local.psql01_dev_max_worker_processes

  backup_retention_period         = 14
  maintenance_window_enabled      = true
  maintenance_window_day          = 0
  maintenance_window_start_hour   = 3
  maintenance_window_start_minute = 0

  tenant_name      = local.subscription_name
  crf_id           = local.crf_id
  customer_name    = local.customer_name
  environment_type = local.environment_type
  cloud_provider   = local.cloud_provider

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgresql]
}



#module "mssql01dev" {
#  source = "git::https://gitlab.com/ds365ai/neftex/terraform-modules/azure/terraform-az-nfx-sql-managed-instance?ref=v0.0.9"
#
#  # Basic
#  instance_name       = "${local.subscription_name}-mssqlmi-01"
#  resource_group_name = azurerm_resource_group.shared_data.name
#  location            = local.location
#
#  # Reuse the existing delegated SQL Managed Instance subnet from network.tf
#  subnet_id = azurerm_subnet_route_table_association.databases-mssql-01.subnet_id
#
#  # NSG is created by the module itself, but the subnet lives in the WLRG, not the module's resource_group_name (DATA)
#  network_resource_group_name = "${local.subscription_name}-WLRG"
#  allowed_client_cidr_ranges  = local.allowed_ips_db
#
#  # Reuse the existing Key Vault and JSON credentials secret
#  key_vault_name                = data.azurerm_key_vault.myvault.name
#  key_vault_resource_group_name = "${local.subscription_name}-SVRG"
#  kv_sql_admin_json_secret_name = "databases--mssql01-dev"
#
#  # Capacity
#  sku_name           = "GP_Gen5"
#  vcores             = 8
#  storage_size_in_gb = 1280
#  license_type       = "BasePrice"
#  #  engine_version = "12.0" # azure does not support configurable version in mssql managed instance,azure control the version
#
#  # Microsoft Entra administrator (disabled for quick test deploy)
#  enable_aad_admin = false
#
#  # Diagnostics and auditing
#  enable_diagnostics         = true
#  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.this.id
#
#  # Microsoft Defender for SQL (disabled for quick test deploy)
#  enable_defender = false
#
#  # Transparent Data Encryption using the Azure service-managed key
#  enable_transparent_data_encryption = true
#
#  # Tags
#  crf_id           = local.crf_id
#  customer_name    = local.customer_name
#  environment_type = local.environment_type
#  environment      = local.environment
#  tenant_name      = local.subscription_name
#  cloud_provider   = local.cloud_provider
#  product          = "neftex"
#
#}

#module "entra_domain_services" {
#  source = "git::https://gitlab.com/ds365ai/neftex/terraform-modules/azure/terraform-az-nfx-entra-domain-services?ref=v0.0.3"
#
#  name                = "${local.subscription_name}-aadds"
#  resource_group_name = data.azurerm_resource_group.workload.name
#  location            = local.location
#  domain_name         = local.ad_domain
#  subnet_id           = azurerm_subnet.entra_domain_services.id
#  sku                 = "Standard"
#
#  tenant_name      = local.subscription_name
#  environment      = local.environment
#  customer_name    = local.customer_name
#  crf_id           = local.crf_id
#  cloud_provider   = local.cloud_provider
#  environment_type = local.environment_type
#  product          = "neftex"
#  tags             = local.tags
#}

resource "random_password" "local_admin" {
  length      = 16
  special     = false
  lower       = true
  upper       = true
  numeric     = true
  min_lower   = 1
  min_numeric = 1
  min_upper   = 1
}

module "jumpbox" {
  source = "git::https://gitlab.com/ds365ai/neftex/terraform-modules/azure/terraform-az-nfx-jumpbox-vm?ref=v0.0.4"

  providers = {
    azurerm     = azurerm
    azurerm.sig = azurerm.sig-resources-id
  }

  vm_name             = "${local.subscription_name}-jbx-dev-01"
  location            = local.location
  resource_group_name = data.azurerm_resource_group.workload.name
  subnet_id           = azurerm_subnet.apps-01.id

  admin_username = local.admin_username
  admin_password = random_password.local_admin.result

  vm_size           = "Standard_B2s"
  os_disk_size_gb   = 1280
  availability_zone = "1"

  patch_mode                = "AutomaticByOS"
  automatic_updates_enabled = true
  enable_boot_diagnostics   = true
  enable_monitoring         = true
  enable_backup             = false

  sig_gallery_name        = local.sig_gallery_name
  sig_image_name          = local.sig_windows_2019_image_name
  sig_image_version       = local.sig_image_version
  sig_resource_group_name = local.sig_resource_group_name

  public_ip_enabled                   = true
  all_traffic_source_address_prefixes = local.workspaces
  deny_other_inbound                  = true

  tags = merge(local.tags, { product = "neftex" })

  depends_on = [azurerm_subnet_route_table_association.apps-01]
}

resource "azurerm_key_vault_secret" "jumpbox_admin" {
  name = "server-specific--jbx-dev-01"

  value = jsonencode({
    username = local.admin_username
    password = random_password.local_admin.result
  })

  key_vault_id = data.azurerm_key_vault.myvault.id
  content_type = "application/json"
}

module "internal_lb" {
  source = "git::https://gitlab.com/ds365ai/neftex/terraform-modules/azure/terraform-az-nfx-lb-internal?ref=v0.0.1"

  environment         = local.environment
  location            = local.location
  resource_group_name = data.azurerm_resource_group.workload.name
  vnet_id             = data.azurerm_virtual_network.main.id
  subnet_id           = azurerm_subnet.apps-01.id
  private_ip_address  = "10.86.82.10"
  dns_zone_name       = "azurenfx.internal"
  host_name           = "app"
  allowed_source_ip   = local.workspaces[0]
}
