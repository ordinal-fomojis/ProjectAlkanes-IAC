resource "azurerm_kubernetes_cluster" "aks" {
  name                = "shovel-aks${local.postfix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "shovel${local.postfix}"

  default_node_pool {
    name                 = "default"
    vm_size              = "Standard_B2ls_v2"
    auto_scaling_enabled = true
    min_count            = 1
    max_count            = 10
    node_count           = 1

    upgrade_settings {
      drain_timeout_in_minutes      = 5
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_container_registry" "acr" {
  name                = "shovelacr${var.id}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
}

resource "azurerm_role_assignment" "acr_role" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}
