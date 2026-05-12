# Case Management & Escalation Dashboard with Agentforce Agent

## Introduction

This project delivers a comprehensive Case Management & Escalation solution for support teams, combining a Lightning Web Component dashboard with an Agentforce agent that proactively surfaces insights. The solution enables support agents to view their full open case queue with key service health indicators including case priority, days open, SLA breach proximity, escalation status, and last customer response date.

The Agentforce agent proactively analyzes the case queue to highlight cases at risk of breaching SLA, cases with no agent response in 24+ hours, and cases showing resolution momentum. The agent summarizes queue trends, flags anomalies (e.g., no update in 48+ hours on a high-priority case), and provides a clear snapshot of what needs immediate attention versus what is progressing — without requiring the support agent to ask.

The solution supports both Apex and Flow implementations, ensuring flexibility for developer-heavy teams and admin-heavy teams across different org setups. All Apex code will include comprehensive test coverage (75%+ code coverage) to ensure quality and maintainability.

## Requirements

### 1. Code Quality Validation

**User Story:**
As a development team lead, I want all Apex code in the org to have comprehensive test coverage so that we maintain code quality standards and can deploy to production with confidence.

**Acceptance Criteria:**
- Every Apex class (excluding test classes) must have a corresponding test class
- Test classes must achieve at least 75% code coverage for the classes they test
- Test classes must follow naming convention: [ClassName]Test (e.g., CaseQueueController → CaseQueueControllerTest)
- All Apex triggers must have corresponding test classes that cover all trigger contexts (before insert, after insert, before update, after update, etc.)
- Test classes must include positive test cases, negative test cases, and bulk test cases (200+ records)
- Current org status: All 4 existing managed package Apex classes have test coverage ✓

### 2. Case Queue Dashboard Data Model

**User Story:**
As a support agent, I want to see all my open cases with key service health indicators in one dashboard so that I can quickly understand my workload and prioritize effectively.

**Acceptance Criteria:**
- Use the standard **Case** object (no new custom objects required)
- Dashboard displays cases where OwnerId = current user AND IsClosed = false
- Display the following fields for each case:
  - Case Number
  - Subject
  - Priority (High, Medium, Low)
  - Status
  - Days Open (calculated from CreatedDate to today)
  - SLA Breach Proximity (calculated from SlaStartDate and SlaExitDate)
  - Escalation Status (IsEscalated field)
  - Last Customer Response Date (LastModifiedDate when LastModifiedBy is a contact/customer)
  - Account Name (related Account)
- Cases are sorted by priority (High first) and then by Days Open (oldest first)
- Dashboard refreshes automatically every 5 minutes or on manual refresh

### 3. Case Queue Dashboard UI Component

**User Story:**
As a support agent, I want an intuitive Lightning Web Component dashboard that displays my case queue with visual indicators so that I can quickly identify cases that need immediate attention.

**Acceptance Criteria:**
- Create a Lightning Web Component named **caseManagementDashboard**
- Dashboard displays cases in a responsive data table with sortable columns
- Visual indicators:
  - Red badge for cases with SLA breach risk (within 24 hours of SLA deadline)
  - Orange badge for escalated cases (IsEscalated = true)
  - Yellow badge for cases with no agent response in 24+ hours
  - Green badge for cases showing resolution momentum (status changed to "In Progress" or "Pending Customer" in last 48 hours)
- Dashboard includes summary metrics at the top:
  - Total Open Cases
  - Cases at SLA Risk (count)
  - Escalated Cases (count)
  - Cases Needing Response (count)
- Dashboard includes a refresh button and displays last refresh timestamp
- Dashboard is responsive and works on desktop and mobile devices

### 4. Case Queue Controller - Apex Implementation

**User Story:**
As a developer, I want an Apex class that retrieves case queue data and calculates service health indicators so that the LWC dashboard can display real-time case information.

**Acceptance Criteria:**
- Create an Apex class named **CaseQueueController** with @AuraEnabled methods
- Method: `getOpenCases()` returns List<CaseWrapper> for current user's open cases
- CaseWrapper includes: caseId, caseNumber, subject, priority, status, daysOpen, slaDaysRemaining, isEscalated, lastCustomerResponseDate, accountName, needsResponse, hasResolutionMomentum, slaRiskLevel
- Method: `getQueueSummary()` returns summary metrics (total open, SLA risk count, escalated count, needs response count)
- Method: `getCaseInsights()` returns proactive insights (cases at risk, stale cases, trending cases)
- All methods use `WITH SECURITY_ENFORCED` or Security.stripInaccessible() for field-level security
- All SOQL queries are bulkified and optimized (no queries in loops)
- Create corresponding test class **CaseQueueControllerTest** with 75%+ coverage
- Test class includes: positive tests, negative tests, bulk tests (200+ records), security tests

### 5. Case Queue Logic - Flow Implementation

