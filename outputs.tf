output "function_app_name" {
  value = azurerm_function_app_flex_consumption.function_app.name
}

output "webapp_name" {
  value = azurerm_linux_web_app.webapp.name
}
