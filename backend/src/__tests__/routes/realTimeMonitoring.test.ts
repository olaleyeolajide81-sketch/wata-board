import request from 'supertest';
import express from 'express';
import realTimeMonitoringRoutes from '../../routes/realTimeMonitoring';

// Mock the real-time monitoring service
jest.mock('../../services/realTimeMonitoringService', () => ({
  __esModule: true,
  default: {
    getRecentAlerts: jest.fn().mockReturnValue([]),
    resolveAlert: jest.fn(),
    updateThresholds: jest.fn(),
    getThresholds: jest.fn().mockReturnValue({
      cpuUsage: 80,
      memoryUsage: 85,
      diskUsage: 90,
      errorRate: 0.1,
      responseTime: 5000,
      networkLatency: 10000,
    }),
    getConnectedClientsCount: jest.fn().mockReturnValue(0),
  },
}));

describe('Real-time Monitoring Routes', () => {
  let app: express.Application;

  beforeEach(() => {
    app = express();
    app.use(express.json());
    app.use('/api/real-time-monitoring', realTimeMonitoringRoutes);
  });

  describe('GET /api/real-time-monitoring/metrics', () => {
    it('should return monitoring metrics', async () => {
      const response = await request(app)
        .get('/api/real-time-monitoring/metrics')
        .expect(200);

      expect(response.body).toHaveProperty('success', true);
      expect(response.body).toHaveProperty('data');
      expect(response.body.data).toHaveProperty('connectedClients');
      expect(response.body.data).toHaveProperty('thresholds');
      expect(response.body.data).toHaveProperty('recentAlerts');
    });
  });

  describe('GET /api/real-time-monitoring/alerts', () => {
    it('should return recent alerts', async () => {
      const response = await request(app)
        .get('/api/real-time-monitoring/alerts')
        .expect(200);

      expect(response.body).toHaveProperty('success', true);
      expect(response.body).toHaveProperty('data');
      expect(Array.isArray(response.body.data)).toBe(true);
    });

    it('should respect limit parameter', async () => {
      const response = await request(app)
        .get('/api/real-time-monitoring/alerts?limit=5')
        .expect(200);

      expect(response.body).toHaveProperty('success', true);
      expect(response.body).toHaveProperty('data');
    });
  });

  describe('POST /api/real-time-monitoring/alerts/:alertId/resolve', () => {
    it('should resolve an alert', async () => {
      const response = await request(app)
        .post('/api/real-time-monitoring/alerts/test-alert-id/resolve')
        .expect(200);

      expect(response.body).toHaveProperty('success', true);
      expect(response.body).toHaveProperty('message', 'Alert resolved successfully');
    });
  });

  describe('PUT /api/real-time-monitoring/thresholds', () => {
    it('should update thresholds', async () => {
      const newThresholds = {
        cpuUsage: 85,
        memoryUsage: 90,
        diskUsage: 95,
        errorRate: 0.15,
        responseTime: 6000,
        networkLatency: 12000,
      };

      const response = await request(app)
        .put('/api/real-time-monitoring/thresholds')
        .send(newThresholds)
        .expect(200);

      expect(response.body).toHaveProperty('success', true);
      expect(response.body).toHaveProperty('message', 'Thresholds updated successfully');
      expect(response.body).toHaveProperty('data');
    });

    it('should validate threshold values', async () => {
      const invalidThresholds = {
        cpuUsage: 150, // Invalid: > 100
        memoryUsage: -10, // Invalid: < 0
      };

      const response = await request(app)
        .put('/api/real-time-monitoring/thresholds')
        .send(invalidThresholds)
        .expect(200);

      expect(response.body).toHaveProperty('success', true);
      // Values should be clamped to valid ranges
      expect(response.body.data.cpuUsage).toBe(100);
      expect(response.body.data.memoryUsage).toBe(0);
    });
  });

  describe('GET /api/real-time-monitoring/thresholds', () => {
    it('should return current thresholds', async () => {
      const response = await request(app)
        .get('/api/real-time-monitoring/thresholds')
        .expect(200);

      expect(response.body).toHaveProperty('success', true);
      expect(response.body).toHaveProperty('data');
      expect(response.body.data).toHaveProperty('cpuUsage');
      expect(response.body.data).toHaveProperty('memoryUsage');
      expect(response.body.data).toHaveProperty('diskUsage');
      expect(response.body.data).toHaveProperty('errorRate');
      expect(response.body.data).toHaveProperty('responseTime');
      expect(response.body.data).toHaveProperty('networkLatency');
    });
  });

  describe('GET /api/real-time-monitoring/status', () => {
    it('should return monitoring status', async () => {
      const response = await request(app)
        .get('/api/real-time-monitoring/status')
        .expect(200);

      expect(response.body).toHaveProperty('success', true);
      expect(response.body).toHaveProperty('data');
      expect(response.body.data).toHaveProperty('active', true);
      expect(response.body.data).toHaveProperty('connectedClients');
      expect(response.body.data).toHaveProperty('uptime');
      expect(response.body.data).toHaveProperty('timestamp');
    });
  });
});
