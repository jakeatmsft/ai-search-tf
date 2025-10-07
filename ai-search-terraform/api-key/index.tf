# Creates a sample index named "hotels" on the Azure AI Search service using the REST API.
# Requires that the search service already exists from main.tf deployment.

variable "api_version" {
  type        = string
  description = "Azure Search REST API version"
  default     = "2024-07-01"
}

# API key for the Search service. Use either admin or query key; admin key required for index management.
# You can retrieve it after service creation with `az search admin-key show`.
variable "search_admin_key" {
  type        = string
  sensitive   = true
  description = "Admin API key for Azure AI Search service"
  default     = ""
}

# Optionally override index name
variable "index_name" {
  type        = string
  description = "Name of the index to create"
  default     = "hotels"
}

# Build endpoint URL for the search service
locals {
  search_service_name = azurerm_search_service.search.name
  search_endpoint     = "https://${local.search_service_name}.search.windows.net"
}

# Payload for the index definition as a JSON string
locals {
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
    suggesters       = [],
    scoringProfiles  = [],
  })
}

# Use a local-exec provisioner to call the REST API via curl.
# This resource will attempt to create the index; it is idempotent in that
# creating an already-existing index will result in an error; for simplicity,
# we use PUT to create or replace. If you prefer strict create, use POST.
resource "null_resource" "create_index" {
  depends_on = [azurerm_search_service.search]

  # Skip creating the index if no admin key is provided
  count = var.search_admin_key == "" ? 0 : 1

  triggers = {
    index_name   = var.index_name,
    api_version  = var.api_version,
    endpoint     = local.search_endpoint,
    content_hash = sha256(local.hotels_index_definition)
  }

  provisioner "local-exec" {
    command = <<EOT
curl -sSf -X POST \
  -H "Content-Type: application/json" \
  -H "api-key: $SEARCH_ADMIN_KEY" \
  --data '${local.hotels_index_definition}' \
  "${local.search_endpoint}/indexes?api-version=${var.api_version}"
EOT
    interpreter = ["/bin/bash", "-c"]
    environment = {
      SEARCH_ADMIN_KEY = var.search_admin_key
    }
  }
}

output "index_create_endpoint" {
  value = "${local.search_endpoint}/indexes?api-version=${var.api_version}"
}
