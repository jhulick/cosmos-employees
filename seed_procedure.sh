# One-liner to insert all items (requires jq installed)
jq -c '.[]' employees_seed.json | while read -r item; do
  az cosmosdb sql item create \
    --account-name cosmos-employees-gxtsodhb \
    --database-name employeesdb \
    --container-name employees \
    --resource-group cosmos-employees-rg \
    --partition-key-value "\"$(echo $item | jq -r .id)\"" \
    --body "$item"
done
