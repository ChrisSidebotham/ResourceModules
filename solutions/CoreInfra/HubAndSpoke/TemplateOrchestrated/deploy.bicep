targetScope = 'subscription'

@description('Required. Name of the Resource Group.')
param resourceGroupName string

@description('Optional. Tags to be applied on all resources/resource groups in this deployment.')
param tags object

@description('Azure Firewall Name')
param azureFirewallName string

@description('Resource Group location')
param location string

@allowed([
  ''
  'CanNotDelete'
  'ReadOnly'
])
@description('Optional. Specify the type of lock for all resources/resource group defined in this template.')
param lock string

@description('Required. Name of the network security group for the Azure Bastion Host subnet.')
param nsgBastionSubnetName string

@description('Required. NSG security rules for the Azure Bastion Host subnet.')
param bastion_nsg_rules array

@description('Required. Name of the virtual network.')
param vnet_hub string

@description('Required. Name of the virtual network.')
param vnetName2 string = 'vnet-spoke'

@description('Optional. Resource ID of the storage account to be used for diagnostic logs.')
param diagnosticStorageAccountId string

@description('Optional. Resource ID of the Log Analytics workspace to be used for diagnostic logs.')
param workspaceId string

@description('Optional. Authorization ID of the Event Hub Namespace to be used for diagnostic logs.')
param eventHubAuthorizationRuleId string

@description('Optional. Name of the Event Hub to be used for diagnostic logs.')
param eventHubName string
module Resource_Groups '../../../../modules/Microsoft.Resources/resourceGroups/deploy.bicep' = {
  name: '${uniqueString(deployment().name)}-rg'
  params: {
    name: resourceGroupName
    location: location
    tags: tags
  }
}

module NSG_bastion_subnet '../../../../modules/Microsoft.Network/networkSecurityGroups/deploy.bicep' = {
  name: '${uniqueString(deployment().name)}-bastion-subnet'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: nsgBastionSubnetName
    securityRules: bastion_nsg_rules
    tags: tags
    lock: lock
    diagnosticWorkspaceId: workspaceId
    diagnosticStorageAccountId: diagnosticStorageAccountId
    diagnosticEventHubAuthorizationRuleId: eventHubAuthorizationRuleId
    diagnosticEventHubName: eventHubName
  }
  dependsOn: [
    Resource_Groups
  ]
}
module Virtual_Network_Hub '../../../../modules/Microsoft.Network/virtualNetworks/deploy.bicep' = {
  name: '${uniqueString(deployment().name)}-VirtualNetwork_Hub'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: vnet_hub
    addressPrefixes: [
      '192.168.100.0/24'
    ]
    subnets: [
      {
        addressPrefix: '192.168.100.0/26'
        name: 'Subnet-Hub'
        //  networkSecurityGroupId: ''
        //  routeTableId: ''
      }
      {
        addressPrefix: '192.168.100.64/26'
        name: 'AzureBastionSubnet'
        networkSecurityGroupId: NSG_bastion_subnet.outputs.resourceId
        //  routeTableId: ''
      }
      {
        addressPrefix: '192.168.100.128/26'
        name: 'GatewaySubnet'
      }
      {
        addressPrefix: '192.168.100.192/26'
        name: 'AzureFirewallSubnet'
      }
    ]
    tags: tags
    lock: lock
    diagnosticWorkspaceId: workspaceId
    diagnosticStorageAccountId: diagnosticStorageAccountId
    diagnosticEventHubAuthorizationRuleId: eventHubAuthorizationRuleId
    diagnosticEventHubName: eventHubName
  }
}
module Virtual_Network_Spoke '../../../../modules/Microsoft.Network/virtualNetworks/deploy.bicep' = {
  name: 'VirtualNetwork_Spoke'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: vnetName2
    addressPrefixes: [
      '192.168.101.0/24'
    ]
    subnets: [
      {
        addressPrefix: '192.168.101.0/26'
        name: 'DefaultSubnet'
      }
    ]
    tags: tags
    lock: lock
    diagnosticWorkspaceId: workspaceId
    diagnosticStorageAccountId: diagnosticStorageAccountId
    diagnosticEventHubAuthorizationRuleId: eventHubAuthorizationRuleId
    diagnosticEventHubName: eventHubName
  }
  dependsOn: [
    Resource_Groups
  ]
}

