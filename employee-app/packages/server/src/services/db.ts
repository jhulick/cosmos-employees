// Import Cosmos SDK and task model
import { Container, CosmosClient, Database } from "@azure/cosmos";
import {Employee} from "../models/employee";

/**
 * This class provides a service for interacting with the Cosmos DB database.
 * It is a singleton class, so only one instance of it will ever exist.
 * @class
 * @property {CosmosClient} client - The Cosmos DB client
 * @property {any} database - The database
 * @property {any} container - The container
 * @method getEmployee - Get a employee by id
 * @method getEmployees - Get all employees
 */
export class DbService {
    private client: CosmosClient;
    private database: Database;
    private container: Container;

    // The singleton instance
    private static instance: DbService;

    // Get the singleton instance
    public static getInstance(): DbService {
        if (!DbService.instance) {
            DbService.instance = new DbService();
        }
        return DbService.instance;
    }

    constructor() {
        // Check that the environment variables are set
        if (!process.env.COSMOS_ENDPOINT) {
            throw new Error("COSMOS_ENDPOINT is not set");
        }
        if (!process.env.COSMOS_KEY) {
            throw new Error("COSMOS_KEY is not set");
        }

        // Connect to the database
        this.client = new CosmosClient({
            endpoint: process.env.COSMOS_ENDPOINT,
            key: process.env.COSMOS_KEY
        });
        this.database = this.client.database("employeesdb");
        this.container = this.database.container("employees");
    }

    // Get a employee by id
    async getEmployee(id: string): Promise<Employee> {
        // Get the employee from the database
        const { resource: task } = await this.container.item(id).read();

        // Return the task
        return task;
    }

    // Get all employees
    async getEmployees(): Promise<Employee[]> {
        // Get the employees from the database
        const { resources: tasks } = await this.container
            .items.query({
                query: "SELECT * FROM c"
            })
            .fetchAll();

        // Return the tasks
        return tasks;
    }
}