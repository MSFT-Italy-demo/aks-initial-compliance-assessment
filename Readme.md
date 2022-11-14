# Checks implemented

## Security:
- Cluster must be private
- Public FQDN should be disabled
- Defender profile should be enabled
- Policy add-on should be enabled
- KMS should be enabled
- RBAC should be enabled
- AAD authentication should be enabled

## Observability:
- Container Insights should be enabled
  
## Resiliency:
- Availability zones should be used
- Uptime SLA should be enabled
- Control plane and node pools version should not be outdated
- Cluster should have at least one system and one user node pool

## Suggegest checks to add:
- NSG should be linked to node pools subnets
- External IP addresses should not be associated with AKS load balancer 
- Network policies (Azure or Calico) should be enabled
- Obsolete features should not be used (e.g. PodIdentity)

# Getting started

## Prerequisites
- Windows PowerShell 5+ / PowerShell Core 7
- Aure CLI 

## Permissions
In order to complete the assessment, the user must have at least Reader permission/role over the Azure Kubernetes Service resources

## Execution
Login to the Azure CLI and execute the script

```powershell
az login # -t [tenant id] (optional)

.\ClusterAssessment.ps1 #-Path "C:\MyPath" -csvDelimiter "," (optional) 

```

## Output 
An output folder named "AKSClusterAssessment_YYYY-MM-DD_hh-mm-ss" will be created for each assessment execution. The folder will contain the following files:

- Assessment_Result_YYYY-MM-DD_hh-mm-ss - CSV Results of the assessment
- Assessment_Log_YYYY-MM-DD_hh-mm-ss - Transcript of the PowerShell execution
