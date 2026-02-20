output "function_app_name" {
  value = {
    for key, value in azurerm_function_app_flex_consumption.function_app : key => value.name
  }
}

output "rg_name" {
  value = azurerm_resource_group.rg.name
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "acr_name" {
  value = azurerm_container_registry.acr.name
}
