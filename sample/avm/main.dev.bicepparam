using './main.bicep'

param environmentName = 'dev'
param location = 'japaneast'
param workloadName = 'web'

// az ad signed-in-user show --query userPrincipalName -o tsv
param sqlAdminLoginName = '<REPLACE_ME@contoso.onmicrosoft.com>'

// az ad signed-in-user show --query id -o tsv
param sqlAdminObjectId = '<REPLACE_ME_OBJECT_ID>'
