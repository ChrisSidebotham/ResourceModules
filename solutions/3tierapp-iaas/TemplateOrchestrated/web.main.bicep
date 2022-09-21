targetScope = 'subscription'

// ========== //
// Parameters //
// ========== //

@description('Optional. Name of the Resource Group.')
param resourceGroupName string = ''

@description('Required. deployment tier.')
param deploymentTier string

@description('Optional. Name of deployment.')
param deploymentPrefix string = ''

@description('Optional. Tags to be applied on all resources/resource groups in this deployment.')
param tags object = {}

@description('Optional. Resource Group location')
param location string = 'eastus2'

@allowed([
  ''
  'CanNotDelete'
  'ReadOnly'
])
@description('Optional. Specify the type of lock for all resources/resource group defined in this template.')
param lock string = ''

@description('Required. Subnet resource ID.')
param subnetId string

@description('Required. Applization security group resource ID.')
param asgId string

@description('Required. VM name prefix.')
param vmNamePrefix string

@description('Required. VM name prefix.')
param availabilitySetNamePrefix string

@description('Optional. Quantity of session hosts to deploy')
param vmCount int = 1

@description('Optional. Existing VM count index')
param vmCountIndex int = 0

@description('Optional. OS source image')
param marketPlaceGalleryImage string = ?????????

@description('Optional. Distribute VMs into availability zones, if set to no availability sets are used. ')
param useAvailabilityZones bool = true

@description('Optional. VM size.')
param vmSize string = 'Standard_D2s_v3'

@description('Optional. OS disk type for session host.')
param vmOsDiskType string = 'Standard_LRS'

@description('Optional. VM local admin user name.')
param vmLocalUserName string = 'localadmin'

@description('Required. VM local admin user password.')
@secure()
param vmLocalUserPassword string

@description('Optional. Key vault name.')
param keyvaultName string = ''

@description('Optional. Name of keyvault that will contain credentials.')
param kvName string = ''

@description('Optional. Name of the application security group for the Azure Bastion Host subnet.')
param asgDbTierSubnetName string = ''

@description('Optional. Resource ID of the storage account to be used for diagnostic logs.')
param diagnosticStorageAccountId string = ''

@description('Optional. Resource ID of the Log Analytics workspace to be used for diagnostic logs.')
param workspaceId string = ''

@description('Optional. Authorization ID of the Event Hub Namespace to be used for diagnostic logs.')
param eventHubAuthorizationRuleId string = ''

@description('Optional. Name of the Event Hub to be used for diagnostic logs.')
param eventHubName string = ''

@description('Do not modify, used to set unique value for resource deployment.')
param time string = utcNow()

// ========== //
// variables  //
// ========== //
var varLocationLowercase = toLower(location)
var uniqueStringSixChar = take('${uniqueString(deploymentPrefix, deploymentTier, time)}', 6)
var varDeploymentTierLowerCase = toLower(deploymentTier)
var varDeploymentPrefixLowerCase = toLower(varDeploymentPrefix)
var varBastionSubnetName = 'AzureBastionSubnet'
var varDeploymentPrefix = !empty(deploymentPrefix) ? deploymentPrefix : '3tier'
var varResourceGroupName = !empty(resourceGroupName) ? resourceGroupName : 'rg-${varDeploymentPrefixLowerCase}-${varLocationLowercase}-${varDeploymentTierLowerCase}'
var varKeyvaultName = !empty(keyvaultName) ? keyvaultName : 'kv-${varDeploymentPrefixLowerCase}-${varDeploymentTierLowerCase}-${varLocationLowercase}-${uniqueStringSixChar}' // max length limit 24 characters
var varAllAvailabilityZones = pickZones('Microsoft.Compute', 'virtualMachines', location, 3)
var varAvailabilitySetNamePrefix = !empty(availabilitySetNamePrefix) ? availabilitySetNamePrefix : 'avail-${varDeploymentPrefixLowerCase}-${varDeploymentTierLowerCase}-${varLocationLowercase}'

// ========== //
// Deployments//
// ========== //

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: varResourceGroupName
  location: varLocationLowercase
  tags: !empty(tags) ? tags : {}
}

module keyVault '../../../modules/Microsoft.KeyVault/vaults/deploy.bicep' = {
  scope: resourceGroup
  name: '${varDeploymentTierLowerCase}-KeyVault-${time}'
  params: {
    name: varKeyvaultName
    location: location
    enableRbacAuthorization: false
    enablePurgeProtection: true
    softDeleteRetentionInDays: 7
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: []
      ipRules: []
    }
    secrets: {
      secureList: [
        {
          name: 'VmLocalUserPassword'
          value: vmLocalUserPassword
          contentType: 'VM local user credentials'
        }
        {
          name: 'VmLocalUserName'
          value: vmLocalUserName
          contentType: 'VM local user credentials'
        }
      ]
    }
    tags: !empty(tags) ? tags : {}
  }
}

resource getkeyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' existing = {
  name: keyVault.outputs.name
  scope: resourceGroup
}

module availabilitySet '../../../modules/Microsoft.Compute/availabilitySets/deploy.bicep' = [for i in range(1, availabilitySetCount): {
  name: 'AVD-AvSet--${i}-${time}'
  scope: resourceGroup
  params: {
    name: '${vmNamePrefix}-${padLeft(i, 3, '0')}'
    location: avdSessionHostLocation
    availabilitySetFaultDomain: avdAsFaultDomainCount
    availabilitySetUpdateDomain: avdAsUpdateDomainCount
    tags: avdTags
  }
}]

module virtualMachines '../../../modules/Microsoft.Compute/virtualMachines/deploy.bicep' = [for i in range(1, vmCount): {
  scope: resourceGroup
  name: 'VM-${padLeft((i + vmCountIndex), 3, '0')}-${time}'
  params: {
    name: '${vmNamePrefix}-${padLeft((i + vmCountIndex), 3, '0')}'
    location: location
    availabilityZone: useAvailabilityZones ? take(skip(varAllAvailabilityZones, i % length(varAllAvailabilityZones)), 1) : []
    availabilitySetName: !useAvailabilityZones ? '${avdAvailabilitySetNamePrefix}-${padLeft(((1 + (i + vmCountIndex) / maxAvailabilitySetMembersCount)), 3, '0')}' : ''
    osType: 'Windows'
    licenseType: 'Windows_Client'
    vmSize: vmSize
    imageReference: marketPlaceGalleryImage
    osDisk: {
      createOption: 'fromImage'
      deleteOption: 'Delete'
      diskSizeGB: 128
      managedDisk: {
        storageAccountType: vmOsDiskType
      }
    }
    adminUsername: vmLocalUserName
    adminPassword: getkeyVault.getSecret('avdVmLocalUserPassword')
    nicConfigurations: [
      {
        nicSuffix: 'nic-001-'
        deleteOption: 'Delete'
        asgId: asgId
        enableAcceleratedNetworking: false
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetId: subnetId
          }
        ]
      }
    ]
    tags: !empty(tags) ? tags : {}
  }
  dependsOn: []
}]

// ========== //
// Outputs    //
// ========== //
