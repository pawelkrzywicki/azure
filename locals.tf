# # AWS-to-Azure migration inventory. Review placeholders before using these locals.
# locals {
#   # Database sizing and PostgreSQL parameters
#   db_memory_db_psql01_dev            = 8388608
#   psql01_dev_shared_buffers_kb       = floor(local.db_memory_db_psql01_dev * 0.25)
#   psql01_dev_effective_cache_size_kb = floor(local.db_memory_db_psql01_dev * 0.75)
#   psql01_dev_maintenance_work_mem_kb = floor(local.db_memory_db_psql01_dev * 0.05)
#   psql01_dev_max_worker_processes    = 8

#   # Network and agent configuration
#   vnet_range                       = "10.86.80.0/20"                                             # AWS: vpc_range
#   arcgis_cloud_servers             = ["18.234.22.29/32", "54.85.173.122/32", "18.234.22.253/32"] # AWS: arcgiscloudservers
#   workspaces_range                 = "63.33.154.0/24"
#   splunk_username                  = "admin"           # AWS: splunk_user; review for Azure
#   splunk_password_key_vault_secret = "splunk-password" # AWS: splunk_pass
#   hub_username                     = "distplatsvc"     # AWS: hub_user
#   hub_token_key_vault_secret       = "hub-token"       # AWS: hub_token from SSM
#   qualys_customer_id               = "3222d5c7-8686-ee75-82d7-e2c6b9767cc2"
#   qualys_linux_activation_id       = "8f5299ef-6c45-4488-ac9e-bebfef41338d" # AWS: qualys_lin_activation_id
#   qualys_windows_activation_id     = "74606139-2510-4525-a1d2-ca9f5c704b57"
#   qualys_linux_version             = "5.9.0.31" # AWS: qualys_lin_version
#   qualys_windows_version           = "4.8.0.31" # AWS: qualys_win_version
#   storage_scripts_container        = ""         # AWS: s3_scripts_folder

#   # Azure account, identity, certificates, and private connectivity
#   subscription_id                      = local.account_data.cloud_account_id # AWS: account
#   ad_domain                            = upper("neftex")
#   ad_fqdn                              = "ad.dev.neftex.com"
#   allowed_rbac_principal_object_ids    = []                                     # AWS: allowed_presigned_users
#   allowed_private_endpoint_ids         = []                                     # AWS: allowed_vpces
#   shared_image_gallery_subscription_id = "b6d99780-0697-4975-aae9-24c6867a0dc1" # AWS: ami_owner
#   bastion_private_ip                   = null                                   # AWS: asabastionip
#   boundary_role_definition_id          = null                                   # AWS: boundary_policy_arn
#   certificate_key_vault_secret_id      = null                                   # AWS: certarn
#   dev_certificate_key_vault_secret_id  = null                                   # AWS: certarn_dev
#   cloud_provider                       = "azure"

#   # AKS equivalents for the EKS cluster locals
#   aks_addons = { # AWS: cluster_addons
#     coredns = {
#       managed_by_azure = true
#     }
#     kube_proxy = {
#       managed_by_azure = true
#     }
#     network_plugin = {
#       name = "azure"
#     }
#     disk_csi_driver = {
#       enabled = true
#     }
#     file_csi_driver = {
#       enabled = true
#     }
#     blob_csi_driver = {
#       enabled = true
#     }
#   }
#   aks_cluster_name       = "aks-cluster" # AWS: cluster_name
#   aks_kubernetes_version = "1.34"        # AWS: cluster_version; verify Azure regional support
#   aks_subnet_ids         = []            # AWS: cluster_subnet_ids

#   # Environment metadata and Azure network names
#   crf_id                         = local.account_data.crf_id
#   customer_name                  = local.account_data.company
#   default_vnet_name              = "${local.subscription_name}-VNET" # AWS: default_vpc_name
#   dmz_subnet_ids                 = []
#   larger_dmz_subnet_ids          = [] # AWS: biggerdmz_subnet_ids
#   dns_zone                       = "${replace(local.subscription_name, "-", "")}.${local.account_data.ad_domain}"
#   environment                    = local.account_data.environment_type
#   environment_type               = local.account_data.environment_type
#   iaas_multi_az_subnet_ids       = []                     # AWS: iaasmultiaz_subnet_ids; Azure availability zones are configured per resource
#   admin_username                 = "remote_admin"         # AWS: key_name
#   linux_image_name               = "com.lgc.centos7.base" # AWS: linux_ami_regex_value
#   maintenance_window             = local.account_data.maintenance_window
#   mssql_managed_instance_sku     = "GP_Gen5"                         # AWS: mssqlinstanceclass
#   nfx_dns_zone                   = "dev.neftex.com"                  # AWS: nfxdnszone
#   ops_automator_task_list        = "Snapshot-Weekly,DeleteSnapshot5" # AWS: OpsAutomatorTaskList
#   os_linux                       = "linux"
#   os_windows                     = "windows"
#   private_subnet_id              = null # AWS data.aws_subnet.private_subnet.id
#   private_subnet_name            = "${local.subscription_name}-IaaS"
#   provisioner_private_ip         = null # AWS: provisionerip
#   public_subnet_id               = null # AWS data.aws_subnet.public_subnet.id
#   public_subnet_name             = "${local.subscription_name}-Public"
#   product                        = "neftex"
#   location                       = local.account_data.cloud_region # AWS: region
#   short_environment              = "dev"
#   sql_image_name                 = "com.lgc.windows2019.sql2016"   # AWS: sql_ami_regex_value
#   subscription_name              = local.account_data.account_name # AWS: tenant_name
#   ubuntu_image_name              = "com.lgc.ubuntu20.base"         # AWS: ubuntu_ami_regex_value
#   managed_disk_iops              = 500                             # AWS: volume_iops
#   managed_disk_size_gb           = 128                             # AWS: volume_size
#   windows_image_name             = "com.lgc.windows2019.base"      # AWS: windows_ami_regex_value
#   workstation_vm_size            = "Standard_D4s_v5"               # AWS: workstation_instance_size
#   database_monitoring_interval   = 30                              # AWS: rds_monitoring_interval
#   database_monitor_identity_id   = null                            # AWS: rds_monitoring_role_arn
#   application_gateway_ssl_policy = "AppGwSslPolicy20220101S"       # AWS: ssl_policy_alb

