param storageAccountName string = uniqueString('stg', resourceGroup(). id)
param location string = resourceGroup().location
param skuName string = 'Standard_LRS'
param managedIdentityName string = 'mi-${uniqueString(resourceGroup().id)}'

// Use Bicep resources

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: managedIdentityName
  location: location
}

resource stgBlobDataContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  scope: tenant()
}

resource blobPrivateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.${environment().suffixes.storage}'
  location: 'global'
}

resource dnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: 'dnsZoneLink'
  parent: blobPrivateDNSZone
  properties: {
    virtualNetwork: {
      id: resourceId('Microsoft.Network/virtualNetworks', 'vnet')
    }
  }
}

resource stg 'Microsoft.Storage/storageAccounts@2023-04-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: skuName
  }
  kind: 'StorageV2'
}

resource stgBlobDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().subscriptionId, 'stgBlobDataContributorRoleAssignment')
  scope: stg
  properties: {
    principalId: managedIdentity.properties.principalId
    roleDefinitionId: stgBlobDataContributor.id
  }
}

resource blobPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'blobPrivateEndpoint'
  location: location
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', 'vnet', 'default')
    }
    privateLinkServiceConnections: [
      {
        name: 'blobPrivateLinkServiceConnection'
        properties: {
          privateLinkServiceId: stg.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

// Use AVM module

module avmStg 'br/public:avm/res/storage/storage-account:0.8.3' = {
  name: '${storageAccountName}-deployment'
  params: {
    name: storageAccountName
    location: location
    skuName: skuName
    kind: 'StorageV2'
    roleAssignments: [
      {
        principalId: managedIdentity.properties.principalId
        roleDefinitionIdOrName: stgBlobDataContributor.id
      }
    ]
    privateEndpoints: [
      {
        service: 'blob'
        subnetResourceId: ''
      }
    ]
  }
}
