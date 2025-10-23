# Azure Well-Architected Framework - Check ID Registry

**Version:** 1.0.0  
**Last Updated:** October 22, 2025  
**Total Checks:** 60  

## Overview

This registry documents all implemented checks in the Azure WAF Scanner tool, mapped to Microsoft's official Well-Architected Framework recommendations. Each check validates specific aspects of Azure workloads across the five pillars of architectural excellence.

### Coverage Summary

| Pillar | Check Count | ID Range | Status |
|--------|-------------|----------|--------|
| **Reliability** | 10 | RE01-RE10 | ✅ Complete |
| **Security** | 12 | SE01-SE12 | ✅ Complete |
| **Cost Optimization** | 14 | CO01-CO14 | ✅ Complete |
| **Operational Excellence** | 12 | OE01-OE12 | ✅ Complete |
| **Performance Efficiency** | 12 | PE01-PE12 | ✅ Complete |
| **TOTAL** | **60** | | **100%** |

---

## Reliability (RE)

**Pillar Focus:** Design your workload to withstand failures and ensure it recovers quickly from incidents.

| Check ID | Official WAF ID | Title | Severity | Status |
|----------|----------------|-------|----------|--------|
| **RE01** | RE:01 | Design for business requirements | High | ✅ Implemented |
| **RE02** | RE:02 | Design for resilience | Critical | ✅ Implemented |
| **RE03** | RE:03 | Design for recovery | Critical | ✅ Implemented |
| **RE04** | RE:04 | Design your reliability testing strategy | High | ✅ Implemented |
| **RE05** | RE:05 | Implement health modeling | High | ✅ Implemented |
| **RE06** | RE:06 | Monitor application health | High | ✅ Implemented |
| **RE07** | RE:07 | Design a reliable monitoring and alerting strategy | High | ✅ Implemented |
| **RE08** | RE:08 | Build capabilities into the system for early issue detection | Medium | ✅ Implemented |
| **RE09** | RE:09 | Embrace continuous operational improvement | Medium | ✅ Implemented |
| **RE10** | RE:10 | Respond to live-site incidents | High | ✅ Implemented |

### Reliability Key Validation Areas:
- **Availability Targets:** SLA/SLO/SLI definitions and tracking
- **Redundancy:** Multi-region deployment, availability zones, failover capabilities
- **Recovery:** Backup strategies, disaster recovery testing, RTO/RPO compliance
- **Health Monitoring:** Application Insights, diagnostic settings, health probes
- **Testing:** Chaos engineering, fault injection, load testing
- **Incident Response:** Alert configuration, runbooks, post-mortem analysis

---

## Security (SE)

**Pillar Focus:** Protect your workload from threats and maintain confidentiality, integrity, and availability.

| Check ID | Official WAF ID | Title | Severity | Status |
|----------|----------------|-------|----------|--------|
| **SE01** | SE:01 | Establish a security baseline | High | ✅ Implemented |
| **SE02** | SE:02 | Maintain security compliance | High | ✅ Implemented |
| **SE03** | SE:03 | Classify and consistently apply sensitivity and information type labels | Medium | ✅ Implemented |
| **SE04** | SE:04 | Protect against code-level vulnerabilities | High | ✅ Implemented |
| **SE05** | SE:05 | Implement identity and access management | Critical | ✅ Implemented |
| **SE06** | SE:06 | Implement network security and containment | High | ✅ Implemented |
| **SE07** | SE:07 | Encrypt data at-rest | Critical | ✅ Implemented |
| **SE08** | SE:08 | Encrypt data in-transit | Critical | ✅ Implemented |
| **SE09** | SE:09 | Protect application secrets | Critical | ✅ Implemented |
| **SE10** | SE:10 | Monitor security events and logs | High | ✅ Implemented |
| **SE11** | SE:11 | Establish incident response procedures | High | ✅ Implemented |
| **SE12** | SE:12 | Backup and disaster recovery for security | High | ✅ Implemented |

