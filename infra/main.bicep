@description('Object ID of the user/principal to grant Cosmos DB data access')
// Get your principal object ID via: az ad signed-in-user show --query id -o tsv
param userPrincipalId string = deployer().objectId

// Load abbreviations from JSON file
var abbrs = loadJsonContent('./abbreviations.json')

@minLength(1)
@description('Primary location for all resources.')
param location string = resourceGroup().location

@minLength(1)
param publisherEmail string = 'noreply@microsoft.com'

@minLength(1)
param publisherName string = 'n/a'

var storageAccountName = '${abbrs.storageStorageAccounts}${uniqueString(resourceGroup().id)}'
var aiFoundryName = '${abbrs.azureFoundryResource}${uniqueString(resourceGroup().id)}'
var aiProjectName = '${abbrs.azureFoundryProject}${uniqueString(resourceGroup().id)}'
var containerAppName = '${abbrs.appContainerApps}${uniqueString(resourceGroup().id)}'
var containerAppEnvName = '${abbrs.appManagedEnvironments}${uniqueString(resourceGroup().id)}'
var logAnalyticsName = '${abbrs.operationalInsightsWorkspaces}${uniqueString(resourceGroup().id)}'
var appInsightsName = '${abbrs.insightsComponents}${uniqueString(resourceGroup().id)}'
var registryName = '${abbrs.containerRegistryRegistries}${uniqueString(resourceGroup().id)}'
var registrySku = 'Standard'
var apimServiceName = '${abbrs.apiManagementService}${uniqueString(resourceGroup().id)}'
var apiCenterName = '${abbrs.apiCenterServices}${uniqueString(resourceGroup().id)}'
var resourceSuffix = uniqueString(resourceGroup().id)

var tags = {
  Project: 'Tech Workshop L300 - MCP and AI Gateway'
  Environment: 'Lab'
  Owner: deployer().userPrincipalName
  SecurityControl: 'ignore'
  CostControl: 'ignore'
}

// Ensure the current resource group has the required tag via a subscription-scoped module
module updateRgTags 'updateRgTags.bicep' = {
  name: 'updateRgTags'
  scope: subscription()
  params: {
    rgName: resourceGroup().name
    rgLocation: resourceGroup().location
    newTags: union(resourceGroup().tags ?? {}, tags )
  }
}

var locations = [
  {
    locationName: location
    failoverPriority: 0
    isZoneRedundant: false
  }
]

@description('Creates an Azure Storage account.')
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
  tags: tags
}

resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-10-01-preview' = {
  name: aiFoundryName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  properties: {
    // required to work in Microsoft Foundry
    allowProjectManagement: true 

    // Defines developer API endpoint subdomain
    customSubDomainName: aiFoundryName

    disableLocalAuth: false
    publicNetworkAccess: 'Enabled'
  }
  tags: tags
}

/*
  Developer APIs are exposed via a project, which groups in- and outputs that relate to one use case, including files.
  Its advisable to create one project right away, so development teams can directly get started.
  Projects may be granted individual RBAC permissions and identities on top of what account provides.
*/ 
resource aiProject 'Microsoft.CognitiveServices/accounts/projects@2025-10-01-preview' = {
  name: aiProjectName
  parent: aiFoundry
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
  tags: tags
}

@description('Creates GPT-5.2-chat deployment in AI Foundry.')
resource gpt52ChatDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: aiFoundry
  name: 'gpt-5.2-chat'
  sku: {
    name: 'GlobalStandard'
    capacity: 250
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-5.2-chat'
      version: '2025-12-11'
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    currentCapacity: 250
    raiPolicyName: 'Microsoft.DefaultV2'
  }
}

@description('Creates GPT-5-mini deployment in AI Foundry.')
resource gpt5MiniDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: aiFoundry
  name: 'gpt-5-mini'
  sku: {
    name: 'GlobalStandard'
    capacity: 212
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-5-mini'
      version: '2025-08-07'
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    currentCapacity: 212
    raiPolicyName: 'Microsoft.DefaultV2'
  }
  dependsOn: [
    gpt52ChatDeployment
  ]
}

