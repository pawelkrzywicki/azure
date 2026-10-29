# Backend deployment

This configuration prepares `GeoWeb.neftexaz.com` on TCP 443 through an AKS-managed public Standard Load Balancer. Only the workspace address `63.33.154.114/32` is allowed by its Service. AKS API access and PostgreSQL remain private. No application or ingress controller is installed.

## Changes

- `public_dns.tf` creates the public Azure DNS zone `neftexaz.com`, a `geoweb` A record pointing to the retained static frontend IP, and outputs Azure's authoritative name servers. DNS is case-insensitive.
- `external_load_balancer.tf` creates a Standard static public IP in the AKS node resource group and a Terraform-managed Kubernetes `LoadBalancer` Service. AKS creates the Azure load balancer, frontend/rules/probe, NSG rules and node backend membership. Terraform waits for the Service to receive its load-balancer address. The Service can exist before any ingress pods exist.
- `externalTrafficPolicy: Local` preserves the client source IP. The existing workspace `/32` Internet route supplies the public return path; all other egress continues through the firewall.
- AKS uses the existing `msi-aks-control-plane` identity. Its existing network permissions must be verified. No Terraform role assignments or custom roles are added.
- Automatic Azure resource-provider registration is disabled in both providers. Registration stays with the platform team.
- The existing internal load balancer module now references the workload VNet containing its subnet, instead of the separate SVRG VNet. It remains separate from the public AKS frontend.
- PostgreSQL provisioning waits for its subnet routing association. Its existing `10.86.80.0/22` allowlist already covers both AKS node subnets (`10.86.82.0/24` and `10.86.83.0/24`), so no extra database network rules are added.

There are no new Terraform modules. The Kubernetes provider is added to manage the actual load-balancer Service. Do not manually attach AKS node NICs to a separately managed Azure load balancer: AKS must reconcile the backend as nodes scale or upgrade.

## Existing access required

Use the existing provisioner environment, its account metadata (`../../account.json` or `/etc/megazord/account.json`), managed identity, remote state access and authenticated private GitLab module access. Install Terraform and `kubelogin` there. `kubectl` is useful for verification. The provider defaults to managed-identity login; select an existing user-assigned identity using `kubernetes_managed_identity_client_id` if necessary. Interactive Kubernetes access can use `kubernetes_login_method = "azurecli"`; AzureRM and the backend still use their existing MSI configuration.

The provisioner needs existing rights to create the public DNS resources and public IP in the AKS node resource group. Its Kubernetes identity needs permission to manage the Service in the configured namespace. Azure resource Contributor access alone does not authorize Kubernetes operations. This change does not grant those permissions.

Verify the existing control-plane identity can use the workload VNet/subnets and the custom route table, and that the provisioner can attach it. Changing an existing cluster identity can take hours to propagate; inspect the real plan and retain the old identity's permissions during the transition.

## Deploy infrastructure, then the load balancer

Copy `external-application.tfvars.example` to `external-application.tfvars`. Set the namespace, pod labels and backend port expected by your ingress deployment. The defaults prepare `applications-public` in the existing `default` namespace, forwarding TCP 443 to port 443. If using another namespace, create it through your usual bootstrap first. Your later ingress chart must reuse this Service, or be configured to select its pods, instead of creating another public frontend.

For an existing, reachable cluster, use the normal full Terraform plan/apply with this configuration. For a brand-new cluster, initialize and create the Azure resources first, with Kubernetes resource creation disabled:

```sh
terraform init
terraform plan -var-file=external-application.tfvars -var=deploy_external_load_balancer=false -out=bootstrap.tfplan
terraform apply bootstrap.tfplan
```

Then run the second full plan/apply from the private jumpbox/provisioner/runner, with `deploy_external_load_balancer = true` in the variables file:

```sh
terraform plan -var-file=external-application.tfvars -out=backend.tfplan
terraform apply backend.tfplan
```

The second apply creates the Kubernetes Service and waits for AKS to provision the public load balancer. Do not use a targeted apply to bypass failures elsewhere in the configuration. Keep the flag enabled after bootstrap; disabling it later removes the Service and its managed frontend configuration. Retain the selected namespace/name in application pipelines so Terraform and Helm do not compete for ownership of the Service.

