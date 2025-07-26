resource "azurerm_cdn_frontdoor_profile" "frontdoor" {
  name                = "FrontDoor"
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Standard_AzureFrontDoor"
}

resource "azurerm_cdn_frontdoor_endpoint" "frontdoor_endpoint" {
  name                     = "FrontDoorEndpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.frontdoor.id
}

resource "azurerm_cdn_frontdoor_origin_group" "frontdoor_origin_group" {
  for_each                 = local.environments
  name                     = "FrontDoorOriginGroup${each.value.name == "" ? "" : "-${each.value.name}"}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.frontdoor.id
  session_affinity_enabled = true

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }

  health_probe {
    path                = "/api/health"
    request_type        = "GET"
    protocol            = "Https"
    interval_in_seconds = 100
  }
}

resource "azurerm_cdn_frontdoor_origin" "app_service_origin" {
  for_each                      = local.environments
  name                          = "BackendOrigin${each.value.name == "" ? "" : "-${each.value.name}"}"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.frontdoor_origin_group[each.key].id

  enabled                        = true
  host_name                      = azurerm_linux_web_app.webapp[each.key].default_hostname
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = azurerm_linux_web_app.webapp[each.key].default_hostname
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = true
}

resource "azurerm_cdn_frontdoor_route" "frontdoor_route" {
  for_each                        = local.environments
  name                            = "BackendRoute${each.value.name == "" ? "" : "-${each.value.name}"}"
  cdn_frontdoor_endpoint_id       = azurerm_cdn_frontdoor_endpoint.frontdoor_endpoint.id
  cdn_frontdoor_origin_group_id   = azurerm_cdn_frontdoor_origin_group.frontdoor_origin_group[each.key].id
  cdn_frontdoor_origin_ids        = [azurerm_cdn_frontdoor_origin.app_service_origin[each.key].id]
  cdn_frontdoor_origin_path       = "/"
  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.api_custom_domain.id]
  
  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = [each.value.route]
  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true
}

resource "azurerm_cdn_frontdoor_custom_domain" "api_custom_domain" {
  name                     = "ApiDomain"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.frontdoor.id
  host_name                = "api.shovel.space"

  tls {
    certificate_type = "ManagedCertificate"
  }
}
