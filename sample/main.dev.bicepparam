using './main.bicep'

param environmentName = 'dev'
param location = 'japaneast'
param workloadName = 'web'

// Obtain with: az ad signed-in-user show --query userPrincipalName -o tsv
param sqlAdminLoginName = '<REPLACE_ME@contoso.onmicrosoft.com>'

// Obtain with: az ad signed-in-user show --query id -o tsv
param sqlAdminObjectId = '<REPLACE_ME_OBJECT_ID>'
