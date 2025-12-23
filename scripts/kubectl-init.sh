set -eo pipefail

source ./scripts/tf-init.sh $1

rg_name=$(terraform output -raw rg_name)
cluster_name=$(terraform output -raw aks_cluster_name)
az aks get-credentials --resource-group $rg_name --name $cluster_name
