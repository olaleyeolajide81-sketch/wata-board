#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

class SecurityAuditReporter {
  constructor() {
    this.reportData = {
      timestamp: new Date().toISOString(),
      project: 'Wata-Board',
      version: '1.0.0',
      summary: {
        totalTests: 0,
        passedTests: 0,
        failedTests: 0,
        criticalVulnerabilities: 0,
        highVulnerabilities: 0,
        mediumVulnerabilities: 0,
        lowVulnerabilities: 0,
        securityScore: 0
      },
      categories: {
        owasp: { tested: 0, passed: 0, failed: 0, vulnerabilities: [] },
        penetration: { tested: 0, passed: 0, failed: 0, vulnerabilities: [] },
        dependency: { tested: 0, passed: 0, failed: 0, vulnerabilities: [] },
        code: { tested: 0, passed: 0, failed: 0, vulnerabilities: [] },
        configuration: { tested: 0, passed: 0, failed: 0, vulnerabilities: [] }
      },
      recommendations: [],
      compliance: {
        owaspTop10: { compliant: false, issues: [] },
        gdpr: { compliant: false, issues: [] },
        pci: { compliant: false, issues: [] }
      }
    };
  }

  async generateReport() {
    console.log('📊 Generating comprehensive security audit report...\n');

    await this.collectTestResults();
    await this.collectVulnerabilityData();
    await this.analyzeCompliance();
    await this.generateRecommendations();
    await this.calculateSecurityScore();
    
    const report = this.createFinalReport();
    await this.saveReport(report);
    
    this.displaySummary(report);
    
    return report;
  }

  async collectTestResults() {
    console.log('📋 Collecting test results...');
    
    const testResults = {
      owasp: this.loadTestResults('../tests/owasp'),
      penetration: this.loadTestResults('../tests/penetration'),
      security: this.loadTestResults('../tests/security')
    };

    for (const [category, results] of Object.entries(testResults)) {
      if (results) {
        this.reportData.categories[category] = {
          tested: results.total || 0,
          passed: results.passed || 0,
          failed: results.failed || 0,
          vulnerabilities: results.vulnerabilities || []
        };
        
        this.reportData.summary.totalTests += results.total || 0;
        this.reportData.summary.passedTests += results.passed || 0;
        this.reportData.summary.failedTests += results.failed || 0;
      }
    }
  }

  loadTestResults(testPath) {
    const fullPath = path.resolve(__dirname, testPath);
    if (!fs.existsSync(fullPath)) {
      return null;
    }

    // Mock test results (in real implementation, parse actual test output)
    return {
      total: 45,
      passed: 38,
      failed: 7,
      vulnerabilities: [
        {
          id: 'OWASP-001',
          severity: 'high',
          title: 'Missing Input Validation',
          description: 'API endpoints lack proper input sanitization'
        },
        {
          id: 'OWASP-002',
          severity: 'medium',
          title: 'Insufficient Rate Limiting',
          description: 'Rate limiting thresholds are too permissive'
        }
      ]
    };
  }

  async collectVulnerabilityData() {
    console.log('🔍 Collecting vulnerability data...');
    
    const vulnerabilityReportPath = path.resolve(__dirname, '../reports/vulnerability-scan-report.json');
    
    if (fs.existsSync(vulnerabilityReportPath)) {
      const vulnData = JSON.parse(fs.readFileSync(vulnerabilityReportPath, 'utf8'));
      
      this.reportData.summary.criticalVulnerabilities = vulnData.severity?.critical || 0;
      this.reportData.summary.highVulnerabilities = vulnData.severity?.high || 0;
      this.reportData.summary.mediumVulnerabilities = vulnData.severity?.medium || 0;
      this.reportData.summary.lowVulnerabilities = vulnData.severity?.low || 0;
      
      // Categorize vulnerabilities
      if (vulnData.vulnerabilities) {
        vulnData.vulnerabilities.forEach(vuln => {
          const category = vuln.category || 'code';
          if (this.reportData.categories[category]) {
            this.reportData.categories[category].vulnerabilities.push(vuln);
          }
        });
      }
    }
  }

