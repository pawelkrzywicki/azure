# Public application DNS is separate from AKS and PostgreSQL private DNS.
variable "public_dns_zone_name" {
  description = "Public Azure DNS zone. Null uses the domain already defined in common.tf."
  type        = string
  default     = null
}

variable "public_dns_record_name" {
  description = "Public application hostname within the zone (DNS is case-insensitive)."
  type        = string
  default     = "geoweb"
}

resource "azurerm_dns_zone" "applications" {
  name                = coalesce(var.public_dns_zone_name, local.domain_name)
  resource_group_name = data.azurerm_resource_group.workload.name
  tags                = local.tags
}

resource "azurerm_dns_a_record" "applications" {
  count = var.external_application == null ? 0 : 1

  name                = var.public_dns_record_name
  zone_name           = azurerm_dns_zone.applications.name
  resource_group_name = azurerm_dns_zone.applications.resource_group_name
  ttl                 = 300
  records             = [azurerm_public_ip.applications[0].ip_address]
  tags                = local.tags
}

output "public_dns_name_servers" {
  description = "Delegate neftexaz.com (or the configured zone) to these name servers at its registrar. Creating the zone does not change registrar delegation."
  value       = azurerm_dns_zone.applications.name_servers
}

output "external_application_hostname" {
  description = "Public application hostname. DNS resolves after delegation; HTTPS requires ingress pods and their TLS certificate."
  value       = one(azurerm_dns_a_record.applications[*].fqdn)
}