@description('Creates text-embedding-3-large deployment in AI Foundry.')
resource textEmbedding3LargeDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: aiFoundry
  name: 'text-embedding-3-large'
  sku: {
    name: 'GlobalStandard'
    capacity: 250
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'text-embedding-3-large'
      version: '1'
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    currentCapacity: 250
    raiPolicyName: 'Microsoft.DefaultV2'
  }
  dependsOn: [
    gpt5MiniDeployment
  ]
}

@description('Creates an Azure Log Analytics workspace.')
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 90
    workspaceCapping: {
      dailyQuotaGb: 1
    }
  }
  tags: tags
}

@description('Creates an Azure Application Insights resource.')
resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
  tags: tags
}

resource alertsWorkbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid(resourceGroup().id, resourceSuffix, 'alertsWorkbook')
  location: resourceGroup().location
  kind: 'shared'
  properties: {
    displayName: 'Alerts Workbook'
    serializedData: loadTextContent('workbooks/alerts.json')
    sourceId: logAnalyticsWorkspace.id
    category: 'workbook'
  }
}

resource azureOpenAIInsightsWorkbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid(resourceGroup().id, resourceSuffix, 'azureOpenAIInsights')
  location: resourceGroup().location
  kind: 'shared'
  properties: {
    displayName: 'Azure OpenAI Insights'
    serializedData: string(loadJsonContent('workbooks/azure-openai-insights.json'))
    sourceId: logAnalyticsWorkspace.id
    category: 'workbook'
  }
}

resource openAIUsageWorkbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid(resourceGroup().id, resourceSuffix, 'costAnalysis')
  location: resourceGroup().location
  kind: 'shared'
  properties: {
    displayName: 'Cost Analysis'
    serializedData: replace(loadTextContent('workbooks/cost-analysis.json'), '{workspace-id}', logAnalyticsWorkspace.id)
    sourceId: logAnalyticsWorkspace.id
    category: 'workbook'
  }
}

@description('Creates custom pricing table in Log Analytics for OpenAI model pricing data.')
resource pricingTable 'Microsoft.OperationalInsights/workspaces/tables@2023-09-01' = {
  parent: logAnalyticsWorkspace
  name: 'PRICING_CL'
  properties: {
    totalRetentionInDays: 4383
    plan: 'Analytics'
    schema: {
      name: 'PRICING_CL'
      description: 'OpenAI models pricing table for ${logAnalyticsWorkspace.properties.customerId}'
      columns: [
        {
          name: 'TimeGenerated'
          type: 'datetime'
        }
        {
          name: 'Model'
          type: 'string'
        }
        {
          name: 'InputTokensPrice'
          type: 'real'
        }
        {
          name: 'OutputTokensPrice'
          type: 'real'
        }
      ]
    }
    retentionInDays: 730
  }
  tags: tags
}

@description('Creates Data Collection Rule for pricing data ingestion.')
resource pricingDCR 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: 'dcr-pricing-${uniqueString(resourceGroup().id)}'
  location: location
  kind: 'Direct'
  properties: {
    streamDeclarations: {
      'Custom-Json-${pricingTable.name}': {
        columns: [
          {
            name: 'TimeGenerated'
            type: 'datetime'
          }
          {
            name: 'Model'
            type: 'string'
          }
          {
            name: 'InputTokensPrice'
            type: 'real'
          }
          {
            name: 'OutputTokensPrice'
            type: 'real'
          }
        ]
      }
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: logAnalyticsWorkspace.id
          name: logAnalyticsWorkspace.name
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Custom-Json-${pricingTable.name}'
        ]
        destinations: [
          logAnalyticsWorkspace.name
        ]
        transformKql: 'source'
        outputStream: 'Custom-${pricingTable.name}'
      }
    ]
  }
  tags: tags
}