  async analyzeCompliance() {
    console.log('🔐 Analyzing compliance requirements...');
    
    // OWASP Top 10 Compliance
    const owaspIssues = [];
    
    if (this.reportData.summary.criticalVulnerabilities > 0) {
      owaspIssues.push('Critical vulnerabilities detected');
    }
    
    if (this.reportData.categories.owasp.failed > 0) {
      owaspIssues.push('OWASP security tests failed');
    }
    
    this.reportData.compliance.owasp = {
      compliant: owaspIssues.length === 0,
      issues: owaspIssues
    };
    
    // GDPR Compliance (simplified)
    const gdprIssues = [];
    
    if (this.reportData.categories.code.vulnerabilities.some(v => 
      v.title.includes('PII') || v.title.includes('personal data')
    )) {
      gdprIssues.push('Potential personal data exposure');
    }
    
    this.reportData.compliance.gdpr = {
      compliant: gdprIssues.length === 0,
      issues: gdprIssues
    };
    
    // PCI DSS Compliance (simplified for payment app)
    const pciIssues = [];
    
    if (!this.reportData.categories.owasp.vulnerabilities.some(v => 
      v.title.includes('encryption') || v.title.includes('PCI')
    )) {
      pciIssues.push('Payment card security measures not verified');
    }
    
    this.reportData.compliance.pci = {
      compliant: pciIssues.length === 0,
      issues: pciIssues
    };
  }

  async generateRecommendations() {
    console.log('💡 Generating security recommendations...');
    
    const recommendations = [];
    
    // Critical vulnerabilities
    if (this.reportData.summary.criticalVulnerabilities > 0) {
      recommendations.push({
        priority: 'critical',
        title: 'Address Critical Vulnerabilities Immediately',
        description: `Found ${this.reportData.summary.criticalVulnerabilities} critical vulnerabilities that require immediate attention`,
        actions: [
          'Review and patch critical security flaws',
          'Implement emergency security measures',
          'Consider temporarily disabling affected features'
        ]
      });
    }
    
    // High vulnerabilities
    if (this.reportData.summary.highVulnerabilities > 0) {
      recommendations.push({
        priority: 'high',
        title: 'Fix High-Risk Security Issues',
        description: `Found ${this.reportData.summary.highVulnerabilities} high-severity vulnerabilities`,
        actions: [
          'Update vulnerable dependencies',
          'Implement proper input validation',
          'Add authentication and authorization controls'
        ]
      });
    }
    
    // Failed tests
    if (this.reportData.summary.failedTests > 0) {
      recommendations.push({
        priority: 'medium',
        title: 'Fix Failed Security Tests',
        description: `${this.reportData.summary.failedTests} security tests are failing`,
        actions: [
          'Review failing test cases',
          'Implement missing security controls',
          'Update test configurations'
        ]
      });
    }
    
    // OWASP compliance
    if (!this.reportData.compliance.owasp.compliant) {
      recommendations.push({
        priority: 'high',
        title: 'Achieve OWASP Top 10 Compliance',
        description: 'Application does not meet OWASP Top 10 security standards',
        actions: [
          'Implement missing OWASP security controls',
          'Conduct comprehensive security assessment',
          'Establish security monitoring'
        ]
      });
    }
    
    // General security improvements
    recommendations.push({
      priority: 'medium',
      title: 'Implement Security Best Practices',
      description: 'General security improvements for long-term security posture',
      actions: [
        'Implement regular security scanning in CI/CD pipeline',
        'Add security headers and HTTPS enforcement',
        'Implement logging and monitoring',
        'Conduct regular security audits',
        'Train development team on secure coding practices'
      ]
    });
    
    this.reportData.recommendations = recommendations;
  }

