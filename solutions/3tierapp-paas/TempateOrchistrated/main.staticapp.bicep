targetScope = 'subscription'

@description('Required. Name of the Resource Group.')
param resourceGroupName string

@description('Optional. Tags to be applied on all resources/resource groups in this deployment.')
param tags object = {}

@description('Resource Group location')
param location string = 'westeurope'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module staticSite '../../../modules/Microsoft.Web/staticSites/deploy.bicep' = {
  name: '${uniqueString(deployment().name)}-StaticSites'
  scope: resourceGroup
  params: {
    // Required parameters
    name: '<<namePrefix>>-az-wss-x-001'
    // Non-required parameters
    allowConfigFileUpdates: true
    enterpriseGradeCdnStatus: 'Disabled'
    lock: 'CanNotDelete'
    privateEndpoints: [
      {
        privateDnsZoneGroup: {
          privateDNSResourceIds: [
            '/subscriptions/<<subscriptionId>>/resourceGroups/validation-rg/providers/Microsoft.Network/privateDnsZones/privatelink.azurestaticapps.net'
          ]
        }
        service: 'staticSites'
        subnetResourceId: '/subscriptions/<<subscriptionId>>/resourceGroups/validation-rg/providers/Microsoft.Network/virtualNetworks/adp-<<namePrefix>>-az-vnet-x-001/subnets/<<namePrefix>>-az-subnet-x-005-privateEndpoints'
      }
    ]
    roleAssignments: [
      {
        principalIds: [
          '<<deploymentSpId>>'
        ]
        roleDefinitionIdOrName: 'Reader'
      }
    ]
    sku: 'Standard'
    stagingEnvironmentPolicy: 'Enabled'
    systemAssignedIdentity: true
    userAssignedIdentities: {
      '/subscriptions/<<subscriptionId>>/resourcegroups/validation-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/adp-<<namePrefix>>-az-msi-x-001': {}
    }
  }
}

module containerGroups '../../../modules/Microsoft.ContainerInstance/containerGroups/deploy.bicep' = {
  name: '${uniqueString(deployment().name)}-ContainerGroups'
  scope: resourceGroup
  params: {
    // Required parameters
    containername: '<<namePrefix>>-az-aci-x-001'
    image: 'mcr.microsoft.com/azuredocs/aci-helloworld'
    name: '<<namePrefix>>-az-acg-x-001'
    // Non-required parameters
    lock: 'CanNotDelete'
    ports: [
      {
        port: '80'
        protocol: 'Tcp'
      }
      {
        port: '443'
        protocol: 'Tcp'
      }
    ]
    systemAssignedIdentity: true
    userAssignedIdentities: {
      '/subscriptions/<<subscriptionId>>/resourcegroups/validation-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/adp-<<namePrefix>>-az-msi-x-001': {}
    }
  }
}

