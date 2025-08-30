data "azuread_users" "admin" {
  user_principal_names = ["vannix_fomojis.io#EXT#@vannixfomojis.onmicrosoft.com"]
}

data "azuread_users" "contributors" {
  user_principal_names = ["konrad.dabrowski02_gmail.com#EXT#@vannixfomojis.onmicrosoft.com"]
}

data "azuread_users" "readers" {
  user_principal_names = ["sanjvault_gmail.com#EXT#@vannixfomojis.onmicrosoft.com"]
}

locals {
  admins       = data.azuread_users.admin.object_ids
  contributors = data.azuread_users.contributors.object_ids
  readers      = data.azuread_users.readers.object_ids
}

resource "azurerm_role_assignment" "key_vault_secrets_officer" {
  for_each             = toset(data.azuread_users.admin.object_ids)
  scope                = azurerm_key_vault.key_vault.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = each.value
}

resource "azurerm_role_assignment" "key_vault_secrets_user" {
  for_each             = toset(concat(local.contributors, local.readers))
  scope                = azurerm_key_vault.key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = each.value
}

resource "azurerm_role_assignment" "rg_contributor" {
  for_each             = toset(concat(local.admins, local.contributors))
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = each.value
}

resource "azurerm_role_assignment" "rg_reader" {
  for_each             = toset(local.readers)
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Reader"
  principal_id         = each.value
}