module Virtual_Network_Peering_Hub_to_Spoke '../../../../modules/Microsoft.Network/virtualNetworks/virtualNetworkPeerings/deploy.bicep' = {
  name: 'VirtualNetwork_Peering_Hub_to_Spoke'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: 'Peering-Hub-to-Spoke'
    remoteVirtualNetworkId: Virtual_Network_Spoke.outputs.resourceId
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
    localVnetName: vnet_hub
  }
  dependsOn: [
    Resource_Groups
    Virtual_Network_Hub
    Virtual_Network_Spoke
  ]
}

module Virtual_Network_Peering_Spoke_to_Hub '../../../../modules/Microsoft.Network/virtualNetworks/virtualNetworkPeerings/deploy.bicep' = {
  name: 'VirtualNetwork_Peering_Spoke_to_Hub'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: 'Peering-Spoke-to-Hub'
    remoteVirtualNetworkId: Virtual_Network_Hub.outputs.resourceId
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
    localVnetName: vnetName2
  }
  dependsOn: [
    Resource_Groups
    Virtual_Network_Spoke
    Virtual_Network_Hub
  ]
}
module virtualMachines '../../../../modules/Microsoft.Compute/virtualMachines/deploy.bicep' = {
  scope: resourceGroup (resourceGroupName)
  name: '${uniqueString(deployment().name)}-VirtualMachines'
  params: {
    location: location
    // Required parameters
    adminUsername: 'azureadmin'
    imageReference: {
      offer: 'WindowsServer'
      publisher: 'MicrosoftWindowsServer'
      sku: '2019-Datacenter'
      version: 'latest'
    }
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: Virtual_Network_Spoke.outputs.subnetResourceIds[0]
            // subnetId: '/subscriptions/d3696aa4-85af-44e1-a83f-5c1516a22fff/resourceGroups/solutions-ne-rg/providers/Microsoft.Network/virtualNetworks/vnet-spoke/subnets/DefaultSubnet'
          }
        ]
        nicSuffix: '-nic-01'
        enableAcceleratedNetworking: false
      }
    ]
    encryptionAtHost: false
    osDisk: {
      diskSizeGB: '128'
      managedDisk: {
        storageAccountType: 'StandardSSD_LRS'
      }
    }
    osType: 'Windows'
    vmSize: 'Standard_B2s'
    // Non-required parameters
    adminPassword: 'Class123!'
    name: 'spoke-vm-win-01'    
  }
  dependsOn: [
    Virtual_Network_Spoke
  ]
}

// add Azure Firewall module

module Azure_Firewall '../../../../modules/Microsoft.Network/azureFirewalls/deploy.bicep' = {
  name: '${uniqueString(deployment().name)}-AzureFirewall'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: azureFirewallName
    location: location
    firewallPolicyId: ''
    vNetId: Virtual_Network_Hub.outputs.resourceId
    tags: tags
    lock: lock
    diagnosticWorkspaceId: workspaceId
    diagnosticStorageAccountId: diagnosticStorageAccountId
    diagnosticEventHubAuthorizationRuleId: eventHubAuthorizationRuleId
    diagnosticEventHubName: eventHubName
  }
  dependsOn: [
    Resource_Groups
    Virtual_Network_Hub
  ]
}

// deploying a route table for the spoke vnet

module Route_Table_Spoke '../../../../modules/Microsoft.Network/routeTables/deploy.bicep' = {
  name: '${uniqueString(deployment().name)}-RouteTable-Spoke'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: 'VM-to-AFW-udr-x-001'
    lock: 'CanNotDelete'
    routes: [
      {
        name: 'default'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopIpAddress: Azure_Firewall.outputs.privateIp
          nextHopType: 'VirtualAppliance'
        }
      }
    ]
  }
}
