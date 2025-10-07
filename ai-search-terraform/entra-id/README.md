# Azure AI Search Terraform sample (Entra ID)

This folder contains the Entra ID version of the Terraform configuration. It deploys an Azure Resource Group, an Azure AI Search service, and then builds a sample "hotels" index using Entra ID (Azure AD) authentication instead of a Search admin key. The index is created with the Azure CLI acquiring an access token for the Search data plane.

## Related templates
- `../api-key/`: alternative version that uses a Search admin key to create the index.

## Prerequisites
- Terraform 1.0+
- Azure CLI installed and authenticated (`az login` or `az login --service-principal ...`)
- Permissions in the target subscription to create resources and assign the **Search Index Data Contributor** role on the Search service
- `curl` installed (used by Terraform to call the REST API)
- `jq` installed (optional; for verification samples)

Terraform uses your current Azure CLI credentials by default. If you run Terraform with a service principal via `ARM_` environment variables, ensure the Azure CLI is also logged in as the same principal so it can request an access token during index creation.

## Files (root)
- `main.tf` – resource group and search service
- `providers.tf` – Terraform and provider requirements (azurerm, random, null)
- `variables.tf` – configurable variables with validations
- `outputs.tf` – key outputs after deployment
- `index.tf` – grants RBAC and creates the sample hotels index via Entra ID-authenticated REST calls

## Deployment steps
1. Change to this directory:

   ```bash
   cd ai-search-terraform/entra-id
   ```

2. Initialize Terraform and download providers:

   ```bash
   terraform init -upgrade
   ```

3. Create an execution plan:

   ```bash
   terraform plan -out main.tfplan
   ```

4. Apply the plan to deploy the infrastructure and create the hotels index:

   ```bash
   terraform apply main.tfplan
   ```

   During the apply Terraform assigns the **Search Index Data Contributor** role to the current identity and then calls the Search REST API with an access token from `az account get-access-token`. If RBAC propagation delays cause the index creation to fail, simply run `terraform apply` again once the role assignment is effective.

## Verify
- Show the created Search service:

  ```bash
  resource_group_name=$(terraform output -raw resource_group_name)
  search_service_name=$(terraform output -raw azurerm_search_service_name)

  az search service show \
    --name "$search_service_name" \
    --resource-group "$resource_group_name"
  ```

- Get the hotels index definition with Entra ID authentication:

  ```bash
  access_token=$(az account get-access-token --resource https://search.azure.com --query accessToken -o tsv)
  curl -sSf \
    -H "Authorization: Bearer $access_token" \
    "https://$search_service_name.search.windows.net/indexes/hotels?api-version=2024-07-01" \
    | jq .
  ```

## Clean up
Destroy all created resources when finished:

```bash
terraform destroy
```

## Notes
- Default region is `eastus`; override with `-var "resource_group_location=<region>"`.
- Default SKU is `standard`; valid values: `free`, `basic`, `standard`, `standard2`, `standard3`, `storage_optimized_l1`, `storage_optimized_l2`.
- The sample index uses the 2024-07-01 API by default; adjust with `-var "api_version=..."` if needed.
