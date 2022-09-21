targetScope = 'subscription'

//////////////////////////
//   Input Parameters   //
//////////////////////////
@description('Optional. A parameter to control which deployments should be executed')
@allowed([
    'All'
    'Web App'
    'Web Static App'
])
param deploymentsToPerformFrontFacingLayer string

@description('Optional. A parameter to control which deployments should be executed')
@allowed([
    'All'
    'Cosmos DB'
    'Serverless SQL'
    'PostresSQL'
])
param deploymentsToPerformDatabaseLayer string

@description('Optional. A parameter to control which deployments should be executed')
@allowed([
    'All'
    'Container Groups'
    'Container Registry'
])
param deploymentsToPerformApplicationLayer string

@description('Optional. Specifies the location for resources.')
param location string


///////////////////////////////
//   User-defined Deployment Properties   //
///////////////////////////////

// This space is dedicated to any users that would like to change the deployment properties

///////////////////////////////
//   Default Deployment Properties   //
///////////////////////////////
// Resource Group
var rgParam = {
    name: 'random-name'
    location: 'northeurope'
    tags: []
}
// User Assigned Identity
var staticSiteParam = {
    name: 'aibMsi'
}
// User Assigned Identity Role Assignment on subscription scope
var msiRoleAssignmentParam = {
    roleDefinitionIdOrName: 'Contributor'
}
// Storage Account
var saParam = {
    name: '<YourStorageAccount>'
    blobServices: {
        containers: [
            {
                name: 'aibscripts'
                publicAccess: 'None'
            }
        ]
    }
}
// Azure Compute Gallery
var acgParam = {
    name: 'aibgallery'
    images: [
        {
            hyperVGeneration: 'V2'
            name: 'linux-sid'
            osType: 'Linux'
            publisher: 'devops'
            offer: 'devops_linux'
            sku: 'devops_linux_az'
        }
        // Windows Example
        // {
        //     name: 'windows-sid'
        //     osType: 'Windows'
        //     publisher: 'devops'
        //     offer: 'devops_windows'
        //     sku: 'devops_windows_az'
        // }
    ]
}
/////////////////////////////
//   Template Deployment   //
/////////////////////////////
module imageInfraDeployment '../templates/imageInfra.deploy.bicep' = {
    name:
} -imageInfra-sbx'
     params: {
location: location
rgParam: rgParam
acgParam: acgParam
msiParam: msiParam
msiRoleAssignmentParam: msiRoleAssignmentParam
saParam: saParam
deploymentsToPerform: deploymentsToPerform
}
}
