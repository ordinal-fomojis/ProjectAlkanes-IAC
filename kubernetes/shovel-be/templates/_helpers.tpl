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

{{/* Returns the key name for dotenv private key */}}
{{- define "dotenvKeyName" -}}
{{- if .name | eq "prod" -}}
DOTENV_PRIVATE_KEY_PROD
{{- else -}}
DOTENV_PRIVATE_KEY_NONPROD
{{- end -}}
{{- end -}}

{{/* Returns name of k8s resource containing dotenv private key */}}
{{- define "dotenvSecretName" -}}
{{- if .name | eq "prod" -}}
dotenv-private-key-prod
{{- else -}}
dotenv-private-key-nonprod
{{- end -}}
{{- end -}}
