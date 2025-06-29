output "kube_cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "rg_name" {
  value = azurerm_resource_group.rg.name
}

output "acr_name" {
  value = azurerm_container_registry.acr.name
}

output "passwords" {
  value = {
    for key, password in random_password.passwords : key => password.result
  }
  sensitive = true
}
