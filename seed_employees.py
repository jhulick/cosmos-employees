import os
import json
from azure.cosmos import CosmosClient, PartitionKey

# Read environment variables from Terraform local-exec
endpoint = os.environ["COSMOS_ENDPOINT"]
key      = os.environ["COSMOS_KEY"]
db_name  = os.environ["DATABASE_NAME"]
container_name = os.environ["CONTAINER_NAME"]

# Employees data (exactly as you provided)
employees = [
    {
        "id": "1",
        "image": "https://randomuser.me/api/portraits/women/90.jpg",
        "name": "Lisa Simpson",
        "department": "Sales",
        "email": "lissimp@email.com",
        "phone": "555-321-2345"
    },
    {
        "id": "2",
        "image": "https://randomuser.me/api/portraits/men/90.jpg",
        "name": "Troy McGibbons",
        "department": "Engineering",
        "email": "troydog@email.com",
        "phone": "555-012-3456"
    },
    {
        "id": "3",
        "image": "https://randomuser.me/api/portraits/women/77.jpg",
        "name": "Sandra Lopez",
        "department": "Design",
        "email": "salola@email.com",
        "phone": "555-456-7890"
    }
]

# Connect and seed
client = CosmosClient(endpoint, key)
database = client.get_database_client(db_name)
container = database.get_container_client(container_name)

print("Seeding employees into Cosmos DB...")

for emp in employees:
    try:
        container.upsert_item(emp)
        print(f"Upserted: {emp['name']} ({emp['id']})")
    except Exception as e:
        print(f"Error upserting {emp['name']}: {e}")

print("Seeding complete!")
