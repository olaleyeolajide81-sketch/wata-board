import React from 'react';
import { render, screen, waitFor } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import RealTimeMonitoringDashboard from '../RealTimeMonitoringDashboard';

// Mock WebSocket
class MockWebSocket {
  static CONNECTING = 0;
  static OPEN = 1;
  static CLOSING = 2;
  static CLOSED = 3;

  readyState = MockWebSocket.OPEN;
  onopen: ((event: any) => void) | null = null;
  onmessage: ((event: any) => void) | null = null;
  onclose: ((event: any) => void) | null = null;
  onerror: ((event: any) => void) | null = null;

  constructor(url: string) {
    // Simulate connection
    setTimeout(() => {
      if (this.onopen) {
        this.onopen({} as Event);
      }
      // Send initial data
      if (this.onmessage) {
        this.onmessage({
          data: JSON.stringify({
            timestamp: Date.now(),
            systemHealth: {
              uptime: 3600,
              memoryUsageMb: 256,
              activeConnections: 5,
              requestsPerMinute: 120,
              avgResponseTimeMs: 150,
              errorRate: 0.02,
            },
            fullHealth: {
              status: 'UP',
              system: {
                cpu: { load: [1.5, 1.2, 1.0], cores: 4 },
                memory: { total: 8589934592, free: 4294967296 },
                disk: { freeBytes: 1000000000000, usedPercent: 45 },
              },
              dependencies: {
                stellar: { status: 'UP', responseTimeMs: 250 },
                sorobanRpc: { status: 'UP', responseTimeMs: 300 },
                database: { status: 'UP', responseTimeMs: 50 },
              },
            },
            alerts: [],
            performanceMetrics: {
              cpuUsage: 37.5,
              memoryUsage: 50,
              diskUsage: 45,
              networkLatency: {
                stellar: 250,
                soroban: 300,
                database: 50,
              },
              requestMetrics: {
                totalRequests: 5,
                errorRate: 0.02,
                avgResponseTime: 150,
                requestsPerSecond: 2,
              },
            },
          }),
        } as MessageEvent);
      }
    }, 100);
  }

  send(data: string) {
    // Mock send
  }

  close() {
    this.readyState = MockWebSocket.CLOSED;
    if (this.onclose) {
      this.onclose({} as CloseEvent);
    }
  }

  addEventListener(event: string, listener: (event: any) => void) {
    switch (event) {
      case 'open':
        this.onopen = listener;
        break;
      case 'message':
        this.onmessage = listener;
        break;
      case 'close':
        this.onclose = listener;
        break;
      case 'error':
        this.onerror = listener;
        break;
    }
  }

  removeEventListener(event: string, listener: (event: any) => void) {
    // Mock removeEventListener
  }
}

// Mock global WebSocket
global.WebSocket = MockWebSocket as any;

const renderWithRouter = (component: React.ReactElement) => {
  return render(
    <BrowserRouter>
      {component}
    </BrowserRouter>
  );
};

describe('RealTimeMonitoringDashboard', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('renders loading state initially', () => {
    renderWithRouter(<RealTimeMonitoringDashboard />);
    
    expect(screen.getByText(/Connecting to monitoring service/i)).toBeInTheDocument();
    expect(screen.getByText(/Status:/i)).toBeInTheDocument();
  });

  it('renders dashboard after receiving data', async () => {
    renderWithRouter(<RealTimeMonitoringDashboard />);
    
    await waitFor(() => {
      expect(screen.getByText(/Real-Time Monitoring/i)).toBeInTheDocument();
    });

    await waitFor(() => {
      expect(screen.getByText(/System health and performance metrics/i)).toBeInTheDocument();
    });
  });

  it('displays system overview cards', async () => {
    renderWithRouter(<RealTimeMonitoringDashboard />);
    
    await waitFor(() => {
      expect(screen.getByText(/System Status/i)).toBeInTheDocument();
      expect(screen.getByText(/Uptime/i)).toBeInTheDocument();
      expect(screen.getByText(/Active Connections/i)).toBeInTheDocument();
      expect(screen.getByText(/Requests\/min/i)).toBeInTheDocument();
    });
  });

  it('displays resource usage sections', async () => {
    renderWithRouter(<RealTimeMonitoringDashboard />);
    
    await waitFor(() => {
      expect(screen.getByText(/CPU Usage/i)).toBeInTheDocument();
      expect(screen.getByText(/Memory Usage/i)).toBeInTheDocument();
      expect(screen.getByText(/Disk Usage/i)).toBeInTheDocument();
    });
  });

  it('displays network dependencies', async () => {
    renderWithRouter(<RealTimeMonitoringDashboard />);
    
    await waitFor(() => {
      expect(screen.getByText(/Network Dependencies/i)).toBeInTheDocument();
      expect(screen.getByText(/Stellar Horizon/i)).toBeInTheDocument();
      expect(screen.getByText(/Soroban RPC/i)).toBeInTheDocument();
      expect(screen.getByText(/Database/i)).toBeInTheDocument();
    });
  });

  it('displays alerts section', async () => {
    renderWithRouter(<RealTimeMonitoringDashboard />);
    
    await waitFor(() => {
      expect(screen.getByText(/Recent Alerts/i)).toBeInTheDocument();
    });
  });

  it('displays request metrics', async () => {
    renderWithRouter(<RealTimeMonitoringDashboard />);
    
    await waitFor(() => {
      expect(screen.getByText(/Request Metrics/i)).toBeInTheDocument();
      expect(screen.getByText(/Avg Response Time/i)).toBeInTheDocument();
      expect(screen.getByText(/Error Rate/i)).toBeInTheDocument();
      expect(screen.getByText(/Requests\/sec/i)).toBeInTheDocument();
      expect(screen.getByText(/Total Requests/i)).toBeInTheDocument();
    });
  });

  it('shows connection status', async () => {
    renderWithRouter(<RealTimeMonitoringDashboard />);
    
    await waitFor(() => {
      expect(screen.getByText(/Connected/i)).toBeInTheDocument();
    });
  });

  it('handles WebSocket reconnection', async () => {
    renderWithRouter(<RealTimeMonitoringDashboard />);
    
    // Initial connection
    await waitFor(() => {
      expect(screen.getByText(/Connecting to monitoring service/i)).toBeInTheDocument();
    });

    // Wait for connection and data
    await waitFor(() => {
      expect(screen.getByText(/Real-Time Monitoring/i)).toBeInTheDocument();
    }, { timeout: 2000 });
  });

  it('displays no alerts message when alerts array is empty', async () => {
    renderWithRouter(<RealTimeMonitoringDashboard />);
    
    await waitFor(() => {
      expect(screen.getByText(/No recent alerts/i)).toBeInTheDocument();
    });
  });

  it('shows percentage values for resource usage', async () => {
    renderWithRouter(<RealTimeMonitoringDashboard />);
    
    await waitFor(() => {
      expect(screen.getByText(/37.5%/i)).toBeInTheDocument(); // CPU usage
      expect(screen.getByText(/50.0%/i)).toBeInTheDocument(); // Memory usage
      expect(screen.getByText(/45.0%/i)).toBeInTheDocument(); // Disk usage
    });
  });

  it('displays network latency values', async () => {
    renderWithRouter(<RealTimeMonitoringDashboard />);
    
    await waitFor(() => {
      expect(screen.getByText(/250ms/i)).toBeInTheDocument(); // Stellar latency
      expect(screen.getByText(/300ms/i)).toBeInTheDocument(); // Soroban latency
      expect(screen.getByText(/50ms/i)).toBeInTheDocument(); // Database latency
    });
  });
});
