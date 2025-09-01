output "function_app_name" {
  value = azurerm_linux_function_app.function_app.name
}

output "webapp_prod_name" {
  value = azurerm_linux_web_app.webapp.name
}

output "webapp_nonprod_name" {
  value = azurerm_linux_web_app.webapp_nonprod.name
}
