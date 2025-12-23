set -eo pipefail

subscription_name=$(az account show | jq .name -r)

if [ "$subscription_name" != "fomojis" ]; then
  az account set --name fomojis
fi
