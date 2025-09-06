output "function_app_name" {
  value = {
    for key, value in azurerm_function_app_flex_consumption.function_app : key => value.name
  }
}

output "webapp_prod_name" {
  value = azurerm_linux_web_app.webapp.name
}

output "webapp_nonprod_name" {
  value = azurerm_linux_web_app.webapp_nonprod.name
}