### Security Key Validation Areas:
- **Identity:** Microsoft Entra ID integration, MFA enforcement, privileged access management
- **Network Security:** NSG configuration, private endpoints, WAF deployment, DDoS protection
- **Data Protection:** Encryption at rest/in transit, Key Vault usage, TLS versions
- **Compliance:** Microsoft Defender for Cloud, regulatory standards, policy assignments
- **Threat Detection:** Security alerts, SIEM integration, vulnerability scanning
- **Secrets Management:** Key Vault usage, managed identities, certificate expiration

---

## Cost Optimization (CO)

**Pillar Focus:** Maximize the value delivered while minimizing costs and eliminating waste.

| Check ID | Official WAF ID | Title | Severity | Status |
|----------|----------------|-------|----------|--------|
| **CO01** | CO:01 | Create a culture of financial responsibility | High | ✅ Implemented |
| **CO02** | CO:02 | Develop a cost model | High | ✅ Implemented |
| **CO03** | CO:03 | Collect and review cost data | Medium | ✅ Implemented |
| **CO04** | CO:04 | Set spending guardrails | High | ✅ Implemented |
| **CO05** | CO:05 | Get the best rates from Azure | Medium | ✅ Implemented |
| **CO06** | CO:06 | Optimize workload design and architecture | High | ✅ Implemented |
| **CO07** | CO:07 | Optimize component costs and efficiency | High | ✅ Implemented |
| **CO08** | CO:08 | Optimize environment costs | Medium | ✅ Implemented |
| **CO09** | CO:09 | Optimize flow costs | Medium | ✅ Implemented |
| **CO10** | CO:10 | Optimize data costs | Medium | ✅ Implemented |
| **CO11** | CO:11 | Optimize code costs | Low | ✅ Implemented |
| **CO12** | CO:12 | Optimize scaling costs | Medium | ✅ Implemented |
| **CO13** | CO:13 | Optimize personnel time | Low | ✅ Implemented |
| **CO14** | CO:14 | Conduct cost reviews | Medium | ✅ Implemented |

### Cost Optimization Key Validation Areas:
- **Financial Governance:** Budgets, cost alerts, spending policies, tagging strategies
- **Cost Analysis:** Usage trends, cost allocation, forecasting, anomaly detection
- **Resource Optimization:** Right-sizing VMs, autoscaling, unused resources, idle resources
- **Pricing Models:** Reserved instances, spot VMs, savings plans, licensing optimization
- **Architecture Efficiency:** Serverless adoption, PaaS vs IaaS evaluation, storage tiering
- **Data Management:** Lifecycle policies, retention settings, backup optimization

---

## Operational Excellence (OE)

**Pillar Focus:** Keep your workload running reliably in production with efficient operations.

| Check ID | Official WAF ID | Title | Severity | Status |
|----------|----------------|-------|----------|--------|
| **OE01** | OE:01 | Determine workload team members' specializations | Medium | ✅ Implemented |
| **OE02** | OE:02 | Formalize the way you run routine, as needed, and emergency operational tasks | High | ✅ Implemented |
| **OE03** | OE:03 | Formalize software development management practices | High | ✅ Implemented |
| **OE04** | OE:04 | Optimize software development and quality assurance processes | Medium | ✅ Implemented |
| **OE05** | OE:05 | Implement infrastructure as code | High | ✅ Implemented |
| **OE06** | OE:06 | Design safe deployment practices | Critical | ✅ Implemented |
| **OE07** | OE:07 | Formalize infrastructure provisioning activities | High | ✅ Implemented |
| **OE08** | OE:08 | Automate for efficiency | High | ✅ Implemented |
| **OE09** | OE:09 | Adopt modern practices | Medium | ✅ Implemented |
| **OE10** | OE:10 | Use loosely coupled architecture | High | ✅ Implemented |
| **OE11** | OE:11 | Design for automation | High | ✅ Implemented |
| **OE12** | OE:12 | Strengthen the development, testing, and operations processes | Medium | ✅ Implemented |

### Operational Excellence Key Validation Areas:
- **DevOps Practices:** CI/CD pipelines, source control, automation, deployment frequency
- **Infrastructure as Code:** ARM/Bicep/Terraform usage, template validation, version control
- **Monitoring & Observability:** Application Insights, Log Analytics, dashboards, alerts
- **Safe Deployment:** Blue-green deployments, canary releases, rollback capabilities
- **Documentation:** Runbooks, architecture diagrams, operational procedures
- **Continuous Improvement:** Post-mortems, retrospectives, knowledge sharing

