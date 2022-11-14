param (
    [Parameter(Mandatory = $false)][string]$Path = $PSScriptRoot,
    [Parameter(Mandatory = $false)][string]$csvDelimiter = ";"
)

$okMessage = "OK";
$koMessage = "KO";

class AKSClusterResult {
    [string]$Compliant
    [string]$Subscription
    [string]$ResourceGroup
    [string]$ClusterName
    [string]$ProvisioningState
    [string]$Region
    [string]$ManagedResourceGroup
    [string]$PrivateCluster
    [string]$PrivateClusterPublicFqdn
    [string]$IsKubernetesVersionSupported
    [string]$ContainerInsights
    [string]$UserAssignedIdentity
    [string]$MicrosoftDefender
    [string]$RBAC
    [string]$AzureADIntegration
    [string]$KMSConfigured
    [string]$AzurePolicy
    [string]$SystemAndUserNodePool
    [string]$AvailabilityZones
    [string]$UptimeSlaConfiguration
    [String]$ObsoletePodIdentity
    [string]$ErrorMessage
}

function Start-AKSClusterAssessment {
    $subscriptions = az account subscription list -o json | ConvertFrom-Json

    foreach ($currentSubscription in $subscriptions) {
          
        Write-Host "***** Assessing the subscription $($currentSubscription.displayName) ($($currentSubscription.id)..." -ForegroundColor Green
        az account set -s $currentSubscription.SubscriptionId

        $aksClusters = az aks list | ConvertFrom-Json
        foreach ($currentAKSCluster in $aksClusters) {
            Write-Host "**** Assessing the AKS Cluster $($currentAKSCluster.Name)..." -ForegroundColor Blue

            $aksResult = [AKSClusterResult]::new()

            try {
                $aksResult.Subscription = $currentSubscription.SubscriptionId
                $aksResult.ResourceGroup = $currentAKSCluster.resourceGroup
                $aksResult.ClusterName = $currentAKSCluster.Name
                $aksResult.ProvisioningState = $currentAKSCluster.provisioningState
                $aksResult.Region = $currentAKSCluster.location
                $aksResult.ManagedResourceGroup = $currentAKSCluster.nodeResourceGroup
                
                #Private cluster should be enabled and public FQDN disabled
                $aksResult.PrivateCluster = $(if ([string]::IsNullOrEmpty($currentAKSCluster.apiServerAccessProfile.enablePrivateCluster)) { $koMessage } else {$okMessage})
                $aksResult.PrivateClusterPublicFqdn =  $(if ([string]::IsNullOrEmpty($currentAKSCluster.privateFqdn))  { $koMessage } else {$okMessage})

                #RBAC should be enabled and azure ad used for authentication, cluster identity should be managed identity 
                $aksResult.RBAC = $(if ($currentAKSCluster.enableRbac) {$okMessage} else {$koMessage})
                $aksResult.AzureADIntegration = $(if ([string]::IsNullOrEmpty($currentAKSCluster.aadProfile)) { $koMessage} else {$okMessage})
                $aksResult.UserAssignedIdentity = $(if ($currentAKSCluster.identity.type -eq "UserAssigned" -or $currentAKSCluster.identity.type -eq "SystemAssigned") {   $okMessage } else {$koMessage})

                #Observability, Compliance and security features
                $aksResult.ContainerInsights = $(if ($currentAKSCluster.addonProfiles.omsagent.enabled) {$okMessage} else {$koMessage}) 
                $aksResult.MicrosoftDefender = $(if([string]::IsNullOrEmpty($currentAKSCluster.securityProfile.defender)) { $koMessage } else {$okMessage})
                $aksResult.KMSConfigured = $(if ([string]::IsNullOrEmpty($currentAKSCluster.securityProfile.azureKeyVaultKms)){$koMessage}else {$okMessage})
                $aksResult.AzurePolicy = $(if ($currentAKSCluster.addonProfiles.azurepolicy.Enabled) {$okMessage}else {$koMessage})

                #High availability (control plane, node pools, uptime sla)                
                $aksResult.AvailabilityZones = CheckAvailabilityZones($currentAKSCluster.agentPoolProfiles)
                $aksResult.SystemAndUserNodePool = CheckNodepoolsSpecification($currentAKSCluster.agentPoolProfiles)
                $aksResult.UptimeSlaConfiguration = $(if ( $currentAKSCluster.sku.tier -eq "Free") {$koMessage} else {$okMessage})
                                
                #Cluster and nodepool version should not lag x versions behind the default
                $aksResult.IsKubernetesVersionSupported = CheckKubernetesControlPlaneVersion($currentAKSCluster)

                #Obsolete features
                #-> PodIdentity

                #Other checks
                
                $aksResult.Compliant = Get-Compliancy $aksResult
            }
            catch {
                $aksResult.ErrorMessage = $_.Exception.Message
            }
            Export-AKSClusterResult $aksResult
        }
    }
}