@description('Assigns Monitoring Metrics Publisher role to deployer for pricing DCR.')
var monitoringMetricsPublisherRoleDefinitionID = resourceId('Microsoft.Authorization/roleDefinitions', '3913510d-42f4-4e42-8a64-420c390055eb')
resource pricingDCRRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: pricingDCR
  name: guid(subscription().id, resourceGroup().id, pricingDCR.name, monitoringMetricsPublisherRoleDefinitionID)
  properties: {
    roleDefinitionId: monitoringMetricsPublisherRoleDefinitionID
    principalId: userPrincipalId
    principalType: 'User'
  }
}

@description('Creates custom subscription quota table in Log Analytics for APIM subscription cost quotas.')
resource subscriptionQuotaTable 'Microsoft.OperationalInsights/workspaces/tables@2023-09-01' = {
  parent: logAnalyticsWorkspace
  name: 'SUBSCRIPTION_QUOTA_CL'
  properties: {
    totalRetentionInDays: 4383
    plan: 'Analytics'
    schema: {
      name: 'SUBSCRIPTION_QUOTA_CL'
      description: 'APIM subscriptions quota table for ${logAnalyticsWorkspace.properties.customerId}'
      columns: [
        {
          name: 'TimeGenerated'
          type: 'datetime'
        }
        {
          name: 'Subscription'
          type: 'string'
        }
        {
          name: 'CostQuota'
          type: 'real'
        }
      ]
    }
    retentionInDays: 730
  }
  tags: tags
}

@description('Creates Data Collection Rule for subscription quota data ingestion.')
resource subscriptionQuotaDCR 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: 'dcr-quota-${uniqueString(resourceGroup().id)}'
  location: location
  kind: 'Direct'
  properties: {
    streamDeclarations: {
      'Custom-Json-${subscriptionQuotaTable.name}': {
        columns: [
          {
            name: 'TimeGenerated'
            type: 'datetime'
          }
          {
            name: 'Subscription'
            type: 'string'
          }
          {
            name: 'CostQuota'
            type: 'real'
          }
        ]
      }
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: logAnalyticsWorkspace.id
          name: logAnalyticsWorkspace.name
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Custom-Json-${subscriptionQuotaTable.name}'
        ]
        destinations: [
          logAnalyticsWorkspace.name
        ]
        transformKql: 'source'
        outputStream: 'Custom-${subscriptionQuotaTable.name}'
      }
    ]
  }
  tags: tags
}

@description('Assigns Monitoring Metrics Publisher role to deployer for subscription quota DCR.')
resource subscriptionQuotaDCRRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: subscriptionQuotaDCR
  name: guid(subscription().id, resourceGroup().id, subscriptionQuotaDCR.name, monitoringMetricsPublisherRoleDefinitionID)
  properties: {
    roleDefinitionId: monitoringMetricsPublisherRoleDefinitionID
    principalId: userPrincipalId
    principalType: 'User'
  }
}

@description('Creates an Azure Container Registry.')
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-12-01' = {
  name: registryName
  location: location
  sku: {
    name: registrySku
  }
  properties: {
    adminUserEnabled: true
  }
  tags: tags
}

@description('Creates an Azure Container Apps Environment.')
resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: containerAppEnvName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
  tags: tags
}

@description('Creates an Azure Container App')
resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: location
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 80
        transport: 'auto'
        allowInsecure: false
      }
      registries: [
        {
          server: '${containerRegistry.name}${environment().suffixes.acrLoginServer}'
          username: containerRegistry.name
          passwordSecretRef: 'registry-password'
        }
      ]
      secrets: [
        {
          name: 'registry-password'
          value: containerRegistry.listCredentials().passwords[0].value
        }
        {
          name: 'appinsights-key'
          value: appInsights.properties.InstrumentationKey
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'mcp-ai-gateway-app'
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
              secretRef: 'appinsights-key'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 5
      }
    }
  }
  tags: tags
}

@description('Creates an Azure API Management service.')
resource apimService 'Microsoft.ApiManagement/service@2024-06-01-preview' = {
  name: apimServiceName
  location: location
  sku: {
    name: 'BasicV2'
    capacity: 1
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    notificationSenderEmail: 'apimgmt-noreply@mail.windowsazure.com'
    hostnameConfigurations: [
      {
        type: 'Proxy'
        hostName: '${apimServiceName}.azure-api.net'
        negotiateClientCertificate: false
        defaultSslBinding: true
        certificateSource: 'BuiltIn'
      }
    ]
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2': 'False'
    }
    virtualNetworkType: 'None'
    natGatewayState: 'Enabled'
    apiVersionConstraint: {}
    publicNetworkAccess: 'Enabled'
    legacyPortalStatus: 'Disabled'
    developerPortalStatus: 'Disabled'
    releaseChannel: 'Default'
  }
  tags: tags
}

