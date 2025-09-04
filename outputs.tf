output "function_app_name_prod" {
  value = azurerm_function_app_flex_consumption.function_app_prod.name
}

output "function_app_name_nonprod" {
  value = azurerm_function_app_flex_consumption.function_app_nonprod.name
}

output "webapp_prod_name" {
  value = azurerm_linux_web_app.webapp.name
}

output "webapp_nonprod_name" {
  value = azurerm_linux_web_app.webapp_nonprod.name
}