The load balancer has no healthy application endpoints until matching ingress pods are deployed. This is expected. Host routing and TLS certificates for `GeoWeb.neftexaz.com` belong to that later ingress deployment: Azure Load Balancer forwards TCP and does not terminate TLS or select applications by hostname.

## Public DNS delegation

After applying, retrieve:

```sh
terraform output public_dns_name_servers
terraform output -raw external_application_hostname
terraform output -raw external_application_public_ip
```

Delegate `neftexaz.com` to the returned Azure name servers at its registrar. Creating a DNS zone does not change registrar delegation. If the domain already has public records elsewhere, preserve those records in Azure before switching its authoritative name servers. This Terraform change does not modify the registrar.

## Jumpbox access to the private AKS API

The jumpbox and AKS nodes use the workload VNet. The AKS System private DNS zone is linked to that VNet automatically. With Azure-provided DNS, the jumpbox should resolve the API's private FQDN. With custom VNet DNS, configure forwarding through an Azure resolver that sees the AKS and PostgreSQL private zones.

For an interactive jumpbox sign-in to the target subscription:

```sh
az aks get-credentials --subscription b15d5e4e-f7f3-4ae3-bb8a-54f9930ac045 --resource-group D-AZ-LMK-NFX-DEV-01-WLRG --name D-AZ-LMK-NFX-DEV-01-aks
kubelogin convert-kubeconfig -l azurecli
kubectl get nodes
kubectl -n default describe service applications-public
```

Use `-l msi` and the existing runner identity for managed-identity access. Public GitLab runners cannot reach the private API merely by adding their public IP to an allowlist; run deployment jobs on a privately connected runner or through the jumpbox.

The private jumpbox module source requires GitLab credentials and could not be inspected here. Verify its `deny_other_inbound` rules apply to the jumpbox NIC, or explicitly allow the necessary traffic if attached to the shared AKS subnet. A subnet-wide deny can block node traffic and load-balancer probes. Live checks must include private TCP 443 to the API, Azure Load Balancer health probes, and node-to-node traffic.

## AKS access to PostgreSQL and delivery services

The PostgreSQL private DNS zone is linked to the workload VNet. Azure CNI Overlay sends traffic outside the cluster using node IPs, which are already covered by the database allowlist. Verify private DNS resolution and TCP 5432 from pods on each node subnet. Network reachability does not grant database login; applications still need PostgreSQL credentials/Entra users and database privileges.

Inspect the existing PostgreSQL module's actual NSG rules after authenticated module initialization. Check effective NSGs/routes and any network policies rather than opening public database access.

JFrog pulls require outbound DNS/firewall access from nodes and an application-namespace image pull secret when authentication is required. A kubelet Azure identity does not authenticate to JFrog. GitLab deployments need private API connectivity and existing Entra Kubernetes authorization. Azure-required AKS outbound traffic and your actual GitLab/JFrog hosts must be permitted by the existing firewall; its configuration is outside this repository.

Blob storage remains commented out, as in the original code; it is not enabled by this backend change.

## Verification and outstanding live checks

Native Azure/Kubernetes resources were validated with AzureRM 4.81.0 and Kubernetes 2.38.0 in an isolated fixture. Offline mocked checks cover workspace-only public ingress, private API/firewall egress, GeoWeb DNS targeting the static IP, disabled ingress, custom backend settings, invalid-port rejection, and Azure-only bootstrap.

A full root initialization/plan and live verification remain pending: the target subscription is absent from the current Azure sign-in, the private GitLab module sources require authentication, and the provisioner account metadata is missing here. No cloud resources have been changed. Offline validation does not establish that the environment is ready for deployments.

## References

- [AKS static public IP and node resource group permissions](https://learn.microsoft.com/en-us/azure/aks/static-ip)
- [Public load balancer source restrictions and client IP preservation](https://learn.microsoft.com/en-us/azure/aks/configure-load-balancer-standard)
- [Azure DNS delegation](https://learn.microsoft.com/en-us/azure/dns/dns-delegate-domain-azure-dns)
- [Private AKS DNS and deployment connectivity](https://learn.microsoft.com/en-us/azure/aks/private-clusters)
- [AKS identity permissions](https://learn.microsoft.com/en-us/azure/aks/managed-identity-overview)
- [kubelogin managed identity authentication](https://azure.github.io/kubelogin/concepts/login-modes/msi.html)