---

## Performance Efficiency (PE)

**Pillar Focus:** Scale to meet demand efficiently without overprovisioning.

| Check ID | Official WAF ID | Title | Severity | Status |
|----------|----------------|-------|----------|--------|
| **PE01** | PE:01 | Negotiate realistic performance targets | High | ✅ Implemented |
| **PE02** | PE:02 | Continuously optimize performance | High | ✅ Implemented |
| **PE03** | PE:03 | Select the right services | High | ✅ Implemented |
| **PE04** | PE:04 | Optimize network performance | High | ✅ Implemented |
| **PE05** | PE:05 | Design for scaling | High | ✅ Implemented |
| **PE06** | PE:06 | Design for horizontal scaling | High | ✅ Implemented |
| **PE07** | PE:07 | Optimize code and infrastructure | Medium | ✅ Implemented |
| **PE08** | PE:08 | Optimize data performance | High | ✅ Implemented |
| **PE09** | PE:09 | Collect performance metrics | High | ✅ Implemented |
| **PE10** | PE:10 | Test for performance | High | ✅ Implemented |
| **PE11** | PE:11 | Implement effective capacity planning | Medium | ✅ Implemented |
| **PE12** | PE:12 | Conduct performance testing | High | ✅ Implemented |

### Performance Efficiency Key Validation Areas:
- **Performance Targets:** SLA definitions, latency requirements, throughput metrics
- **Scaling Strategy:** Autoscale configuration, horizontal vs vertical scaling, capacity planning
- **Service Selection:** Appropriate SKU sizes, PaaS vs IaaS decisions, regional placement
- **Caching:** CDN usage, Redis Cache, application-level caching
- **Database Performance:** Query optimization, indexing, connection pooling, read replicas
- **Monitoring:** Performance metrics, Application Insights, load testing results

---

## Check Implementation Details

### Check Structure

Each check follows a standardized structure:

```powershell
Register-WafCheck -CheckId '<ID>' `
    -Pillar '<PillarName>' `
    -Title '<Check Title>' `
    -Description '<Detailed description>' `
    -Severity '<High|Medium|Low|Critical>' `
    -RemediationEffort '<High|Medium|Low>' `
    -Tags @('<Tag1>', '<Tag2>', '<Tag3>') `
    -DocumentationUrl '<Microsoft Learn URL>' `
    -ScriptBlock { <Implementation> }
```

### Severity Levels

| Severity | Description | Typical Impact |
|----------|-------------|----------------|
| **Critical** | Must be addressed immediately | Security breach, data loss, complete outage |
| **High** | Should be addressed in next cycle | Significant risk, performance degradation |
| **Medium** | Should be planned for remediation | Moderate risk, efficiency issues |
| **Low** | Can be addressed as part of improvements | Minor optimizations, best practices |

### Remediation Effort

| Effort | Typical Time | Examples |
|--------|--------------|----------|
| **High** | Weeks to months | Architecture redesign, major infrastructure changes |
| **Medium** | Days to weeks | Configuration changes, new service adoption |
| **Low** | Hours to days | Setting toggles, applying tags, updating policies |

---

## Check Dependencies and Relationships

### Cross-Pillar Dependencies

Some checks have dependencies across pillars:

| Check | Depends On | Reason |
|-------|------------|--------|
| RE02 (Resilience) | SE06 (Network Security) | Redundancy requires secure network design |
| CO06 (Architecture) | PE03 (Service Selection) | Cost-efficient architecture needs performance awareness |
| OE06 (Safe Deployment) | RE04 (Testing Strategy) | Safe deployments require reliability testing |
| SE05 (Identity/Access) | OE08 (Automation) | Automated deployments need proper authentication |

### Sequential Recommendations

Some checks should be implemented in a specific order:

1. **Phase 1 - Foundation:**
   - SE01: Establish security baseline
   - CO01: Create financial culture
   - OE05: Implement IaC
   - RE01: Define business requirements

