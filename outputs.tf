output "function_app_name" {
  value = azurerm_linux_function_app.function_app.name
}

output "webapp_name" {
  value = {
    for key, value in azurerm_linux_web_app.webapp : key => value.name
  }
}

output "custom_domain_verification_id" {
  value = {
    for key, value in azurerm_linux_web_app.webapp : key => value.custom_domain_verification_id
  }
  sensitive = true
}

output "hostname" {
  value = {
    for key, value in azurerm_linux_web_app.webapp : key => value.default_hostname
  }
}
