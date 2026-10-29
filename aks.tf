# -----------------------------------------------------------------------------
# AKS cluster (native azurerm resources)
#
# Rewritten from the AVM module Azure/avm-res-containerservice-managedcluster,
# which requires Terraform >= 1.11 and cannot run on Terraform 1.8.1. The native
# azurerm_kubernetes_cluster resource works on Terraform 1.8.x with the azurerm
# 4.x provider while preserving the original cluster configuration.
# -----------------------------------------------------------------------------

variable "aks" {
  description = "AKS cluster settings."
  type = object({
    kubernetes_version = string
  })
  default = {
    kubernetes_version = "1.35"
  }
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = "${local.subscription_name}-aks"
  location            = data.azurerm_resource_group.workload.location
  resource_group_name = data.azurerm_resource_group.workload.name
  dns_prefix          = local.subscription_name

  kubernetes_version = var.aks.kubernetes_version

  sku_tier = "Standard"

  # Private API server with an AKS-managed private DNS zone
  private_cluster_enabled             = true
  private_cluster_public_fqdn_enabled = false
  private_dns_zone_id                 = "System"

  # Workload Identity / OIDC
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # Entra ID managed integration with Azure RBAC for Kubernetes authorization
  azure_active_directory_role_based_access_control {
    tenant_id          = local.tenant_id
    azure_rbac_enabled = true
  }

  # Reuse the pre-provisioned identity; verify its existing network permissions.
  # Terraform does not create or widen role assignments.
  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.D_AZ_LMK_NFX_DEV_01_msi_aks_control_plane.id]
  }

  # System node pool: min 3 nodes spread across the 3 availability zones
  default_node_pool {
    name                 = "system"
    vm_size              = "Standard_D16s_v5"
    auto_scaling_enabled = true
    node_count           = 4
    min_count            = 3
    max_count            = 5
    max_pods             = 30
    os_disk_size_gb      = 256
    zones                = ["1", "2", "3"]
    vnet_subnet_id       = azurerm_subnet.apps-01.id
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay" # required by Azure CNI Powered by Cilium
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    load_balancer_sku   = "standard"
    outbound_type       = "userDefinedRouting"
    service_cidr        = "10.100.0.0/16"
    dns_service_ip      = "10.100.0.10"
  }

  oms_agent {
    log_analytics_workspace_id      = data.azurerm_log_analytics_workspace.this.id
    msi_auth_for_monitoring_enabled = true
  }

  storage_profile {
    blob_driver_enabled = true
    disk_driver_enabled = true
    file_driver_enabled = true
  }

  tags = local.tags

  # node_count is managed by the cluster autoscaler after creation
  lifecycle {
    ignore_changes = [default_node_pool[0].node_count]
  }

  depends_on = [
    azurerm_subnet_route_table_association.apps-01,
    azurerm_subnet_route_table_association.apps-02
  ]
}

resource "azurerm_kubernetes_cluster_node_pool" "apps" {
  name                  = "apps"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  mode                  = "User"

  vm_size              = "Standard_D16s_v5"
  auto_scaling_enabled = true
  node_count           = 4
  min_count            = 3
  max_count            = 5
  max_pods             = 30
  os_disk_size_gb      = 256
  zones                = ["1", "2", "3"]
  vnet_subnet_id       = azurerm_subnet.apps-02.id

  node_labels = {
    workload = "applications"
  }

  tags = local.tags

  lifecycle {
    ignore_changes = [node_count]
  }
}