@description('Creates diagnostic settings for API Management to send logs to Log Analytics.')
resource apimDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: apimService
  name: 'apim-diagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        category: 'GatewayLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'WebSocketConnectionLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'DeveloperPortalAuditLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'GatewayLlmLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

@description('Creates Azure Monitor logger for API Management.')
resource apimAzureMonitorLogger 'Microsoft.ApiManagement/service/loggers@2024-06-01-preview' = {
  parent: apimService
  name: 'azuremonitor'
  properties: {
    loggerType: 'azureMonitor'
    isBuffered: true
  }
}

@description('Creates diagnostic settings for API Management with Azure Monitor.')
resource apimDiagnostics 'Microsoft.ApiManagement/service/diagnostics@2024-06-01-preview' = {
  parent: apimService
  name: 'azuremonitor'
  properties: {
    logClientIp: true
    loggerId: apimAzureMonitorLogger.id
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: {
        dataMasking: {
          queryParams: [
            {
              value: '*'
              mode: 'Hide'
            }
          ]
        }
      }
    }
    backend: {
      request: {
        dataMasking: {
          queryParams: [
            {
              value: '*'
              mode: 'Hide'
            }
          ]
        }
      }
    }
  }
}

@description('Associates Azure Monitor logger with diagnostics.')
resource apimDiagnosticsLogger 'Microsoft.ApiManagement/service/diagnostics/loggers@2018-01-01' = {
  parent: apimDiagnostics
  name: 'azuremonitor'
}

@description('Creates a product for the weather assistant application.')
resource weatherAssistantProduct 'Microsoft.ApiManagement/service/products@2024-06-01-preview' = {
  name: 'app-weather-assistant'
  parent: apimService
  properties: {
    displayName: 'APP-Weather-Assistant'
    description: 'Offering OpenAI services for the weather assistant platform.'
    subscriptionRequired: true
    approvalRequired: true
    subscriptionsLimit: 200
    state: 'published'
    terms: 'By subscribing to this product, you agree to the terms and conditions.'
  }
}

@description('Creates Platinum product with TPM: 2000, Token Quota: 1000000/Monthly, Cost Quota: 15')
resource platinumProduct 'Microsoft.ApiManagement/service/products@2024-06-01-preview' = {
  name: 'platinum'
  parent: apimService
  properties: {
    displayName: 'Platinum Product'
    description: 'Premium tier with 2000 TPM, 1000000 tokens per month, and $15 cost quota'
    subscriptionRequired: true
    approvalRequired: false
    state: 'published'
  }
}

@description('Creates Gold product with TPM: 1000, Token Quota: 1000000/Monthly, Cost Quota: 10')
resource goldProduct 'Microsoft.ApiManagement/service/products@2024-06-01-preview' = {
  name: 'gold'
  parent: apimService
  properties: {
    displayName: 'Gold Product'
    description: 'Gold tier with 1000 TPM, 1000000 tokens per month, and $10 cost quota'
    subscriptionRequired: true
    approvalRequired: false
    state: 'published'
  }
}

@description('Creates Silver product with TPM: 500, Token Quota: 1000000/Monthly, Cost Quota: 5')
resource silverProduct 'Microsoft.ApiManagement/service/products@2024-06-01-preview' = {
  name: 'silver'
  parent: apimService
  properties: {
    displayName: 'Silver Product'
    description: 'Silver tier with 500 TPM, 1000000 tokens per month, and $5 cost quota'
    subscriptionRequired: true
    approvalRequired: false
    state: 'published'
  }
}