function CheckNodepoolsSpecification {    
    Param(
        [Parameter(Mandatory = $true)]$agentPoolProfiles
    )   

    foreach ($agentProfile in $agentPoolProfiles) {
        if ($agentProfile.Mode -eq "User") {
            return $okMessage
        }
    }
    return $koMessage;
}

function CheckAvailabilityZones {
    Param(
        [Parameter(Mandatory = $true)]$agentPoolProfiles
    )   
    $countNodepool = 0;
    $countNodePoolWithAZ = 0;
    foreach ($agentProfile in $agentPoolProfiles) {
        $countNodepool++;
        if (($agentProfile.availabilityZones.Count -ge 2) -and ($agentProfile.count -ge 2)) {
            $countNodePoolWithAZ++ 
        }
    }
    if ($countNodepool -gt $countNodePoolWithAZ) {
        return $koMessage
    }
    else {
        return $okMessage
    }
}

function CheckKubernetesControlPlaneVersion {
    Param(
        [Parameter(Mandatory = $true)]$cluster
    )
    
    $aksVersions = $(az aks get-versions --location westeurope --output json | ConvertFrom-Json).orchestrators.orchestratorVersion  
    $result = $okMessage

    if($cluster.kubernetesVersion -notin $aksVersions){
        $result = $koMessage 
    }

    foreach($pool in $cluster.agentPoolProfiles){
        if($pool.orchestratorVersion -notin $aksVersions){
            $result = $koMessage
        }
    }

    return $result
}

function Get-Compliancy {
    Param(
        [Parameter(Mandatory = $true)]$clusterResult
    )   
    if ($clusterResult.IsKubernetesVersionSupported -ne "" -or
        $clusterResult.PrivateCluster -eq $koMessage -or
        $clusterResult.ContainerInsights -eq $koMessage -or 
        $clusterResult.UserAssignedIdentity -eq $koMessage -or
        $clusterResult.MicrosoftDefender -eq $koMessage -or
        $clusterResult.EnableRBAC -eq $koMessage -or
        $clusterResult.KMSConfigured -eq $koMessage -or
        $clusterResult.SystemAndUserNodePool -eq $koMessage -or
        $clusterResult.EnableAzurePolicy -eq $koMessage -or
        $clusterResult.AzureADIntegration -eq $koMessage -or
        $clusterResult.PrivateCluster -eq $koMessage -or
        $clusterResult.AvailabilityZones -eq $koMessage -or
        $clusterResult.UptimeSlaConfiguration -eq $koMessage) {
        return $koMessage;
    }
   
    return  $okMessage;
}

function Export-AKSClusterResult {
    Param(
        [Parameter(Mandatory = $true)]$clusterResult
    )   
    $clusterResult | Export-Csv $exportASKClusterAssessment -NoTypeInformation -Append -Delimiter $csvDelimiter   
}

#=========================== Main code
$today = [DateTime]::Now.ToString("yyyy-MM-dd_hh-mm-ss")


Write-Host "******** Welcome to the Microsoft Azure Kubernetes Cluster assessment" -ForegroundColor Green


if ($Path.Trim() -eq '' -or -not(Test-Path -Path $Path)) {
    Write-Host "- Please insert the Path where to save the Assessment result" -ForegroundColor Blue
    $Path = $PSScriptRoot
    Write-Host "- Default Path: $Path" -ForegroundColor Blue
}

Start-Transcript -Path "$Path\AKSClusterAssessment_$today\Assessment_Log_$today.txt"
$exportASKClusterAssessment = "$Path\AKSClusterAssessment_$today\Assessment_Result_$today.csv"

Start-AKSClusterAssessment

Stop-Transcript