**User Story:**
As a Salesforce admin, I want a Flow-based alternative to retrieve case queue data so that I can maintain the solution without requiring developer resources.

**Acceptance Criteria:**
- Create an autolaunched Flow named **Case_Queue_Data_Retrieval**
- Flow accepts input variable: userId (Text)
- Flow returns output variable: caseList (Record Collection of Cases)
- Flow uses Get Records element to query Cases where OwnerId = userId AND IsClosed = false
- Flow calculates Days Open using formula: TODAY() - CreatedDate
- Flow calculates SLA Days Remaining using formula: SlaExitDate - TODAY()
- Flow determines if case needs response by checking if LastModifiedBy is not the current user and LastModifiedDate > 24 hours ago
- Flow determines resolution momentum by checking if Status changed to "In Progress" or "Pending Customer" in last 48 hours
- Flow is invocable from Apex or LWC via Flow.Interview.createInterview()
- Create a second autolaunched Flow named **Case_Queue_Summary_Calculation** that calculates summary metrics

### 6. Agentforce Agent Configuration

**User Story:**
As a support agent, I want an Agentforce agent that proactively surfaces insights about my case queue so that I understand my workload without having to ask specific questions.

**Acceptance Criteria:**
- Create an Agentforce agent named **Case Queue Insights Agent**
- Agent uses Agent Script (agentScript element) for deterministic behavior
- Agent proactively surfaces insights when the dashboard loads (no user prompt required)
- Agent provides the following insights:
  - **SLA Breach Risks**: List of cases within 24 hours of SLA deadline, sorted by urgency
  - **Stale Cases**: Cases with no update in 48+ hours on high-priority cases, 72+ hours on medium-priority
  - **Resolution Momentum**: Cases that have progressed in status in the last 48 hours
  - **Queue Trends**: Summary of case volume trends (increasing, decreasing, stable)
  - **Anomaly Detection**: Flags unusual patterns (e.g., high-priority case with no update in 48+ hours)
- Agent provides a clear snapshot: "Immediate Attention" section vs. "Progressing" section
- Agent updates insights automatically when dashboard refreshes

### 7. Agentforce Agent Actions - Apex Implementation

**User Story:**
As a developer, I want Apex-based agent actions that the Agentforce agent can invoke to retrieve case insights so that the agent can provide proactive recommendations.

**Acceptance Criteria:**
- Create Apex class **CaseInsightsActions** with @InvocableMethod annotations
- Method: `getSLABreachRisks()` returns cases within 24 hours of SLA deadline
- Method: `getStaleCases()` returns cases with no update in 48+ hours (high priority) or 72+ hours (medium priority)
- Method: `getResolutionMomentum()` returns cases that progressed in status in last 48 hours
- Method: `getQueueTrends()` returns case volume trends (comparing last 7 days to previous 7 days)
- Method: `detectAnomalies()` returns cases with unusual patterns (high priority + no update in 48+ hours)
- Each method returns a structured response with case details and insight summary
- Create corresponding test class **CaseInsightsActionsTest** with 75%+ coverage
- Create GenAiFunction elements for each action (e.g., Get_SLA_Breach_Risks, Get_Stale_Cases, etc.)
- Create GenAiPlugin (topic) named **Case_Queue_Insights** that groups all actions

### 8. Agentforce Agent Actions - Flow Implementation

**User Story:**
As a Salesforce admin, I want Flow-based agent actions that the Agentforce agent can invoke so that I can maintain the agent logic without requiring developer resources.

**Acceptance Criteria:**
- Create autolaunched Flow **Agent_Action_SLA_Breach_Risks** that returns cases within 24 hours of SLA deadline
- Create autolaunched Flow **Agent_Action_Stale_Cases** that returns cases with no update in 48+ hours (high priority) or 72+ hours (medium priority)
- Create autolaunched Flow **Agent_Action_Resolution_Momentum** that returns cases that progressed in status in last 48 hours
- Create autolaunched Flow **Agent_Action_Queue_Trends** that calculates case volume trends
- Create autolaunched Flow **Agent_Action_Detect_Anomalies** that identifies cases with unusual patterns
- Each Flow accepts input variable: userId (Text)
- Each Flow returns output variable: insightData (Text or Record Collection)
- Flows are invocable from Agentforce agent via GenAiFunction elements
- Create GenAiFunction elements for each Flow-based action
- GenAiFunction elements reference the Flow API names in InvocationTarget field

### 9. Dashboard App Page and Navigation

**User Story:**
As a support agent, I want to access the Case Management Dashboard from the main navigation so that I can quickly view my case queue from anywhere in Salesforce.

**Acceptance Criteria:**
- Create a Lightning App Page named **Case_Management_Dashboard**
- App page contains a single region with the **caseManagementDashboard** LWC component
- Create a custom tab named **Case Dashboard** that points to the app page
- Add the custom tab to a custom application named **Support Agent Console**
- Custom application includes the Case Dashboard tab, Cases tab, and Accounts tab
- Dashboard is accessible from the app launcher and navigation bar
- Dashboard displays the Agentforce agent insights panel alongside the case queue table