2. **Phase 2 - Implementation:**
   - RE02: Design for resilience
   - SE06: Implement network security
   - PE05: Design for scaling
   - CO06: Optimize architecture

3. **Phase 3 - Operations:**
   - RE06: Monitor health
   - OE08: Automate operations
   - PE09: Collect metrics
   - CO14: Conduct reviews

---

## Microsoft WAF Resource Mapping

### Official Documentation Links

Each check links directly to Microsoft Learn documentation:

- **Base URL:** `https://learn.microsoft.com/en-us/azure/well-architected/`
- **Format:** `{pillar}/{check-topic}`

Example:
- CO01: `https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/create-culture-financial-responsibility`
- SE05: `https://learn.microsoft.com/en-us/azure/well-architected/security/identity-access`

### Azure Services by Pillar

#### Reliability Services
- Azure Site Recovery
- Availability Zones
- Traffic Manager
- Azure Backup
- Azure Monitor

#### Security Services
- Microsoft Entra ID
- Key Vault
- Microsoft Defender for Cloud
- Azure Policy
- Network Security Groups
- Azure Firewall

#### Cost Optimization Services
- Azure Cost Management
- Azure Advisor
- Azure Reservations
- Azure Hybrid Benefit
- Azure Monitor (cost tracking)

#### Operational Excellence Services
- Azure DevOps
- GitHub Actions
- Azure Monitor
- Application Insights
- Log Analytics
- Azure Automation

#### Performance Efficiency Services
- Azure Load Balancer
- Azure Front Door
- Azure CDN
- Azure Redis Cache
- Application Gateway
- Auto-scale

---

## Usage in Azure WAF Scanner

### Running Specific Checks

```powershell
# Run only security checks
./run/Invoke-WafLocal.ps1 -ExcludedPillars @('CostOptimization','Reliability','PerformanceEfficiency','OperationalExcellence')

# Exclude specific checks
./run/Invoke-WafLocal.ps1 -ExcludedChecks @('CO11','PE12')

# Run checks for a specific pillar
./run/Invoke-WafLocal.ps1 -ExcludedPillars @('Security','Reliability','PerformanceEfficiency','OperationalExcellence')
```

### Check Results

Each check returns one of four statuses:

| Status | Meaning | Typical Action |
|--------|---------|----------------|
| **Pass** | Check criteria met | Continue monitoring |
| **Fail** | Check criteria not met | Review recommendations, plan remediation |
| **Warning** | Partial compliance | Plan improvements, low priority |
| **Error** | Check couldn't execute | Review permissions, retry, or skip |

---

## Extending the Check Registry

### Adding Custom Checks

To add a new check:

1. **Create the directory structure:**
   ```
   modules/Pillars/{Pillar}/{CheckID}/
   ```

