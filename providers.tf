provider "azurerm" {
  subscription_id     = "b15d5e4e-f7f3-4ae3-bb8a-54f9930ac045"
  tenant_id           = "b7be7686-6f97-4db7-9081-a23cf09a96b5"
  use_msi             = true
  storage_use_azuread = true
  # Registration is owned by the platform team in this restricted subscription.
  resource_provider_registrations = "none"

  features {
    key_vault {
      recover_soft_deleted_key_vaults = false
      purge_soft_delete_on_destroy    = false
    }
  }
}

provider "azurerm" {
  alias                           = "sig-resources-id"
  resource_provider_registrations = "none"
  use_msi                         = true
  subscription_id                 = "b6d99780-0697-4975-aae9-24c6867a0dc1"
  tenant_id                       = "b7be7686-6f97-4db7-9081-a23cf09a96b5"
  features {}
}

variable "kubernetes_login_method" {
  description = "kubelogin authentication for the private AKS API. MSI is for the existing Azure provisioner; azurecli is for an interactive signed-in session."
  type        = string
  default     = "msi"

  validation {
    condition     = contains(["msi", "azurecli", "workloadidentity"], var.kubernetes_login_method)
    error_message = "Use msi, azurecli, or workloadidentity."
  }
}

variable "kubernetes_managed_identity_client_id" {
  description = "Client ID of the existing runner identity for MSI login, or null for the runner's default managed identity. This must already have Kubernetes authorization."
  type        = string
  default     = null
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.this.kube_config[0].host
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "kubelogin"
    args = concat([
      "get-token", "--login", var.kubernetes_login_method,
      "--server-id", "6dae42f8-4368-4678-94ff-3960e28e3630",
      "--tenant-id", local.tenant_id,
      "--use-azurerm-env-vars"
      ], var.kubernetes_login_method == "msi" && var.kubernetes_managed_identity_client_id != null ? [
      "--client-id", var.kubernetes_managed_identity_client_id
    ] : [])
  }
}