  async calculateSecurityScore() {
    console.log('📈 Calculating security score...');
    
    let score = 100;
    
    // Deduct points for vulnerabilities
    score -= this.reportData.summary.criticalVulnerabilities * 25;
    score -= this.reportData.summary.highVulnerabilities * 15;
    score -= this.reportData.summary.mediumVulnerabilities * 8;
    score -= this.reportData.summary.lowVulnerabilities * 3;
    
    // Deduct points for failed tests
    score -= this.reportData.summary.failedTests * 2;
    
    // Deduct points for non-compliance
    if (!this.reportData.compliance.owasp.compliant) score -= 20;
    if (!this.reportData.compliance.gdpr.compliant) score -= 15;
    if (!this.reportData.compliance.pci.compliant) score -= 10;
    
    // Ensure score is within 0-100 range
    score = Math.max(0, Math.min(100, score));
    
    this.reportData.summary.securityScore = Math.round(score);
  }

  createFinalReport() {
    return {
      ...this.reportData,
      reportMetadata: {
        generatedBy: 'Wata-Board Security Audit System',
        reportVersion: '1.0.0',
        framework: 'OWASP Security Testing',
        scanDuration: 'Comprehensive Security Audit'
      },
      riskAssessment: {
        overallRisk: this.calculateRiskLevel(),
        riskFactors: this.identifyRiskFactors(),
        mitigationPriority: this.getMitigationPriority()
      }
    };
  }

  calculateRiskLevel() {
    const critical = this.reportData.summary.criticalVulnerabilities;
    const high = this.reportData.summary.highVulnerabilities;
    const score = this.reportData.summary.securityScore;
    
    if (critical > 0 || score < 30) return 'CRITICAL';
    if (high > 0 || score < 50) return 'HIGH';
    if (score < 70) return 'MEDIUM';
    if (score < 85) return 'LOW';
    return 'MINIMAL';
  }

  identifyRiskFactors() {
    const factors = [];
    
    if (this.reportData.summary.criticalVulnerabilities > 0) {
      factors.push('Critical security vulnerabilities present');
    }
    
    if (this.reportData.summary.highVulnerabilities > 2) {
      factors.push('Multiple high-severity vulnerabilities');
    }
    
    if (!this.reportData.compliance.owasp.compliant) {
      factors.push('Non-compliance with OWASP Top 10');
    }
    
    if (this.reportData.summary.failedTests > 5) {
      factors.push('Multiple failed security tests');
    }
    
    return factors;
  }

  getMitigationPriority() {
    const priorities = [];
    
    // Critical first
    if (this.reportData.summary.criticalVulnerabilities > 0) {
      priorities.push('IMMEDIATE: Patch critical vulnerabilities');
    }
    
    // High priority
    if (this.reportData.summary.highVulnerabilities > 0) {
      priorities.push('HIGH: Address high-severity security issues');
    }
    
    // Medium priority
    if (this.reportData.summary.failedTests > 0) {
      priorities.push('MEDIUM: Fix failing security tests');
    }
    
    // Low priority
    priorities.push('LOW: Implement general security improvements');
    
    return priorities;
  }

  async saveReport(report) {
    const reportsDir = path.resolve(__dirname, '../reports');
    
    if (!fs.existsSync(reportsDir)) {
      fs.mkdirSync(reportsDir, { recursive: true });
    }
    
    // Save JSON report
    const jsonReportPath = path.join(reportsDir, `security-audit-report-${Date.now()}.json`);
    fs.writeFileSync(jsonReportPath, JSON.stringify(report, null, 2));
    
    // Save HTML report
    const htmlReportPath = path.join(reportsDir, `security-audit-report-${Date.now()}.html`);
    const htmlContent = this.generateHTMLReport(report);
    fs.writeFileSync(htmlReportPath, htmlContent);
    
    // Save latest report
    const latestJsonPath = path.join(reportsDir, 'latest-security-report.json');
    const latestHtmlPath = path.join(reportsDir, 'latest-security-report.html');
    
    fs.writeFileSync(latestJsonPath, JSON.stringify(report, null, 2));
    fs.writeFileSync(latestHtmlPath, htmlContent);
    
    console.log(`📄 Reports saved:`);
    console.log(`  JSON: ${jsonReportPath}`);
    console.log(`  HTML: ${htmlReportPath}`);
  }

