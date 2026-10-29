# AKS owns the load balancer, backend membership, probes and NSG rules through
# the Service below. Do not attach node NICs to a separately managed LB.
variable "external_application" {
  description = "Backend ingress Service settings. It can be provisioned before ingress pods exist. Set null to disable public ingress. target_port is a numeric pod port."
  type = object({
    service_name = string
    namespace    = string
    selector     = map(string)
    ports = list(object({
      name        = string
      port        = number
      target_port = number
    }))
  })
  default = {
    service_name = "applications-public"
    namespace    = "default"
    selector     = { "app.kubernetes.io/name" = "applications-ingress" }
    ports        = [{ name = "https", port = 443, target_port = 443 }]
  }

  validation {
    condition = var.external_application == null ? true : (
      length(var.external_application.selector) > 0 &&
      length(var.external_application.ports) > 0 &&
      length(distinct([for port in var.external_application.ports : port.name])) == length(var.external_application.ports) &&
      length(distinct([for port in var.external_application.ports : port.port])) == length(var.external_application.ports) &&
      alltrue([for port in var.external_application.ports :
        port.port >= 1 && port.port <= 65535 && floor(port.port) == port.port &&
        port.target_port >= 1 && port.target_port <= 65535 && floor(port.target_port) == port.target_port
      ])
    )
    error_message = "Specify pod selectors and at least one TCP port; names and frontend ports must be unique and ports must be integers from 1 to 65535."
  }
}

resource "azurerm_public_ip" "applications" {
  count = var.external_application == null ? 0 : 1

  name     = "${local.subscription_name}-apps-pip"
  location = azurerm_kubernetes_cluster.this.location
  # AKS already has permissions here; using a different RG would need an
  # additional role assignment. The Terraform runner must also be allowed here.
  resource_group_name = azurerm_kubernetes_cluster.this.node_resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags

  lifecycle {
    precondition {
      condition     = length(local.workspaces) == 1 && alltrue([for cidr in local.workspaces : can(cidrnetmask(cidr)) && endswith(cidr, "/32")])
      error_message = "Public application access must be restricted to exactly one workspace IPv4 /32."
    }
  }
}

locals {
  external_application_service = var.external_application == null ? null : {
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = var.external_application.service_name
      namespace = var.external_application.namespace
      annotations = {
        "service.beta.kubernetes.io/azure-load-balancer-internal"       = "false"
        "service.beta.kubernetes.io/azure-load-balancer-resource-group" = azurerm_public_ip.applications[0].resource_group_name
        "service.beta.kubernetes.io/azure-pip-name"                     = azurerm_public_ip.applications[0].name
      }
    }
    spec = {
      type                     = "LoadBalancer"
      externalTrafficPolicy    = "Local"
      loadBalancerSourceRanges = local.workspaces
      selector                 = var.external_application.selector
      ports = [for port in var.external_application.ports : {
        name       = port.name
        protocol   = "TCP"
        port       = port.port
        targetPort = port.target_port
      }]
    }
  }
}

output "external_application_service_manifest" {
  description = "Rendered Service for inspection. Terraform manages it through kubernetes_service_v1.applications_public. Null when disabled."
  value       = local.external_application_service == null ? null : yamlencode(local.external_application_service)
}

output "external_application_public_ip" {
  description = "Application frontend; inbound TCP access is limited by the Service to the workspace /32."
  value       = one(azurerm_public_ip.applications[*].ip_address)
}

output "aks_private_api_url" {
  description = "Private Kubernetes API URL for jumpbox/runner context verification; contains no credentials."
  value       = "https://${azurerm_kubernetes_cluster.this.private_fqdn}:443"
}

variable "deploy_external_load_balancer" {
  description = "Create the Kubernetes Service that provisions the Azure public load balancer. Set false only for the first infrastructure bootstrap, then true from a private runner/jumpbox."
  type        = bool
  default     = true
}

resource "kubernetes_service_v1" "applications_public" {
  count = var.deploy_external_load_balancer && var.external_application != null ? 1 : 0

  metadata {
    name        = local.external_application_service.metadata.name
    namespace   = local.external_application_service.metadata.namespace
    annotations = local.external_application_service.metadata.annotations
  }

  spec {
    type                        = "LoadBalancer"
    external_traffic_policy     = "Local"
    load_balancer_source_ranges = local.workspaces
    selector                    = var.external_application.selector

    dynamic "port" {
      for_each = var.external_application.ports
      content {
        name        = port.value.name
        protocol    = "TCP"
        port        = port.value.port
        target_port = tostring(port.value.target_port)
      }
    }
  }

  wait_for_load_balancer = true

  timeouts {
    create = "20m"
  }

  # Ensure both node pools are ready before AKS reconciles the frontend.
  depends_on = [azurerm_kubernetes_cluster_node_pool.apps]
}
