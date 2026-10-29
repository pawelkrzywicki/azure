provider "azurerm" {
  subscription_id     = "b15d5e4e-f7f3-4ae3-bb8a-54f9930ac045"
  tenant_id           = "b7be7686-6f97-4db7-9081-a23cf09a96b5"
  use_msi             = true
  storage_use_azuread = true
  # Domain Services requires subscription registration before resource creation.
  resource_providers_to_register = ["Microsoft.AAD"]

  features {
    key_vault {
      recover_soft_deleted_key_vaults = false
      purge_soft_delete_on_destroy    = false
    }
  }
}

provider "azurerm" {
  alias           = "sig-resources-id"
  use_msi         = true
  subscription_id = "b6d99780-0697-4975-aae9-24c6867a0dc1"
  tenant_id       = "b7be7686-6f97-4db7-9081-a23cf09a96b5"
  features {}
}
