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

@description('VM name prefix.')
param vmNamePrefix string

@description('Optional. Quantity of session hosts to deploy')
param vmCount int = 1

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

// ========== //
// Deployment //
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

module avdSessionHosts '../../../carml/1.2.0/Microsoft.Compute/virtualMachines/deploy.bicep' = [for i in range(1, avdSessionHostsCount): {
  scope: resourceGroup('${avdWorkloadSubsId}', '${avdComputeObjectsRgName}')
  name: 'AVD-Session-Host-${padLeft((i + avdSessionHostCountIndex), 3, '0')}-${time}'
  params: {
    name: '${avdSessionHostNamePrefix}-${padLeft((i + avdSessionHostCountIndex), 3, '0')}'
    location: avdSessionHostLocation
    timeZone: avdTimeZone
    userAssignedIdentities: createAvdFslogixDeployment ? {
      '${fslogixManagedIdentityResourceId}': {}
    } : {}
    availabilityZone: avdUseAvailabilityZones ? take(skip(varAllAvailabilityZones, i % length(varAllAvailabilityZones)), 1) : []
    encryptionAtHost: encryptionAtHost
    availabilitySetName: !avdUseAvailabilityZones ? '${avdAvailabilitySetNamePrefix}-${padLeft(((1 + (i + avdSessionHostCountIndex) / maxAvailabilitySetMembersCount)), 3, '0')}' : ''
    osType: 'Windows'
    licenseType: 'Windows_Client'
    vmSize: avdSessionHostsSize
    imageReference: useSharedImage ? json('{\'id\': \'${avdImageTemplateDefinitionId}\'}') : marketPlaceGalleryWindows
    osDisk: {
      createOption: 'fromImage'
      deleteOption: 'Delete'
      diskSizeGB: 128
      managedDisk: {
        storageAccountType: avdSessionHostDiskType
      }
    }
    adminUsername: avdVmLocalUserName
    adminPassword: avdWrklKeyVaultget.getSecret('avdVmLocalUserPassword')
    nicConfigurations: [
      {
        nicSuffix: 'nic-001-'
        deleteOption: 'Delete'
        asgId: !empty(avdApplicationSecurityGroupResourceId) ? avdApplicationSecurityGroupResourceId : null
        enableAcceleratedNetworking: false
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetId: avdSubnetId
          }
        ]
      }
    ]
    // Join domain.
    allowExtensionOperations: true
    extensionDomainJoinPassword: avdWrklKeyVaultget.getSecret('avdDomainJoinUserPassword')
    extensionDomainJoinConfig: {
      enabled: true
      settings: {
        name: avdIdentityDomainName
        ouPath: !empty(sessionHostOuPath) ? sessionHostOuPath : null
        user: avdDomainJoinUserName
        restart: 'true'
        options: '3'
      }
    }
    // Enable and Configure Microsoft Malware.
    extensionAntiMalwareConfig: {
      enabled: true
      settings: {
        AntimalwareEnabled: true
        RealtimeProtectionEnabled: 'true'
        ScheduledScanSettings: {
          isEnabled: 'true'
          day: '7' // Day of the week for scheduled scan (1-Sunday, 2-Monday, ..., 7-Saturday)
          time: '120' // When to perform the scheduled scan, measured in minutes from midnight (0-1440). For example: 0 = 12AM, 60 = 1AM, 120 = 2AM.
          scanType: 'Quick' //Indicates whether scheduled scan setting type is set to Quick or Full (default is Quick)
        }
        Exclusions: createAvdFslogixDeployment ? {
          Extensions: '*.vhd;*.vhdx'
          Paths: '"%ProgramFiles%\\FSLogix\\Apps\\frxdrv.sys;%ProgramFiles%\\FSLogix\\Apps\\frxccd.sys;%ProgramFiles%\\FSLogix\\Apps\\frxdrvvt.sys;%TEMP%\\*.VHD;%TEMP%\\*.VHDX;%Windir%\\TEMP\\*.VHD;%Windir%\\TEMP\\*.VHDX;\\\\server\\share\\*\\*.VHD;\\\\server\\share\\*\\*.VHDX'
          Processes: '%ProgramFiles%\\FSLogix\\Apps\\frxccd.exe;%ProgramFiles%\\FSLogix\\Apps\\frxccds.exe;%ProgramFiles%\\FSLogix\\Apps\\frxsvc.exe'
        } : {}
      }
    }
    tags: avdTags
  }
  dependsOn: []
}]

module virtualNetwork '../../../../../modules/Microsoft.Network/virtualNetworks/deploy.bicep' = {
  scope: resourceGroup
  name: 'Deploy-vNet-${time}'
  params: {
    name: varVnetName
    addressPrefixes: [
      vnetAddressPrefix
    ]
    subnets: [
      {
        addressPrefix: vnetBastionSubnetAddressPrefix
        name: varBastionSubnetName
        networkSecurityGroupId: nsgBastionSubnet.outputs.resourceId
        //  routeTableId: ''
      }
      {
        addressPrefix: vnetWebSubnetAddressPrefix
        name: varWebTierSubnetName
        networkSecurityGroupId: nsgWebSubnet.outputs.resourceId
        routeTableId: udrWebSubnet.outputs.resourceId
      }
      {
        addressPrefix: vnetAppSubnetAddressPrefix
        name: varAppTierSubnetName
        networkSecurityGroupId: nsgAppSubnet.outputs.resourceId
        routeTableId: udrAppSubnet.outputs.resourceId
      }
      {
        addressPrefix: vnetDbSubnetAddressPrefix
        name: varDbTierSubnetName
        networkSecurityGroupId: nsgDbSubnet.outputs.resourceId
        routeTableId: udrDbSubnet.outputs.resourceId
      }
    ]
    tags: !empty(tags) ? tags : {}
    lock: !empty(lock) ? lock : ''
    diagnosticWorkspaceId: !empty(workspaceId) ? workspaceId : ''
    diagnosticStorageAccountId: !empty(diagnosticStorageAccountId) ? diagnosticStorageAccountId : ''
    diagnosticEventHubAuthorizationRuleId: !empty(eventHubAuthorizationRuleId) ? eventHubAuthorizationRuleId : ''
    diagnosticEventHubName: !empty(eventHubName) ? eventHubName : ''
  }
  dependsOn: [
    asgWebSubnet
    asgAppSubnet
    asgDbSubnet
  ]

}

output virtualNetworkId string = virtualNetwork.outputs.resourceId
output bastionSubnetId string = virtualNetwork.outputs.subnetResourceIds[0]
output webSubnetId string = virtualNetwork.outputs.subnetResourceIds[1]
output appSubnetId string = virtualNetwork.outputs.subnetResourceIds[2]
output dbSubnetId string = virtualNetwork.outputs.subnetResourceIds[2]
output asgWebId string = asgWebSubnet.outputs.resourceId
output asgAppId string = asgWebSubnet.outputs.resourceId
output asgDbId string = asgWebSubnet.outputs.resourceId
