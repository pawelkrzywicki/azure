# =============================================================================
# SHARED DATABASES RESOURCES GROUP
# =============================================================================
# Databases

resource "azurerm_resource_group" "shared_data" {
  name     = "${local.subscription_name}-DATA"
  location = local.location

  tags = local.tags
}



# =============================================================================
# SHARED APP RESOURCES GROUP
# =============================================================================
# Application Servers 
#AKS cluster

resource "azurerm_resource_group" "shared_app" {
  name     = "${local.subscription_name}-APP"
  location = local.location

  tags = local.tags
}


 