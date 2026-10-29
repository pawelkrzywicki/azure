# # -----------------------------------------------------------------------------
# # Blob storage (AWS S3-bucket equivalent) + AKS data-plane access
# # -----------------------------------------------------------------------------

# module "storage" {
#   source = "git::https://gitlab.com/ds365ai/neftex/terraform-modules/azure/terraform-az-nfx-storage?ref=v0.0.2"

#   environment         = local.environment
#   resource_group_name = data.azurerm_resource_group.workload.name
#   location            = local.location
#   storage_containers  = local.storage_containers
# }

# data "azurerm_storage_account" "nfx" {
#   name                = lower(replace("${local.environment}nfxstorage", "-", ""))
#   resource_group_name = data.azurerm_resource_group.workload.name

#   depends_on = [module.storage]
# }

# # One role assignment per container (same loop/source as the module) so each
# # blob is an independent RBAC boundary. Today every container grants the AKS
# # node (kubelet) identity read + write; per-container principals/roles can be
# # split out from this loop later without touching the storage definition.
# resource "azurerm_role_assignment" "aks_blob_data_contributor" {
#   for_each = toset(local.storage_containers)

#   scope                = "${data.azurerm_storage_account.nfx.id}/blobServices/default/containers/${local.environment}-nfx-${each.value}"
#   role_definition_name = "Storage Blob Data Contributor"
#   principal_id         = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id

#   depends_on = [azurerm_role_assignment.terraform_storage_rbac]
# }