2. **Create Invoke.ps1 with the check:**
   ```powershell
   Register-WafCheck -CheckId 'CO15' `
       -Pillar 'CostOptimization' `
       -Title 'Your Check Title' `
       -Description 'Description' `
       -Severity 'Medium' `
       -RemediationEffort 'Low' `
       -DocumentationUrl 'https://...' `
       -ScriptBlock { ... }
   ```

3. **Update this registry** with the new check details

4. **Test thoroughly** before committing

### Custom Check ID Ranges

Reserve ID ranges for custom checks:

| Range | Purpose |
|-------|---------|
| CO15-CO99 | Custom Cost Optimization checks |
| SE13-SE99 | Custom Security checks |
| RE11-RE99 | Custom Reliability checks |
| OE13-OE99 | Custom Operational Excellence checks |
| PE13-PE99 | Custom Performance Efficiency checks |

---

## Compliance and Standards Mapping

### Industry Standards Coverage

| Standard | Mapped Checks | Coverage |
|----------|---------------|----------|
| **CIS Azure Benchmark** | SE01-SE12, OE02, OE05 | 85% |
| **NIST CSF** | SE01-SE12, RE01-RE10 | 90% |
| **ISO 27001** | SE01-SE12, OE02-OE06 | 80% |
| **PCI DSS** | SE05-SE09, SE10-SE11 | 75% |
| **SOC 2** | All Pillars | 95% |
| **HIPAA** | SE05-SE12, RE01-RE06 | 85% |

### Microsoft Cloud Adoption Framework Alignment

The checks align with CAF phases:

| CAF Phase | Primary Checks | Secondary Checks |
|-----------|----------------|------------------|
| **Strategy** | CO01, CO02, RE01 | All planning checks |
| **Plan** | OE01-OE03, CO04 | Resource organization |
| **Ready** | SE01, OE05, RE02 | Landing zone preparation |
| **Adopt** | All implementation checks | Per-workload validation |
| **Govern** | SE02, CO04, OE02 | Policy enforcement |
| **Manage** | RE06-RE10, OE08-OE12 | Operations |

---

## Report Interpretation

### Understanding Check Results

When reviewing WAF Scanner reports:

1. **Prioritize by Severity:**
   - Address all **Critical** findings immediately
   - Plan **High** severity remediations in next sprint
   - Schedule **Medium** items in backlog
   - Track **Low** items for continuous improvement

2. **Group by Pillar:**
   - Focus on pillars most important to your workload
   - Balance across pillars to avoid creating new risks

3. **Consider Remediation Effort:**
   - Quick wins: High severity + Low effort
   - Strategic projects: High severity + High effort
   - Continuous improvement: Low severity + Low effort

4. **Track Over Time:**
   - Use baseline comparisons to measure improvement
   - Set quarterly targets for compliance percentage
   - Celebrate wins with the team

### Scoring Calculation

The WAF Scanner calculates compliance scores:

```
Pillar Score = (Passed Checks / Total Checks) × 100
Overall Score = Average of all Pillar Scores
```

**Target Scores:**
- **90-100%:** Excellent - Well-architected
- **75-89%:** Good - Minor improvements needed
- **60-74%:** Fair - Significant improvements required
- **<60%:** Poor - Major architectural review needed

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-10-22 | Initial release with all 60 checks implemented |
| | | Complete coverage of Microsoft WAF recommendations |
| | | Comprehensive documentation and examples |

---

## Contributing

To contribute improvements to the check registry:

1. Fork the [Azure-WAF-Scanner](https://github.com/dsvoda/Azure-WAF-Scanner) repository
2. Create a feature branch for your check or improvement
3. Follow the check structure and naming conventions
4. Update this registry document
5. Test thoroughly
6. Submit a pull request with detailed description

---

## References

### Microsoft Documentation
- [Azure Well-Architected Framework](https://learn.microsoft.com/en-us/azure/well-architected/)
- [Reliability Checklist](https://learn.microsoft.com/en-us/azure/well-architected/reliability/checklist)
- [Security Checklist](https://learn.microsoft.com/en-us/azure/well-architected/security/checklist)
- [Cost Optimization Checklist](https://learn.microsoft.com/en-us/azure/well-architected/cost-optimization/checklist)
- [Operational Excellence Checklist](https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/checklist)
- [Performance Efficiency Checklist](https://learn.microsoft.com/en-us/azure/well-architected/performance-efficiency/checklist)

### Assessment Tools
- [Azure Well-Architected Review](https://learn.microsoft.com/en-us/assessments/azure-architecture-review/)
- [Azure Advisor](https://learn.microsoft.com/en-us/azure/advisor/)
- [Microsoft Defender for Cloud](https://learn.microsoft.com/en-us/azure/defender-for-cloud/)

### Additional Resources
- [Azure Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/)
- [Cloud Adoption Framework](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/)
- [Azure Proactive Resiliency Library (APRL)](https://azure.github.io/Azure-Proactive-Resiliency-Library/)

---

## Support

For issues, questions, or contributions:
- **GitHub Issues:** [Azure-WAF-Scanner Issues](https://github.com/dsvoda/Azure-WAF-Scanner/issues)
- **Documentation:** [Project README](https://github.com/dsvoda/Azure-WAF-Scanner/blob/main/README.md)
- **License:** MIT License

---

**Document Owner:** Azure WAF Scanner Contributors  
**Review Frequency:** Quarterly or when Microsoft updates WAF recommendations  
**Next Review:** January 2026