  generateHTMLReport(report) {
    return `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Wata-Board Security Audit Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; border-bottom: 2px solid #007bff; padding-bottom: 20px; margin-bottom: 30px; }
        .score { font-size: 48px; font-weight: bold; text-align: center; margin: 20px 0; }
        .score.critical { color: #dc3545; }
        .score.high { color: #fd7e14; }
        .score.medium { color: #ffc107; }
        .score.low { color: #28a745; }
        .section { margin: 30px 0; }
        .vulnerability { border: 1px solid #ddd; padding: 15px; margin: 10px 0; border-radius: 5px; }
        .critical { border-left: 5px solid #dc3545; }
        .high { border-left: 5px solid #fd7e14; }
        .medium { border-left: 5px solid #ffc107; }
        .low { border-left: 5px solid #28a745; }
        .recommendation { background: #f8f9fa; padding: 15px; margin: 10px 0; border-radius: 5px; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #007bff; color: white; }
        .status { padding: 4px 8px; border-radius: 3px; color: white; font-size: 12px; }
        .compliant { background: #28a745; }
        .non-compliant { background: #dc3545; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔒 Wata-Board Security Audit Report</h1>
            <p>Generated on ${new Date(report.timestamp).toLocaleString()}</p>
            <div class="score ${this.getScoreClass(report.summary.securityScore)}">
                Security Score: ${report.summary.securityScore}/100
            </div>
            <p><strong>Risk Level: ${report.riskAssessment.overallRisk}</strong></p>
        </div>

        <div class="section">
            <h2>📊 Executive Summary</h2>
            <table>
                <tr><th>Metric</th><th>Value</th></tr>
                <tr><td>Total Tests</td><td>${report.summary.totalTests}</td></tr>
                <tr><td>Passed Tests</td><td>${report.summary.passedTests}</td></tr>
                <tr><td>Failed Tests</td><td>${report.summary.failedTests}</td></tr>
                <tr><td>Critical Vulnerabilities</td><td>${report.summary.criticalVulnerabilities}</td></tr>
                <tr><td>High Vulnerabilities</td><td>${report.summary.highVulnerabilities}</td></tr>
                <tr><td>Medium Vulnerabilities</td><td>${report.summary.mediumVulnerabilities}</td></tr>
                <tr><td>Low Vulnerabilities</td><td>${report.summary.lowVulnerabilities}</td></tr>
            </table>
        </div>

        <div class="section">
            <h2>🔐 Compliance Status</h2>
            <table>
                <tr><th>Framework</th><th>Status</th><th>Issues</th></tr>
                <tr>
                    <td>OWASP Top 10</td>
                    <td><span class="status ${report.compliance.owasp.compliant ? 'compliant' : 'non-compliant'}">${report.compliance.owasp.compliant ? 'Compliant' : 'Non-Compliant'}</span></td>
                    <td>${report.compliance.owasp.issues.join(', ') || 'None'}</td>
                </tr>
                <tr>
                    <td>GDPR</td>
                    <td><span class="status ${report.compliance.gdpr.compliant ? 'compliant' : 'non-compliant'}">${report.compliance.gdpr.compliant ? 'Compliant' : 'Non-Compliant'}</span></td>
                    <td>${report.compliance.gdpr.issues.join(', ') || 'None'}</td>
                </tr>
                <tr>
                    <td>PCI DSS</td>
                    <td><span class="status ${report.compliance.pci.compliant ? 'compliant' : 'non-compliant'}">${report.compliance.pci.compliant ? 'Compliant' : 'Non-Compliant'}</span></td>
                    <td>${report.compliance.pci.issues.join(', ') || 'None'}</td>
                </tr>
            </table>
        </div>

        <div class="section">
            <h2>🚨 Vulnerabilities</h2>
            ${this.generateVulnerabilitiesHTML(report)}
        </div>

        <div class="section">
            <h2>💡 Recommendations</h2>
            ${this.generateRecommendationsHTML(report)}
        </div>

        <div class="section">
            <h2>📈 Risk Assessment</h2>
            <h3>Mitigation Priority:</h3>
            <ol>
                ${report.riskAssessment.mitigationPriority.map(priority => `<li>${priority}</li>`).join('')}
            </ol>
        </div>
    </div>
</body>
</html>`;
  }

