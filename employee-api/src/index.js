// app.js - Node.js middleware application for Azure App Service
const express = require('express');
const { CosmosClient, CosmosClientOptions } = require('@azure/cosmos');
const { DefaultAzureCredential } = require('@azure/identity');

const app = express();
const port = process.env.PORT || 3000;

// Cosmos DB configuration (use environment variables in production)
const cosmosEndpoint = process.env.COSMOS_ENDPOINT || 'https://employee-cosmosdb.documents.azure.com:443/';
const databaseId = 'employeesdb'; // Your database ID
const containerId = 'employees'; // Your container ID

// Use Managed Identity for authentication
const credential = new DefaultAzureCredential();
const clientOptions: CosmosClientOptions = { endpoint: cosmosEndpoint, aadCredentials: credential };

// Create Cosmos client with Managed Identity
const cosmosClient = new CosmosClient(clientOptions);

// Middleware to handle JSON responses
app.use(express.json());

// GET /employees endpoint
app.get('/employees', async (req, res) => {
    try {
        const database = cosmosClient.database(databaseId);
        const container = database.container(containerId);

        // Query all employees (adjust query as needed)
        const querySpec = {
            query: 'SELECT * FROM c'
        };

        const { resources: employees } = await container.items.query(querySpec).fetchAll();

        res.status(200).json(employees);
    } catch (error) {
        console.error('Error querying Cosmos DB:', error);
        res.status(500).json({ error: 'Failed to retrieve employees' });
    }
});

// Start the server
app.listen(port, () => {
    console.log(`Server running on port ${port}`);
});
