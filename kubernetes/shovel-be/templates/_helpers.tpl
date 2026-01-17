{{/* Returns the subdomain for a given environment */}}
{{- define "subdomain" -}}
{{- if (index . 1).name | eq "prod" -}}
{{- index . 0 -}}
{{- else -}}
{{- (index . 1).name -}}.{{- index . 0 -}}
{{- end -}}
{{- end -}}

{{/* Creates a list of all routes, combining the custom routes with the main app environment routes */}}
{{- define "routes" -}}
{{- $allRoutes := .Values.routes -}}
{{- range $config := .Values.environments -}}
  {{- if $config.enabled -}}
    {{- $route := dict "name" $config.name "subdomain" (include "subdomain" (list $.Values.baseSubdomain $config)) "service" (printf "%s-service" $config.name) "namespace" "shovel-be" -}}
    {{- $allRoutes = append $allRoutes $route -}}
  {{- end -}}
{{- end -}}
{{- toJson $allRoutes -}}
{{- end -}}