  getScoreClass(score) {
    if (score < 30) return 'critical';
    if (score < 50) return 'high';
    if (score < 70) return 'medium';
    if (score < 85) return 'low';
    return 'low';
  }

  generateVulnerabilitiesHTML(report) {
    const allVulnerabilities = [];
    
    Object.values(report.categories).forEach(category => {
      if (category.vulnerabilities) {
        allVulnerabilities.push(...category.vulnerabilities);
      }
    });
    
    if (allVulnerabilities.length === 0) {
      return '<p>✅ No vulnerabilities found!</p>';
    }
    
    return allVulnerabilities.map(vuln => `
      <div class="vulnerability ${vuln.severity}">
        <h4>${vuln.title} [${vuln.severity.toUpperCase()}]</h4>
        <p>${vuln.description}</p>
        ${vuln.file ? `<p><strong>File:</strong> ${vuln.file}</p>` : ''}
        ${vuln.line ? `<p><strong>Line:</strong> ${vuln.line}</p>` : ''}
      </div>
    `).join('');
  }

  generateRecommendationsHTML(report) {
    return report.recommendations.map(rec => `
      <div class="recommendation">
        <h4>${rec.title} [${rec.priority.toUpperCase()}]</h4>
        <p>${rec.description}</p>
        <ul>
          ${rec.actions.map(action => `<li>${action}</li>`).join('')}
        </ul>
      </div>
    `).join('');
  }

  displaySummary(report) {
    console.log('\n🎯 Security Audit Summary');
    console.log('==========================');
    console.log(`Security Score: ${report.summary.securityScore}/100`);
    console.log(`Risk Level: ${report.riskAssessment.overallRisk}`);
    console.log(`Total Vulnerabilities: ${report.summary.criticalVulnerabilities + report.summary.highVulnerabilities + report.summary.mediumVulnerabilities + report.summary.lowVulnerabilities}`);
    console.log(`Critical: ${report.summary.criticalVulnerabilities}`);
    console.log(`High: ${report.summary.highVulnerabilities}`);
    console.log(`Medium: ${report.summary.mediumVulnerabilities}`);
    console.log(`Low: ${report.summary.lowVulnerabilities}`);
    console.log(`Test Results: ${report.summary.passedTests}/${report.summary.totalTests} passed`);
    
    console.log('\n🔧 Top Recommendations:');
    report.recommendations.slice(0, 3).forEach((rec, index) => {
      console.log(`${index + 1}. ${rec.title} (${rec.priority})`);
    });
    
    console.log('\n📊 Compliance Status:');
    console.log(`OWASP Top 10: ${report.compliance.owasp.compliant ? '✅ Compliant' : '❌ Non-Compliant'}`);
    console.log(`GDPR: ${report.compliance.gdpr.compliant ? '✅ Compliant' : '❌ Non-Compliant'}`);
    console.log(`PCI DSS: ${report.compliance.pci.compliant ? '✅ Compliant' : '❌ Non-Compliant'}`);
  }
}

// Run the reporter
if (require.main === module) {
  const reporter = new SecurityAuditReporter();
  reporter.generateReport().catch(console.error);
}

module.exports = SecurityAuditReporter;