#   # AWS Secrets Manager entries converted to Azure Key Vault secret names
#   key_vault_secret_names = [
#     "ad-admin-password",
#     "local-admin-password",
#     "test-db-as-password",
#     "test-db-postgres-password",
#     "test-db-service-password",
#     "test-fme-password",
#     "test-artifactory-password",
#     "newrelic-api-key",
#     "newrelic-license-key",
#     "dl-neftex-alerting-group",
#     "arcgis-server-password",
#     "db-restore-password",
#     "opensearch-master-password",
#     "okta-secret",
#     "validationkey",
#     "decryptionkey",
#     "fixedtoken",
#     "oktatoken",
#     "wmlayoutpwd",
#     "aks-okta-envs",
#     "aks-kafka-listener",
#     "aks-mssql01-creds",
#     "aks-rd-mssql01-creds",
#     "aks-postgresql02-creds",
#     "aks-psql01-dev-creds",
#     "fme-passwords",
#     "aks-spotfire-oci-registry-creds",
#     "aks-mail",
#     "aks-certificates",
#     "aks-keycloak"
#   ]

#   key_vault_secret_descriptions = [
#     "Password for AD admin account",
#     "Password for local admin account",
#     "Password for AS SQL database",
#     "Password for PostgreSQL database",
#     "Password for service SQL database",
#     "Password for FME",
#     "Password for Artifactory",
#     "New Relic installer API key",
#     "New Relic license key for D-AZ-LMK-NFX-DEV-01",
#     "Alerting group email addresses",
#     "Password for ArcGIS server",
#     "Secret for database restoration",
#     "OpenSearch master password",
#     "Okta client secret",
#     "Validation key for Web.xml",
#     "Decryption key for Web.xml",
#     "Fixed token for Client Portal",
#     "Okta token",
#     "Webmapper layout password",
#     "Okta client configuration for all environments",
#     "Kafka listener credentials",
#     "Database connection credentials for mssql01",
#     "Database connection credentials for rd-mssql01",
#     "Database connection credentials for postgresql02",
#     "Database connection credentials for psql01-dev",
#     "Group credentials for FME",
#     "Spotfire OCI registry credentials",
#     "Mail service values",
#     "AKS cluster certificates",
#     "Keycloak authentication credentials"
#   ]

#   allowed_role_assignment_principal_ids = [] # AWS: allowed_principals

#   allowed_ips_db = [
#     "107.22.231.94/32",
#     "108.128.57.38/32",
#     "185.230.235.32/28",
#     "217.40.59.24/29",
#     "34.198.112.183/32",
#     "34.198.173.153/32",
#     "34.205.117.216/32",
#     "34.205.14.94/32",
#     "34.231.49.237/32",
#     "5.158.229.64/29",
#     "52.71.249.146/32",
#     "52.87.128.35/32",
#     "54.155.21.195/32",
#     "54.155.221.55/32",
#     "54.208.105.252/32",
#     "54.225.100.136/32",
#     "63.33.154.114/32",
#     "75.101.139.164/32",
#     "79.135.50.112/32",
#     "10.51.0.0/16",
#     "10.114.160.16/28",
#     "10.7.0.0/16",
#     "3.217.116.13/32",
#     "54.87.55.150/32",
#     "54.80.4.23/32"
#   ]

#   allowed_ips_aks = [ # AWS: allowed_ips_eks
#     "107.22.231.94/32",
#     "134.132.0.0/16",
#     "185.230.235.32/28",
#     "185.55.61.160/28",
#     "34.198.112.183/32",
#     "34.198.173.153/32",
#     "34.205.117.216/32",
#     "34.205.14.94/32",
#     "34.231.49.237/32",
#     "46.249.196.208/28",
#     "5.158.229.64/29",
#     "52.71.249.146/32",
#     "52.87.128.35/32",
#     "54.208.105.252/32",
#     "54.225.100.136/32",
#     "63.33.154.114/32",
#     "75.101.139.164/32",
#     "79.135.50.112/32",
#     "3.217.116.13/32"
#   ]

#   allowed_ips_storage = [ # AWS: allowed_ips_s3
#     "107.22.231.94/32",
#     "108.128.57.38/32",
#     "134.132.0.0/16",
#     "18.159.27.183/32",
#     "18.159.79.7/32",
#     "18.197.38.71/32",
#     "217.40.59.24/29",
#     "3.71.198.84/32",
#     "3.74.90.60/32",
#     "34.198.112.183/32",
#     "34.198.173.153/32",
#     "34.205.117.216/32",
#     "34.205.14.94/32",
#     "34.231.49.237/32",
#     "35.156.49.6/32",
#     "5.158.229.64/29",
#     "52.59.103.51/32",
#     "52.71.249.146/32",
#     "52.87.128.35/32",
#     "54.155.21.195/32",
#     "54.155.221.55/32",
#     "54.208.105.252/32",
#     "54.225.100.136/32",
#     "63.33.154.114/32",
#     "75.101.139.164/32",
#     "86.139.188.149/32",
#     "3.217.116.13/32"
#   ]
# }
