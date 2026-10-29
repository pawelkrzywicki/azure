terraform {
  backend "azurerm" {
    use_msi          = true
    use_azuread_auth = true

    tenant_id       = "b7be7686-6f97-4db7-9081-a23cf09a96b5"
    subscription_id = "b15d5e4e-f7f3-4ae3-bb8a-54f9930ac045"

    resource_group_name  = "D-AZ-LMK-NFX-DEV-01-WLRG"
    storage_account_name = "dazlmknfxdev01ict"
    container_name       = "ict-tf-state"
    key                  = "ict/terraform.tfstate"
  }
}
