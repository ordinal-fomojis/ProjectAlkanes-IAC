output "function_app_name" {
  value = {
    for key, value in azurerm_function_app_flex_consumption.function_app : key => value.name
  }
}

output "webapp_name" {
  value = {
    for key, value in azurerm_linux_web_app.webapp : key => value.name
  }
}