@description('Creates Subscription 1 for Platinum product')
resource subscription1 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = {
  name: 'subscription1'
  parent: apimService
  properties: {
    displayName: 'Subscription 1'
    scope: '/products/${platinumProduct.name}'
    state: 'active'
  }
}

@description('Creates Subscription 2 for Gold product')
resource subscription2 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = {
  name: 'subscription2'
  parent: apimService
  properties: {
    displayName: 'Subscription 2'
    scope: '/products/${goldProduct.name}'
    state: 'active'
  }
}

@description('Creates Subscription 3 for Silver product')
resource subscription3 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = {
  name: 'subscription3'
  parent: apimService
  properties: {
    displayName: 'Subscription 3'
    scope: '/products/${silverProduct.name}'
    state: 'active'
  }
}

@description('Creates Subscription 4 for Silver product')
resource subscription4 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = {
  name: 'subscription4'
  parent: apimService
  properties: {
    displayName: 'Subscription 4'
    scope: '/products/${silverProduct.name}'
    state: 'active'
  }
}

@description('Creates an Azure API Center service.')
resource apiCenter 'Microsoft.ApiCenter/services@2024-06-01-preview' = {
  name: apiCenterName
  location: location
  sku: {
    name: 'Free'
  }
  properties: {}
  tags: tags
}

@description('Creates default workspace in API Center.')
resource apiCenterDefaultWorkspace 'Microsoft.ApiCenter/services/workspaces@2024-06-01-preview' = {
  parent: apiCenter
  name: 'default'
  properties: {
    title: 'Default workspace'
    description: 'Default workspace'
  }
}

@description('Creates Microsoft docs MCP server API in API Center.')
resource apiMsdocsMcpServer 'Microsoft.ApiCenter/services/workspaces/apis@2024-06-01-preview' = {
  parent: apiCenterDefaultWorkspace
  name: 'msdocs-mcp-server'
  properties: {
    title: 'Microsoft docs'
    summary: 'AI assistant with real-time access to official Microsoft documentation.'
    description: 'AI assistant with real-time access to official Microsoft documentation.'
    kind: 'mcp'
    externalDocumentation: []
    contacts: []
    customProperties: {}
  }
}

@description('Creates Swagger Petstore API in API Center.')
resource apiSwaggerPetstore 'Microsoft.ApiCenter/services/workspaces/apis@2024-06-01-preview' = {
  parent: apiCenterDefaultWorkspace
  name: 'swagger-petstore'
  properties: {
    title: 'Swagger Petstore'
    summary: 'A sample API that uses a petstore as an example to demonstrate features in the OpenAPI Specification.'
    description: 'The Swagger Petstore API serves as a sample API to demonstrate the functionality and features of the OpenAPI Specification. This API allows users to interact with a virtual pet store, including managing pet inventory, placing orders, and retrieving details about available pets. It provides various endpoints that simulate real-world scenarios, making it a valuable reference for understanding how to structure and implement API specifications in compliance with OpenAPI standards.'
    kind: 'rest'
    termsOfService: {
      url: 'https://aka.ms/apicenter-samples-api-termsofservice-link'
    }
    license: {
      name: 'MIT'
      url: 'https://aka.ms/apicenter-samples-api-license-link'
    }
    externalDocumentation: [
      {
        description: 'API Documentation'
        url: 'https://aka.ms/apicenter-samples-api-documentation-link'
      }
    ]
    contacts: [
      {
        name: 'John Doe'
        email: 'john.doe@example.com'
      }
    ]
    customProperties: {}
  }
}

@description('Creates default MCP environment in API Center.')
resource apiEnvironmentDefaultMcp 'Microsoft.ApiCenter/services/workspaces/environments@2024-06-01-preview' = {
  parent: apiCenterDefaultWorkspace
  name: 'default-mcp-env'
  properties: {
    title: 'Default MCP Environment'
    kind: 'development'
    description: 'Auto-generated environment for Microsoft docs'
    customProperties: {}
  }
}

@description('Creates original version for Microsoft docs MCP server.')
resource apiVersionMsdocsMcpOriginal 'Microsoft.ApiCenter/services/workspaces/apis/versions@2024-06-01-preview' = {
  parent: apiMsdocsMcpServer
  name: 'original'
  properties: {
    title: 'Original'
    lifecycleStage: 'production'
  }
}

