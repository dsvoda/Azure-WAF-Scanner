# Azure WAF Scanner - Quick Reference Guide

**Quick lookup for all 60 Azure Well-Architected Framework checks**

---

## Quick Stats

| Metric | Value |
|--------|-------|
| Total Checks | 60 |
| Critical Severity | 5 |
| High Severity | 42 |
| Medium Severity | 12 |
| Low Severity | 1 |

---

## Reliability (RE) - 10 Checks

Design for continuous functionality and rapid recovery from failures.

| ID | Title | Severity | Key Focus |
|----|-------|----------|-----------|
| **RE01** | Design for business requirements | High | SLA/SLO definitions, availability targets |
| **RE02** | Design for resilience | Critical | Multi-region, availability zones, redundancy |
| **RE03** | Design for recovery | Critical | Backup, disaster recovery, RTO/RPO |
| **RE04** | Design reliability testing | High | Chaos engineering, fault injection |
| **RE05** | Implement health modeling | High | Health probes, dependency mapping |
| **RE06** | Monitor application health | High | Application Insights, diagnostics |
| **RE07** | Design monitoring/alerting | High | Alert rules, notification channels |
| **RE08** | Build early detection | Medium | Anomaly detection, trending |
| **RE09** | Continuous improvement | Medium | Post-mortems, lessons learned |
| **RE10** | Respond to incidents | High | Runbooks, escalation procedures |

**Quick Win:** RE06 - Enable Application Insights for immediate visibility  
**Biggest Impact:** RE02 - Implement availability zones for critical workloads

---

## Security (SE) - 12 Checks

Protect workloads from threats while maintaining CIA (Confidentiality, Integrity, Availability).

| ID | Title | Severity | Key Focus |
|----|-------|----------|-----------|
| **SE01** | Establish security baseline | High | Defender for Cloud, policy framework |
| **SE02** | Maintain compliance | High | Regulatory standards, audit trails |
| **SE03** | Classify and label data | Medium | Data classification, sensitivity labels |
| **SE04** | Protect against code vulns | High | SAST/DAST, dependency scanning |
| **SE05** | Identity and access mgmt | Critical | MFA, RBAC, Entra ID integration |
| **SE06** | Network security | High | NSG, private endpoints, WAF |
| **SE07** | Encrypt data at-rest | Critical | Storage encryption, disk encryption |
| **SE08** | Encrypt data in-transit | Critical | TLS 1.2+, HTTPS enforcement |
| **SE09** | Protect secrets | Critical | Key Vault, managed identities |
| **SE10** | Monitor security events | High | Log Analytics, SIEM integration |
| **SE11** | Incident response | High | SOC procedures, playbooks |
| **SE12** | Backup for security | High | Immutable backups, retention |

**Quick Win:** SE09 - Move secrets to Key Vault  
**Biggest Impact:** SE05 - Enforce MFA and RBAC across all identities

**Critical Triad:** SE05, SE07, SE08, SE09 - These 4 protect your core assets

---

## Cost Optimization (CO) - 14 Checks

Maximize value while minimizing unnecessary expenses.

| ID | Title | Severity | Key Focus |
|----|-------|----------|-----------|
| **CO01** | Financial responsibility | High | Budgets, alerts, cost culture |
| **CO02** | Develop cost model | High | Forecasting, allocation model |
| **CO03** | Collect and review data | Medium | Cost analysis, spending trends |
| **CO04** | Set spending guardrails | High | Budgets, quotas, policies |
| **CO05** | Get best Azure rates | Medium | Reservations, savings plans |
| **CO06** | Optimize architecture | High | Right services, PaaS vs IaaS |
| **CO07** | Optimize components | High | Right-sizing, SKU selection |
| **CO08** | Optimize environments | Medium | Non-prod savings, auto-shutdown |
| **CO09** | Optimize flow costs | Medium | Data transfer, bandwidth |
| **CO10** | Optimize data costs | Medium | Storage tiering, lifecycle |
| **CO11** | Optimize code costs | Low | Efficient algorithms, caching |
| **CO12** | Optimize scaling | Medium | Autoscaling, capacity planning |
| **CO13** | Optimize personnel time | Low | Automation, tool efficiency |
| **CO14** | Conduct cost reviews | Medium | Regular reviews, accountability |

