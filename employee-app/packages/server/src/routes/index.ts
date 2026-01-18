import express from 'express';
import { Employee } from '../models/employee';
import { DbService } from '../services/db';

const router = express.Router();

router.get('/', async function(req, res) {
    res.json({ message: 'server up' });
});

router.get('/employees', async function(req, res) {
    try {
        const employees: Employee[] = await DbService.getInstance().getEmployees();

        res.json(employees);
    } catch (error: any) {
        res.status(500).json({ error: error?.message || 'Internal server error' });
    }
});

router.get('/employees/:employeeId', async function(req, res) {
    try {
        const { employeeId } = req.params;

        const employee = await DbService.getInstance().getEmployee(employeeId);

        res.json(employee);
    } catch (error: any) {
        res.status(500).json({ error: error?.message || 'Internal server error' });
    }
});

export default router;