### 10. Permission Set for Support Agents

**User Story:**
As a system administrator, I want a permission set that grants support agents access to the Case Management Dashboard and all related components so that I can easily assign permissions to the support team.

**Acceptance Criteria:**
- Create a permission set named **Case_Management_Dashboard_Access**
- Permission set grants access to:
  - Custom application: Support Agent Console
  - Custom tab: Case Dashboard
  - Lightning App Page: Case_Management_Dashboard
  - LWC component: caseManagementDashboard
  - Apex classes: CaseQueueController, CaseInsightsActions (if using Apex implementation)
  - Flows: All Case Queue and Agent Action flows (if using Flow implementation)
  - GenAiPlugin: Case_Queue_Insights
  - GenAiFunction: All agent action functions
- Permission set grants Read access to Case object and all fields used in the dashboard
- Permission set grants Read access to Account object (for Account Name display)
- Permission set does not grant Create, Edit, or Delete permissions on Cases (view-only dashboard)

## Special Requirements

### Dual Implementation Support

The solution must support both Apex and Flow implementations to accommodate different org setups:

- **Apex Implementation**: For developer-heavy teams that prefer programmatic control, performance optimization, and complex business logic. All Apex classes must have corresponding test classes with 75%+ coverage.
- **Flow Implementation**: For admin-heavy teams that prefer declarative configuration and easier maintenance without code deployments.
- **Hybrid Approach**: Teams can mix and match — use Apex for dashboard controller and Flow for agent actions, or vice versa.
- The architecture should clearly document which components are Apex-based vs. Flow-based, and provide guidance on when to choose each approach.

### Performance Considerations

- Dashboard should load within 3 seconds for case queues up to 500 cases
- SOQL queries must be optimized with selective filters (indexed fields like OwnerId, IsClosed)
- Use pagination if case queue exceeds 100 cases (display 50 cases per page)
- Agentforce agent insights should calculate within 2 seconds
- Dashboard refresh should not block user interaction (use asynchronous loading)

### Security and Compliance

- All Apex code must enforce field-level security using `WITH SECURITY_ENFORCED` or `Security.stripInaccessible()`
- Dashboard respects user's Case object permissions (if user cannot read Cases, show appropriate error message)
- Agentforce agent only surfaces insights for cases the user has access to
- No sensitive case data (e.g., case descriptions with PII) should be exposed in agent insights without proper masking

## Glossary

- **SLA (Service Level Agreement)**: A commitment between a service provider and a customer that defines the expected level of service, including response time and resolution time.
- **SLA Breach**: When a case exceeds the defined SLA deadline without being resolved or responded to.
- **SLA Breach Proximity**: The time remaining until a case breaches its SLA (e.g., "2 hours remaining").
- **Escalated Case**: A case marked as escalated (IsEscalated = true), typically indicating higher urgency or complexity.
- **Stale Case**: A case with no updates or activity for an extended period (48+ hours for high priority, 72+ hours for medium priority).
- **Resolution Momentum**: Cases that have progressed in status recently (e.g., moved to "In Progress" or "Pending Customer" in last 48 hours), indicating active work toward resolution.
- **Case Queue**: The collection of open cases assigned to a specific support agent (OwnerId = current user).
- **Agentforce Agent**: An AI-powered agent built with Salesforce Agentforce that can proactively surface insights and perform actions.
- **Agent Script**: Salesforce's language for building deterministic Agentforce agents, combining natural language instructions with programmatic expressions.
- **GenAiFunction**: An agent action that can be invoked by an Agentforce agent, calling either an Apex class or a Flow.
- **GenAiPlugin**: An agent topic that categorizes related actions for Agentforce agents.

## Existing Salesforce Elements

### Case Object

The standard Case object will be used to store and track all support cases. The dashboard will query and display cases assigned to the current user.

**Metadata ID:** Case

**Details:**
- CaseNumber: Unique case identifier displayed in the dashboard
- Subject: Case subject line displayed in the dashboard
- Priority: Picklist field (High, Medium, Low) used for sorting and visual indicators
- Status: Picklist field (New, In Progress, Pending Customer, Closed, etc.) used for resolution momentum tracking
- IsClosed: Boolean field used to filter open cases
- IsEscalated: Boolean field used to identify escalated cases with visual indicators
- CreatedDate: Used to calculate Days Open
- SlaStartDate: Used to calculate SLA breach proximity
- SlaExitDate: Used to calculate SLA breach proximity
- OwnerId: Used to filter cases assigned to the current user
- LastModifiedDate: Used to determine last customer response date and stale case detection
- LastModifiedById: Used to determine if last modification was by customer or agent
- AccountId: Lookup to Account object for displaying Account Name
- Custom Field: SLAViolation__c (if exists) - Used to track SLA violations