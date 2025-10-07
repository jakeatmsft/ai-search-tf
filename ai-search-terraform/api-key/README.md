# Azure AI Search Terraform sample (API key version)

This folder contains the original sample that deploys an Azure Resource Group and an Azure AI Search service using Terraform, and then creates a sample search index (hotels) using the REST API authenticated with a Search admin key. To use the Entra ID-based workflow, run Terraform from the repository root instead.

## Prerequisites
- Terraform 1.0+
- Azure CLI installed and logged in to a subscription with permissions to create resources
  - az login
  - (optional) set subscription: az account set --subscription <SUBSCRIPTION_ID>
- curl installed (for REST calls run by Terraform and for verification)
- jq installed (optional; used in verification examples)

The azurerm provider uses your Azure CLI credentials by default. Alternatively, configure a Service Principal via the ARM_ environment variables.

## Files
- main.tf – resource group and search service
- providers.tf – Terraform and provider requirements (azurerm, random, null)
- variables.tf – configurable variables with validations
- outputs.tf – key outputs after deployment
- index.tf – creates the sample hotels index via the Search REST API using a local-exec provisioner

## Deployment steps
1) Change to the directory with the Terraform files:

   cd ai-search-terraform/api-key

2) Initialize Terraform and download providers:

   terraform init -upgrade

3) Create an execution plan:

   terraform plan -out main.tfplan

4) Apply the plan to deploy the resource group and Azure AI Search service:

   terraform apply main.tfplan

5) Retrieve the Search service admin key (required to manage indexes):

   resource_group_name=$(terraform output -raw resource_group_name)
   search_service_name=$(terraform output -raw azurerm_search_service_name)
   admin_key=$(az search admin-key show --resource-group "$resource_group_name" --service-name "$search_service_name" --query primaryKey -o tsv)

6) Create the sample hotels index using the REST API via Terraform (index.tf):

   terraform apply -var "search_admin_key=$admin_key"

- Optional overrides:
  - Index name: -var "index_name=hotels"
  - API version: -var "api_version=2024-07-01"

## Verify
- Show the created Search service:

  az search service show \
    --name "$search_service_name" \
    --resource-group "$resource_group_name"

- List indexes on the service:

  curl -sSf -H "api-key: $admin_key" \
    "https://$search_service_name.search.windows.net/indexes?api-version=2024-07-01" | jq .

- Get the hotels index definition:

  curl -sSf -H "api-key: $admin_key" \
    "https://$search_service_name.search.windows.net/indexes/hotels?api-version=2024-07-01" | jq .

## Clean up
Destroy all created resources when finished:

  terraform destroy

## Notes
- Default region is eastus; override with -var "resource_group_location=<region>".
- Default SKU is standard; valid values: free, basic, standard, standard2, standard3, storage_optimized_l1, storage_optimized_l2.
- Free SKU allows only 1 replica and 1 partition.
- The index.tf uses POST to /indexes to create the index. If you need create-or-replace behavior, switch to PUT and target /indexes/<index_name>.