**Quick Win:** CO05 - Purchase reservations for stable workloads (30-70% savings)  
**Biggest Impact:** CO07 - Right-size VMs and databases

**Cost Cascade:** CO01 → CO02 → CO04 - Foundation for all cost optimization

---

## Operational Excellence (OE) - 12 Checks

Keep workloads running reliably with efficient operations.

| ID | Title | Severity | Key Focus |
|----|-------|----------|-----------|
| **OE01** | Team specializations | Medium | Roles, responsibilities, skills |
| **OE02** | Formalize operations | High | Runbooks, procedures, standards |
| **OE03** | Software development mgmt | High | Source control, branching strategy |
| **OE04** | Optimize dev/QA | Medium | CI/CD, automated testing |
| **OE05** | Infrastructure as Code | High | ARM/Bicep/Terraform, version control |
| **OE06** | Safe deployment practices | Critical | Blue-green, canary, rollback |
| **OE07** | Formalize provisioning | High | Standard templates, validation |
| **OE08** | Automate for efficiency | High | Automation accounts, scripts |
| **OE09** | Adopt modern practices | Medium | DevOps culture, agile methods |
| **OE10** | Loosely coupled architecture | High | Microservices, APIs, messaging |
| **OE11** | Design for automation | High | API-first, scriptable resources |
| **OE12** | Strengthen processes | Medium | Continuous improvement, metrics |

**Quick Win:** OE05 - Implement IaC for consistent deployments  
**Biggest Impact:** OE06 - Safe deployments prevent outages

**DevOps Core:** OE03, OE04, OE05, OE06 - Essential for modern operations

---

## Performance Efficiency (PE) - 12 Checks

Scale to meet demand efficiently without overprovisioning.

| ID | Title | Severity | Key Focus |
|----|-------|----------|-----------|
| **PE01** | Negotiate performance targets | High | SLA requirements, baselines |
| **PE02** | Continuously optimize | High | Performance monitoring, tuning |
| **PE03** | Select right services | High | Service selection, SKU sizing |
| **PE04** | Optimize network | High | CDN, caching, latency reduction |
| **PE05** | Design for scaling | High | Horizontal scaling, partitioning |
| **PE06** | Design horizontal scaling | High | Autoscale rules, scale units |
| **PE07** | Optimize code/infrastructure | Medium | Code profiling, query optimization |
| **PE08** | Optimize data performance | High | Indexing, caching, replication |
| **PE09** | Collect performance metrics | High | APM, custom metrics, logging |
| **PE10** | Test for performance | High | Load testing, stress testing |
| **PE11** | Capacity planning | Medium | Growth projections, resource planning |
| **PE12** | Conduct performance testing | High | Baseline tests, regression testing |

**Quick Win:** PE04 - Enable CDN for static content  
**Biggest Impact:** PE06 - Implement autoscaling for dynamic workloads

**Performance Pipeline:** PE01 → PE09 → PE10 → PE02 - Measure, test, optimize, repeat

---

## Common Failure Patterns

### Top 5 Failed Checks Across All Scans

1. **CO01** - No budgets or cost tracking (80% fail rate)
2. **SE09** - Secrets in code or config files (75% fail rate)
3. **RE02** - Single region deployments (70% fail rate)
4. **OE05** - Manual deployments, no IaC (65% fail rate)
5. **PE06** - No autoscaling configured (60% fail rate)

### Critical Failures That Need Immediate Attention

| Check | Why Critical | Immediate Action |
|-------|-------------|------------------|
| SE05 | No MFA = account takeover risk | Enable MFA for all users |
| SE07 | Unencrypted data = compliance violation | Enable storage encryption |
| RE03 | No backups = data loss risk | Configure Azure Backup |
| OE06 | No safe deployment = production outages | Implement blue-green |

---

## Severity Guide

### Critical (5 checks)
**Impact:** Security breach, data loss, complete service failure  
**Timeline:** Immediate action required (hours, not days)  
**Examples:** RE02, RE03, SE05, SE07, SE08, SE09, OE06

**Decision Rule:** If this fails, we lose data, get breached, or go completely offline

