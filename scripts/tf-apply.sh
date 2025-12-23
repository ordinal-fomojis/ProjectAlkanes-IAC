set -eo pipefail

source ./scripts/tf-init.sh $1
terraform apply -var="id=$1"
