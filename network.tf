


resource "azurerm_subnet" "databases-psql-01" {
  name                 = "${local.subscription_name}-db-psql-01"
  resource_group_name  = "${local.subscription_name}-WLRG"
  virtual_network_name = "${local.subscription_name}-VNET"

  address_prefixes  = ["10.86.81.0/27"]
  service_endpoints = ["Microsoft.Storage"]

  delegation {
    name = "postgresqldelegation"

    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"

      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }
}

resource "azurerm_subnet" "databases-psql-02" {
  name                 = "${local.subscription_name}-db-psql-02"
  resource_group_name  = "${local.subscription_name}-WLRG"
  virtual_network_name = "${local.subscription_name}-VNET"

  address_prefixes  = ["10.86.81.32/27"]
  service_endpoints = ["Microsoft.Storage"]

  delegation {
    name = "postgresqldelegation"

    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"

      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }
}

resource "azurerm_subnet" "databases-mssql-01" {
  name                 = "${local.subscription_name}-db-mssql-01"
  resource_group_name  = "${local.subscription_name}-WLRG"
  virtual_network_name = "${local.subscription_name}-VNET"

  address_prefixes = ["10.86.81.64/27"]

  # Delegation retained: SQL MI d-az-lmk-nfx-dev-01-mssqlmi-01 still occupies
  # this subnet and applies a Network Intent Policy, so Azure blocks removal of
  # the delegation/NSG. The MI is being deleted; once it and its virtual cluster
  # are fully gone and the NIP clears, remove this delegation and apply.
  delegation {
    name = "managedinstancedelegation"

    service_delegation {
      name = "Microsoft.Sql/managedInstances"

      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
      ]
    }
  }
}

resource "azurerm_subnet" "databases-mssql-02" {
  name                 = "${local.subscription_name}-db-mssql-02"
  resource_group_name  = "${local.subscription_name}-WLRG"
  virtual_network_name = "${local.subscription_name}-VNET"

  address_prefixes = ["10.86.81.96/27"]

  delegation {
    name = "managedinstancedelegation"

    service_delegation {
      name = "Microsoft.Sql/managedInstances"

      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
      ]
    }
  }
}

data "azurerm_virtual_network" "workload" {
  name                = "${local.subscription_name}-VNET"
  resource_group_name = "${local.subscription_name}-WLRG"
}

resource "azurerm_subnet" "entra_domain_services" {
  name                 = "${local.subscription_name}-aadds"
  resource_group_name  = data.azurerm_virtual_network.workload.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.workload.name
  address_prefixes     = [local.entra_domain_subnet_cidr]
}

resource "azurerm_private_dns_zone" "postgresql" {
  name                = "private.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.shared_data.name

  tags = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgresql" {
  name                  = "${local.subscription_name}-psql-dns-link"
  resource_group_name   = azurerm_resource_group.shared_data.name
  private_dns_zone_name = azurerm_private_dns_zone.postgresql.name
  virtual_network_id    = data.azurerm_virtual_network.workload.id
  registration_enabled  = false

  tags = local.tags
}


resource "azurerm_subnet" "apps-01" {
  name                 = "${local.subscription_name}-apps-01"
  resource_group_name  = "${local.subscription_name}-WLRG"
  virtual_network_name = "${local.subscription_name}-VNET"

  address_prefixes = ["10.86.82.0/24"]
}



resource "azurerm_subnet" "apps-02" {
  name                 = "${local.subscription_name}-apps-02"
  resource_group_name  = "${local.subscription_name}-WLRG"
  virtual_network_name = "${local.subscription_name}-VNET"

  address_prefixes = ["10.86.83.0/24"]
}

# -----------------------------------------------------------------------------
# Route all subnet egress through the Azure Firewall
# -----------------------------------------------------------------------------

