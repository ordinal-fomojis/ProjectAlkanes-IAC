output "function_app_name" {
  value = azurerm_linux_function_app.function_app.name
}

output "webapp_name" {
  value = {
    for key, value in azurerm_linux_web_app.webapp : key => value.name
  }
}