### High (42 checks)
**Impact:** Significant business disruption, compliance issues  
**Timeline:** Address in current sprint/cycle (days to weeks)  
**Examples:** Most checks across all pillars

**Decision Rule:** If this fails, customers notice or business is impacted

### Medium (12 checks)
**Impact:** Efficiency loss, increased cost or toil  
**Timeline:** Plan for next quarter (weeks to months)  
**Examples:** CO03, CO08, OE09, PE07

**Decision Rule:** If this fails, operations are harder or more expensive

### Low (1 check)
**Impact:** Minor optimization opportunity  
**Timeline:** Continuous improvement backlog  
**Examples:** CO11, CO13

**Decision Rule:** Nice to have, but not urgent

---

## Remediation Effort Guide

### High Effort (Architecture Changes)
**Time:** Weeks to months  
**Cost:** Significant (redesign, migration)  
**Examples:**
- RE02: Implement multi-region architecture
- SE06: Redesign network security
- PE05: Refactor for horizontal scaling

**Approach:** Plan as project, phased rollout, get executive buy-in

### Medium Effort (Configuration & New Services)
**Time:** Days to weeks  
**Cost:** Moderate (new services, configuration)  
**Examples:**
- CO02: Set up cost management
- SE01: Enable Defender for Cloud
- OE05: Implement IaC

**Approach:** Dedicated sprint, team effort, some training needed

### Low Effort (Settings & Policies)
**Time:** Hours to days  
**Cost:** Minimal (mostly time)  
**Examples:**
- CO01: Create budgets
- SE09: Move secrets to Key Vault
- OE02: Document runbooks

**Approach:** Quick wins, can be done by one person, immediate value

---

## Pillar Interdependencies

Some checks are more effective when combined:

```
Security + Cost:
├─ SE06 (Network Security) + CO09 (Flow Costs)
│  └─ Secure architecture that's also cost-efficient
│
Reliability + Performance:
├─ RE02 (Resilience) + PE05 (Scaling)
│  └─ Resilient AND performant architecture
│
Operations + All Pillars:
└─ OE05 (IaC) enables everything else
   ├─ Reliable deployments (RE)
   ├─ Consistent security (SE)
   ├─ Cost tracking via tags (CO)
   └─ Repeatable performance (PE)
```

---

## Check Execution Order

### Phase 1: Foundation (Week 1)
Start here - these enable everything else:
1. **SE01** - Security baseline
2. **CO01** - Financial awareness
3. **OE05** - Infrastructure as Code
4. **RE01** - Business requirements

### Phase 2: Core Implementation (Weeks 2-4)
Build on the foundation:
1. **SE05** - Identity/Access
2. **SE06** - Network security
3. **RE02** - Resilience
4. **CO04** - Cost guardrails
5. **PE05** - Scaling design

### Phase 3: Advanced (Weeks 5-8)
Mature practices:
1. **RE06** - Health monitoring
2. **SE10** - Security monitoring
3. **CO07** - Component optimization
4. **OE06** - Safe deployments
5. **PE09** - Performance metrics

### Phase 4: Optimization (Weeks 9-12)
Continuous improvement:
1. **RE09** - Improvement process
2. **CO14** - Cost reviews
3. **OE12** - Process strengthening
4. **PE02** - Continuous optimization

---

## Scan Interpretation

### Understanding Your Score

```
Overall Score: 75%

By Pillar:
Reliability:     85% ████████████████▓░░░  ← Good!
Security:        70% ██████████████░░░░░░  ← Needs work
Cost:            65% █████████████░░░░░░░  ← Priority
Operations:      80% ████████████████░░░░  ← Solid
Performance:     90% ██████████████████░░  ← Excellent!
```

**Score Interpretation:**
- **90-100%:** Excellent - maintain and minor tweaks
- **75-89%:** Good - targeted improvements
- **60-74%:** Fair - focused effort needed
- **< 60%:** Needs attention - prioritize this pillar

### Red Flags 🚩

Watch for these patterns:
- **Security < 70%:** Immediate risk, prioritize above all
- **Reliability < 70%:** Outage risk, customer impact likely
- **Multiple Critical failures:** Drop everything, fix these first
- **Trend declining:** Investigation needed, something changed

