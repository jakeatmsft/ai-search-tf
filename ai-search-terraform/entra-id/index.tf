data "azurerm_client_config" "current" {}

data "azurerm_role_definition" "search_index_data_contributor" {
  name  = "Search Index Data Contributor"
  scope = azurerm_resource_group.rg.id
}

resource "azurerm_role_assignment" "search_index_data_contributor" {
  scope                = azurerm_search_service.search.id
  role_definition_id   = data.azurerm_role_definition.search_index_data_contributor.role_definition_id
  principal_id         = data.azurerm_client_config.current.object_id
  skip_service_principal_aad_check = true
}

locals {
  search_service_name = azurerm_search_service.search.name
  search_endpoint     = "https://${local.search_service_name}.search.windows.net"
  hotels_index_definition = jsonencode({
    name   = var.index_name,
    fields = [
      { name = "HotelId", type = "Edm.String", key = true, retrievable = true, searchable = true, filterable = true },
      { name = "HotelName", type = "Edm.String", retrievable = true, searchable = true, filterable = false, sortable = true, facetable = false },
      { name = "Description", type = "Edm.String", retrievable = true, searchable = true, filterable = false, sortable = false, facetable = false, analyzer = "en.microsoft" },
      { name = "Description_fr", type = "Edm.String", retrievable = true, searchable = true, filterable = false, sortable = false, facetable = false, analyzer = "fr.microsoft" },
      {
        name   = "Address",
        type   = "Edm.ComplexType",
        fields = [
          { name = "StreetAddress", type = "Edm.String", retrievable = true, filterable = false, sortable = false, facetable = false, searchable = true },
          { name = "City", type = "Edm.String", retrievable = true, searchable = true, filterable = true, sortable = true, facetable = true },
          { name = "StateProvince", type = "Edm.String", retrievable = true, searchable = true, filterable = true, sortable = true, facetable = true }
        ]
      }
    ],
    suggesters      = [],
    scoringProfiles = [],
  })
}

resource "null_resource" "create_index" {
  depends_on = [
    azurerm_search_service.search,
    azurerm_role_assignment.search_index_data_contributor,
  ]

  triggers = {
    index_name   = var.index_name
    api_version  = var.api_version
    endpoint     = local.search_endpoint
    content_hash = sha256(local.hotels_index_definition)
  }

  provisioner "local-exec" {
    command = <<EOT
set -euo pipefail

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI (az) is required to create the search index with Entra ID authentication." >&2
  exit 1
fi

ACCESS_TOKEN=$(az account get-access-token --resource https://search.azure.com --query accessToken -o tsv)
if [ -z "$ACCESS_TOKEN" ]; then
  echo "Failed to obtain an access token for https://search.azure.com." >&2
  exit 1
fi

for attempt in $(seq 1 10); do
  if curl -sSf -X PUT \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    --data '${local.hotels_index_definition}' \
    "${local.search_endpoint}/indexes/${var.index_name}?api-version=${var.api_version}"; then
    exit 0
  fi

  echo "Index creation attempt ${attempt} failed. Waiting before retrying..." >&2
  sleep 10
done

echo "Failed to create or update the index after multiple attempts." >&2
exit 1
EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

output "index_create_endpoint" {
  value = "${local.search_endpoint}/indexes/${var.index_name}?api-version=${var.api_version}"
}
