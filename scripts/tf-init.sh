set -eo pipefail

source ./scripts/prepare-az.sh

subscription_id=$(az account show | jq .id -r)

state_file="shovel-$1.tfstate"
if [ -z "$1" ]; then
  state_file="shovel.tfstate"
fi

cd terraform
export ARM_SUBSCRIPTION_ID=$subscription_id
terraform init -backend-config="key=${state_file}" -reconfigure