---

## Quick Commands

### Run specific checks
```powershell
# Security only
./run/Invoke-WafLocal.ps1 -ExcludedPillars @('CostOptimization','Reliability','PerformanceEfficiency','OperationalExcellence')

# Exclude low-impact checks
./run/Invoke-WafLocal.ps1 -ExcludedChecks @('CO11','CO13')

# High severity only (custom filter after scan)
$results | Where-Object Severity -in @('Critical','High')
```

### Generate reports
```powershell
# All formats
./run/Invoke-WafLocal.ps1 -EmitJson -EmitCsv -EmitHtml

# Compare to baseline
./run/Invoke-WafLocal.ps1 -BaselineFile "./baseline.json" -EmitHtml

# Multiple subscriptions
./run/Invoke-WafLocal.ps1 -Subscriptions @('sub1','sub2','sub3') -Parallel
```

---

## Compliance Mapping

### Quick Reference: Check to Standard

**CIS Azure Benchmark:**
- SE01-SE12: Most security controls
- OE02, OE05: Operational controls
- Coverage: ~85%

**NIST CSF:**
- SE: Protect pillar
- RE: Recover pillar
- OE: Detect pillar
- Coverage: ~90%

**SOC 2:**
- All pillars map to trust principles
- Strong coverage across all controls
- Coverage: ~95%

---

## Success Metrics

Track these KPIs:

| Metric | Target | Frequency |
|--------|--------|-----------|
| Overall Compliance | > 85% | Monthly |
| Critical Issues | 0 | Weekly |
| Security Score | > 90% | Weekly |
| Trend Direction | Improving | Quarterly |
| Mean Time to Remediate | < 30 days | Monthly |
| Repeat Failures | < 5% | Quarterly |

---

## Getting Help

### By Check Type

**Security Questions (SE01-SE12):**
- Microsoft Defender for Cloud docs
- Security team consultation
- Azure Security Benchmark

**Cost Questions (CO01-CO14):**
- Azure Cost Management docs
- Finance team review
- Azure Advisor recommendations

**All Other Questions:**
- Check-IDRegistry.md (detailed docs)
- Microsoft Learn (official guidance)
- GitHub Issues (community support)

---

## Cheat Sheet: First 24 Hours

**Hour 1: Setup**
```powershell
# Install scanner
git clone https://github.com/dsvoda/Azure-WAF-Scanner.git
cd Azure-WAF-Scanner

# Connect to Azure
Connect-AzAccount
```

**Hours 2-3: First Scan**
```powershell
# Run initial scan
./run/Invoke-WafLocal.ps1 -EmitHtml -EmitJson

# Review HTML report in browser
```

**Hours 4-8: Triage**
1. Review Critical issues (< 10 typically)
2. Review High issues in Security pillar
3. Create remediation plan
4. Assign owners

**Hours 9-16: Quick Wins**
1. Fix low-effort items (CO01 budget, SE09 secrets)
2. Document learnings
3. Plan bigger changes

**Hours 17-24: Automation**
1. Set up scheduled scans
2. Create baseline file
3. Configure alerts
4. Document process

---

## Print-Friendly Checklist

□ **Foundation Setup**
  □ SE01: Security baseline established
  □ CO01: Budgets configured
  □ OE05: IaC implemented
  □ RE01: Requirements documented

□ **Critical Security**
  □ SE05: MFA enabled for all users
  □ SE07: Encryption at rest enabled
  □ SE08: TLS 1.2+ enforced
  □ SE09: Secrets in Key Vault

□ **Reliability Essentials**
  □ RE02: Availability zones used
  □ RE03: Backups configured
  □ RE06: Monitoring enabled
  □ RE10: Incident runbooks ready

□ **Cost Control**
  □ CO04: Spending limits set
  □ CO05: Reservations purchased
  □ CO07: Resources right-sized

□ **Operations**
  □ OE06: Safe deployment process
  □ OE08: Key tasks automated

□ **Performance**
  □ PE06: Autoscaling configured
  □ PE09: Metrics collected

---

**Last Updated:** October 22, 2025  
**Document Version:** 1.0  
**For detailed information, see:** Check-IDRegistry.md
