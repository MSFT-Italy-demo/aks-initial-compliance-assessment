Checks implemented
Security:
- Cluster must be private
- Public FQDN should be disabled
- Defender profile should be enabled
- Policy add-on should be enabled
- KMS should be enabled
- RBAC should be enabled
- AAD authentication should be enabled

Observability:
- Container Insights should be enabled
  
Resiliency:
- Availability zones should be used
- Uptime SLA should be enabled
- Control plane and node pools version should not be outdated
- Cluster should have at least one system and one user node pool

Suggegest checks to add:
- NSG should be linked to node pools subnets
- External IP addresses should not be associated with AKS load balancer 
- Network policies (Azure or Calico) should be enabled
- Obsolete features should not be used (e.g. PodIdentity)