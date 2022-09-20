targetScope = 'subscription'

@description('Required. Name of the Resource Group.')
param resourceGroupName string

@description('Optional. Tags to be applied on all resources/resource groups in this deployment.')
param tags object = {}

@description('Resource Group location')
param location string = 'westeurope'

@allowed([
  ''
  'CanNotDelete'
  'ReadOnly'
])
@description('Optional. Specify the type of lock for all resources/resource group defined in this template.')
param lock string = ''

@description('Required. Name of the network security group for the Azure Bastion Host subnet.')
param nsgBastionSubnetName string = '123'

@description('Required. Name of the virtual network.')
param vnetName1 string = 'vnet-hub'

@description('Required. Name of the virtual network.')
param vnetName2 string = 'vnet-spoke'

@description('Optional. Resource ID of the storage account to be used for diagnostic logs.')
param diagnosticStorageAccountId string = ''

@description('Optional. Resource ID of the Log Analytics workspace to be used for diagnostic logs.')
param workspaceId string = ''

@description('Optional. Authorization ID of the Event Hub Namespace to be used for diagnostic logs.')
param eventHubAuthorizationRuleId string = ''

@description('Optional. Name of the Event Hub to be used for diagnostic logs.')
param eventHubName string = ''

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module NSG_bastion_subnet '../../../modules/Microsoft.Network/networkSecurityGroups/deploy.bicep' = {
  name: 'NSG_Bastion_subnet'
  scope: resourceGroup
  params: {
    name: nsgBastionSubnetName
    securityRules: [
      {
        name: 'AllowhttpsInbound'
        properties: {
          description: 'Allow inbound TCP 443 connections from the Internet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowGatewayManagerInbound'
        properties: {
          description: 'Allow inbound TCP 443 connections from the Gateway Manager'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAzureLoadBalancerInbound'
        properties: {
          description: 'Allow inbound TCP 443 connections from the Azure Load Balancer'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 140
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowBastionHostCommunication'
        properties: {
          description: 'Allow inbound 8080 and 5701 connections from the Virtual Network'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 150
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowSshRdpOutbound'
        properties: {
          description: 'Allow outbound SSH and RDP connections to Virtual Network'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: [
            '22'
            '3389'
          ]
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowAzureCloudOutbound'
        properties: {
          description: 'Allow outbound 443 connections to Azure cloud'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowBastionCommunication'
        properties: {
          description: 'Allow outbound 8080 and 5701 connections to Virtual Network'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 120
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowGetSessionInformation'
        properties: {
          description: 'Allow outbound 80 connections to Internet'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 130
          direction: 'Outbound'
        }
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

module VirtualNetwork '../../../modules/Microsoft.Network/virtualNetworks/deploy.bicep' = {
  name: 'VirtualNetwork_Hub'
  scope: resourceGroup
  params: {
    name: vnetName1
    addressPrefixes: [
      '192.168.100.0/24'
    ]
    subnets: [
      {
        addressPrefix: '192.168.100.128/26'
        name: 'GatewaySubnet'
      }
      {
        addressPrefix: '192.168.100.160/26'
        name: 'AzureFirewallSubnet'
      }
      {
        addressPrefix: '192.168.100.64/26'
        name: 'AzureBastionSubnet'
        networkSecurityGroupId: NSG_bastion_subnet.outputs.resourceId
        //  routeTableId: ''
      }
      {
        addressPrefix: '192.168.100.0/26'
        name: 'Subnet-Hub'
        //  networkSecurityGroupId: ''
        //  routeTableId: ''
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

module VirtualNetworkSpoke '../../../modules/Microsoft.Network/virtualNetworks/deploy.bicep' = {
  name: 'VirtualNetwork_Spoke'
  scope: resourceGroup
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
}
