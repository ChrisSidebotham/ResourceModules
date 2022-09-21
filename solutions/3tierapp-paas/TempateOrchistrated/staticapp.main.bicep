targetScope = 'subscription'

///////////////////////////////
//   User-defined Deployment Properties   //
///////////////////////////////

@description('Required. Name of the Resource Group.')
param resourceGroupName string

@description('Optional. Tags to be applied on all resources/resource groups in this deployment.')
param tags object

@description('Resource Group location')
param location string = ''

@description('Required. Name of the Static Site.')
param staticSiteName string

@description('Required. Name of the Static Site.')
param allowConfigFileUpdates bool

@description('Required. Name of the Static Site.')
param enterpriseGradeCdnStatus string

///////////////////////////////
//   Default Deployment Properties   //
///////////////////////////////
@description('Static Siteparams')
param rgParam object

@description('Static Site params')
param staticSiteParam object

// @description('Container Group location')
// param containerGroupParam object

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : rgParam.name
  location: !empty(location) ? location : rgParam.location
  tags: !empty(tags) ? tags : rgParam.tags
}

module staticSites '../../../modules/Microsoft.Web/staticSites/deploy.bicep' = {
  name: '${uniqueString(deployment().name)}-StaticSites'
  scope: resourceGroup
  params: {
    // Required parameters
    name: !empty(staticSiteName) ? staticSiteName : staticSiteParam.name
    // Non-required parameters
    allowConfigFileUpdates: !empty(allowConfigFileUpdates) ? allowConfigFileUpdates : staticSiteParam.allowConfigFileUpdates
    enterpriseGradeCdnStatus: !empty(enterpriseGradeCdnStatus) ? enterpriseGradeCdnStatus : staticSiteParam.enterpriseGradeCdnStatus
    lock: !empty(lock) ? lock : staticSiteParam.lock
    privateEndpoints: [
      {
        privateDnsZoneGroup: {
          privateDNSResourceIds: [
            !empty(privateDNSResourceIds) ? privateDNSResourceIds : staticSiteParam.privateDNSResourceIds
          ]
        }
        service: !empty(service) ? service : staticSiteParam.service
        subnetResourceId: !empty(subnetResourceId) ? subnetResourceId : staticSiteParam.subnetResourceId
      }
    ]
    roleAssignments: [
      {
        principalIds: [
          !empty(principalIds) ? principalIds : staticSiteParam.principalIds
        ]
        roleDefinitionIdOrName: !empty(roleDefinitionIdOrName) ? roleDefinitionIdOrName : staticSiteParam.roleDefinitionIdOrName
      }
    ]
    sku: !empty(sku) ? sku : staticSiteParam.sku
    stagingEnvironmentPolicy: !empty(stagingEnvironmentPolicy) ? stagingEnvironmentPolicy : staticSiteParam.stagingEnvironmentPolicy
    systemAssignedIdentity: !empty(systemAssignedIdentity) ? systemAssignedIdentity : staticSiteParam.systemAssignedIdentity
    userAssignedIdentities: {
      '/subscriptions/<<subscriptionId>>/resourcegroups/validation-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/adp-<<namePrefix>>-az-msi-x-001': {}
    }
  }
}

// module containerGroups '../../../modules/Microsoft.ContainerInstance/containerGroups/deploy.bicep' = {
//   name: '${uniqueString(deployment().name)}-ContainerGroups'
//   scope: resourceGroup
//   params: {
//     // Required parameters
//     containername: '<<namePrefix>>-az-aci-x-001'
//     image: 'mcr.microsoft.com/azuredocs/aci-helloworld'
//     name: '<<namePrefix>>-az-acg-x-001'
//     // Non-required parameters
//     lock: 'CanNotDelete'
//     ports: [
//       {
//         port: '80'
//         protocol: 'Tcp'
//       }
//       {
//         port: '443'
//         protocol: 'Tcp'
//       }
//     ]
//     systemAssignedIdentity: true
//     userAssignedIdentities: {
//       '/subscriptions/<<subscriptionId>>/resourcegroups/validation-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/adp-<<namePrefix>>-az-msi-x-001': {}
//     }
//   }
// }