resource "azurerm_route_table" "firewall" {
  name                = "${local.subscription_name}-fw-rt"
  location            = local.location
  resource_group_name = "${local.subscription_name}-WLRG"

  # Direct public-IP ingress needs replies to bypass the stateful firewall.
  # This exception applies to both application subnets using this table.
  dynamic "route" {
    for_each = toset(local.workspaces)
    iterator = workspace

    content {
      name           = "workspace-${replace(replace(workspace.value, ".", "-"), "/", "-")}"
      address_prefix = workspace.value
      next_hop_type  = "Internet"
    }
  }

  route {
    name                   = "default-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = local.firewall_private_ip
    #next_hop_in_ip_address = data.azurerm_firewall.this.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_route_table" "databases-psql-01" {
  name                = "${local.subscription_name}-db-psql-01-rt"
  location            = local.location
  resource_group_name = "${local.subscription_name}-WLRG"

  route {
    name           = "azure-active-directory"
    address_prefix = "AzureActiveDirectory"
    next_hop_type  = "Internet"
  }

  # route {
  #   name           = "postgresql-subnet"
  #   address_prefix = "10.86.81.0/27"
  #   next_hop_type  = "VnetLocal"
  # }

  route {
    name                   = "default-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = local.firewall_private_ip
  }
}

resource "azurerm_route_table" "databases-psql-02" {
  name                = "${local.subscription_name}-db-psql-02-rt"
  location            = local.location
  resource_group_name = "${local.subscription_name}-WLRG"

  route {
    name           = "azure-active-directory"
    address_prefix = "AzureActiveDirectory"
    next_hop_type  = "Internet"
  }

  # route {
  #   name           = "postgresql-subnet"
  #   address_prefix = "10.86.81.32/27"
  #   next_hop_type  = "VnetLocal"
  # }

  route {
    name                   = "default-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = local.firewall_private_ip
  }
}

# -----------------------------------------------------------------------------
# Dedicated route tables for the SQL Managed Instance subnets.
# Azure attaches a Network Intent Policy to MI-delegated subnets that requires
# the associated route table to contain an exact VnetLocal route for the
# subnet's own CIDR, alongside the default-to-firewall egress route.
# -----------------------------------------------------------------------------

resource "azurerm_route_table" "databases-mssql-01" {
  name                = "${local.subscription_name}-db-mssql-01-rt"
  location            = local.location
  resource_group_name = "${local.subscription_name}-WLRG"

  route {
    name           = "subnet-to-vnetlocal"
    address_prefix = one(azurerm_subnet.databases-mssql-01.address_prefixes)
    next_hop_type  = "VnetLocal"
  }

  route {
    name                   = "default-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = local.firewall_private_ip
  }
}

resource "azurerm_route_table" "databases-mssql-02" {
  name                = "${local.subscription_name}-db-mssql-02-rt"
  location            = local.location
  resource_group_name = "${local.subscription_name}-WLRG"

  route {
    name           = "subnet-to-vnetlocal"
    address_prefix = one(azurerm_subnet.databases-mssql-02.address_prefixes)
    next_hop_type  = "VnetLocal"
  }

  route {
    name                   = "default-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = local.firewall_private_ip
  }
}

resource "azurerm_subnet_route_table_association" "databases-psql-01" {
  subnet_id      = azurerm_subnet.databases-psql-01.id
  route_table_id = azurerm_route_table.databases-psql-01.id
}

resource "azurerm_subnet_route_table_association" "databases-psql-02" {
  subnet_id      = azurerm_subnet.databases-psql-02.id
  route_table_id = azurerm_route_table.databases-psql-02.id
}

resource "azurerm_subnet_route_table_association" "databases-mssql-01" {
  subnet_id      = azurerm_subnet.databases-mssql-01.id
  route_table_id = azurerm_route_table.databases-mssql-01.id
}

resource "azurerm_subnet_route_table_association" "databases-mssql-02" {
  subnet_id      = azurerm_subnet.databases-mssql-02.id
  route_table_id = azurerm_route_table.databases-mssql-02.id
}

resource "azurerm_subnet_route_table_association" "apps-01" {
  subnet_id      = azurerm_subnet.apps-01.id
  route_table_id = azurerm_route_table.firewall.id
}

resource "azurerm_subnet_route_table_association" "apps-02" {
  subnet_id      = azurerm_subnet.apps-02.id
  route_table_id = azurerm_route_table.firewall.id
}
