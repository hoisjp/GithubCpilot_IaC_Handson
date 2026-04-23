using './main.bicep'

param environmentName = 'prod'
param location = 'japaneast'
param workloadName = 'web'

// For production, prefer an Entra ID **group** as SQL admin, not a single user.
// Obtain group object id with: az ad group show --group "<group-name>" --query id -o tsv
param sqlAdminLoginName = '<REPLACE_ME_GROUP_NAME>'
param sqlAdminObjectId = '<REPLACE_ME_GROUP_OBJECT_ID>'
