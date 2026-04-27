import { realTimeMonitoringService } from '../services/realTimeMonitoringService';
import { metricsCollector } from '../middleware/metrics';
import { HealthService } from '../utils/health';

// Mock dependencies
jest.mock('../middleware/metrics');
jest.mock('../utils/health');
jest.mock('../utils/logger');

describe('RealTimeMonitoringService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('getRecentAlerts', () => {
    it('should return recent alerts', () => {
      const alerts = realTimeMonitoringService.getRecentAlerts(10);
      expect(Array.isArray(alerts)).toBe(true);
    });
  });

  describe('resolveAlert', () => {
    it('should resolve an alert by ID', () => {
      const alertId = 'test-alert-id';
      expect(() => {
        realTimeMonitoringService.resolveAlert(alertId);
      }).not.toThrow();
    });
  });

  describe('updateThresholds', () => {
    it('should update monitoring thresholds', () => {
      const newThresholds = {
        cpuUsage: 85,
        memoryUsage: 90,
        diskUsage: 95,
        errorRate: 0.15,
        responseTime: 6000,
        networkLatency: 12000,
      };

      expect(() => {
        realTimeMonitoringService.updateThresholds(newThresholds);
      }).not.toThrow();

      const updatedThresholds = realTimeMonitoringService.getThresholds();
      expect(updatedThresholds.cpuUsage).toBe(85);
    });
  });

  describe('getThresholds', () => {
    it('should return current thresholds', () => {
      const thresholds = realTimeMonitoringService.getThresholds();
      expect(thresholds).toHaveProperty('cpuUsage');
      expect(thresholds).toHaveProperty('memoryUsage');
      expect(thresholds).toHaveProperty('diskUsage');
      expect(thresholds).toHaveProperty('errorRate');
      expect(thresholds).toHaveProperty('responseTime');
      expect(thresholds).toHaveProperty('networkLatency');
    });
  });

  describe('getConnectedClientsCount', () => {
    it('should return number of connected clients', () => {
      const count = realTimeMonitoringService.getConnectedClientsCount();
      expect(typeof count).toBe('number');
      expect(count).toBeGreaterThanOrEqual(0);
    });
  });

  describe('stop', () => {
    it('should stop the monitoring service', () => {
      expect(() => {
        realTimeMonitoringService.stop();
      }).not.toThrow();
    });
  });
});