@description('Creates version 1.0.0 for Swagger Petstore API.')
resource apiVersionSwaggerPetstore100 'Microsoft.ApiCenter/services/workspaces/apis/versions@2024-06-01-preview' = {
  parent: apiSwaggerPetstore
  name: '1-0-0'
  properties: {
    title: '1.0.0'
    lifecycleStage: 'testing'
  }
}

@description('Creates SSE definition for Microsoft docs MCP server.')
resource apiDefinitionMsdocsMcpSse 'Microsoft.ApiCenter/services/workspaces/apis/versions/definitions@2024-06-01-preview' = {
  parent: apiVersionMsdocsMcpOriginal
  name: 'default-sse'
  properties: {
    title: 'SSE Definition for Microsoft docs'
    description: 'Auto-generated definition for Microsoft docs'
  }
}

@description('Creates Streamable definition for Microsoft docs MCP server.')
resource apiDefinitionMsdocsMcpStreamable 'Microsoft.ApiCenter/services/workspaces/apis/versions/definitions@2024-06-01-preview' = {
  parent: apiVersionMsdocsMcpOriginal
  name: 'default-streamable'
  properties: {
    title: 'Streamable Definition for Microsoft docs'
    description: 'Auto-generated definition for Microsoft docs'
  }
}

@description('Creates default definition for Swagger Petstore.')
resource apiDefinitionSwaggerPetstoreDefault 'Microsoft.ApiCenter/services/workspaces/apis/versions/definitions@2024-06-01-preview' = {
  parent: apiVersionSwaggerPetstore100
  name: 'default'
  properties: {
    title: 'Default'
  }
}

@description('Creates deployment to default MCP environment.')
resource apiDeploymentMsdocsMcp 'Microsoft.ApiCenter/services/workspaces/apis/deployments@2024-06-01-preview' = {
  parent: apiMsdocsMcpServer
  name: 'default-deployment'
  properties: {
    title: 'Deployment to default-mcp-env'
    environmentId: '/workspaces/default/environments/default-mcp-env'
    definitionId: '/workspaces/default/apis/msdocs-mcp-server/versions/original/definitions/default-sse'
    server: {
      runtimeUri: [
        'https://learn.microsoft.com/api/mcp'
      ]
    }
    customProperties: {}
  }
  dependsOn: [
    apiDefinitionMsdocsMcpSse
    apiEnvironmentDefaultMcp
  ]
}

module finOpsDashboardModule 'dashboard.bicep' = {
  name: 'finOpsDashboardModule'
  params: {
    resourceSuffix: resourceSuffix
    workspaceName: logAnalyticsWorkspace.name
    workspaceId: logAnalyticsWorkspace.id
    workbookCostAnalysisId: openAIUsageWorkbook.id
    workbookAzureOpenAIInsightsId: azureOpenAIInsightsWorkbook.id
    appInsightsId: appInsights.id
    appInsightsName: appInsights.name
  }
}


output storageAccountName string = storageAccount.name
output container_registry_name string = containerRegistry.name
output container_app_environment_name string = containerAppEnvironment.name
output container_app_environment_id string = containerAppEnvironment.id
output application_name string = containerApp.name
output application_url string = containerApp.properties.configuration.ingress.fqdn
output apim_service_name string = apimService.name
output apim_gateway_url string = apimService.properties.gatewayUrl
output api_center_name string = apiCenter.name
output pricingDCREndpoint string = pricingDCR.properties.endpoints.logsIngestion
output pricingDCRImmutableId string = pricingDCR.properties.immutableId
output pricingDCRStream string = pricingDCR.properties.dataFlows[0].streams[0]
output subscriptionQuotaDCREndpoint string = subscriptionQuotaDCR.properties.endpoints.logsIngestion
output subscriptionQuotaDCRImmutableId string = subscriptionQuotaDCR.properties.immutableId
output subscriptionQuotaDCRStream string = subscriptionQuotaDCR.properties.dataFlows[0].streams[0]
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.properties.customerId

