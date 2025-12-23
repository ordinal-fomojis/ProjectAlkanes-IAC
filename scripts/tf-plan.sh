set -eo pipefail

source ./scripts/tf-init.sh $1
terraform plan -var="id=$1"
