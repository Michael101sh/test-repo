public with sharing class CME_CaseQueueController {

    // Wrapper class for case data with calculated fields
    public class CaseWrapper {
        @AuraEnabled public String caseId { get; set; }
        @AuraEnabled public String caseNumber { get; set; }
        @AuraEnabled public String subject { get; set; }
        @AuraEnabled public String priority { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Integer daysOpen { get; set; }
        @AuraEnabled public Integer slaDaysRemaining { get; set; }
        @AuraEnabled public Boolean isEscalated { get; set; }
        @AuraEnabled public DateTime lastModifiedDate { get; set; }
        @AuraEnabled public String accountName { get; set; }
        @AuraEnabled public Boolean needsResponse { get; set; }
        @AuraEnabled public Boolean hasResolutionMomentum { get; set; }
        @AuraEnabled public String slaRiskLevel { get; set; }
    }

    // Wrapper class for queue summary metrics
    public class QueueSummary {
        @AuraEnabled public Integer totalOpen { get; set; }
        @AuraEnabled public Integer slaRiskCount { get; set; }
        @AuraEnabled public Integer escalatedCount { get; set; }
        @AuraEnabled public Integer needsResponseCount { get; set; }
    }

    // Wrapper class for case insights
    public class CaseInsights {
        @AuraEnabled public List<CaseWrapper> casesAtRisk { get; set; }
        @AuraEnabled public List<CaseWrapper> staleCases { get; set; }
        @AuraEnabled public List<CaseWrapper> trendingCases { get; set; }
    }

    /**
     * Retrieves open cases for the current user
     */
    @AuraEnabled(cacheable=false)
    public static List<CaseWrapper> getOpenCases() {
        try {
            Id currentUserId = UserInfo.getUserId();

            List<Case> cases = [
                SELECT Id, CaseNumber, Subject, Priority, Status, IsEscalated,
                       CreatedDate, SlaStartDate, SlaExitDate, LastModifiedDate,
                       LastModifiedById, Account.Name
                FROM Case
                WHERE OwnerId = :currentUserId
                  AND IsClosed = false
                ORDER BY Priority DESC, CreatedDate ASC
                LIMIT 500
            ];

            List<CaseWrapper> wrappers = new List<CaseWrapper>();
            DateTime now = DateTime.now();
            DateTime fortyEightHoursAgo = now.addHours(-48);

            for (Case c : cases) {
                CaseWrapper wrapper = new CaseWrapper();
                wrapper.caseId = c.Id;
                wrapper.caseNumber = c.CaseNumber;
                wrapper.subject = c.Subject;
                wrapper.priority = c.Priority;
                wrapper.status = c.Status;
                wrapper.isEscalated = c.IsEscalated;
                wrapper.lastModifiedDate = c.LastModifiedDate;
                wrapper.accountName = c.Account != null ? c.Account.Name : '';

                // Calculate days open
                wrapper.daysOpen = c.CreatedDate.date().daysBetween(Date.today());

                // Calculate SLA days remaining
                if (c.SlaExitDate != null) {
                    wrapper.slaDaysRemaining = Date.today().daysBetween(c.SlaExitDate.date());
                } else {
                    wrapper.slaDaysRemaining = null;
                }

                // Determine SLA risk level
                if (wrapper.slaDaysRemaining != null) {
                    if (wrapper.slaDaysRemaining <= 1) {
                        wrapper.slaRiskLevel = 'high';
                    } else if (wrapper.slaDaysRemaining <= 3) {
                        wrapper.slaRiskLevel = 'medium';
                    } else {
                        wrapper.slaRiskLevel = 'low';
                    }
                } else {
                    wrapper.slaRiskLevel = 'none';
                }

                // Determine if needs response (last modified by someone else more than 24 hours ago)
                wrapper.needsResponse = false;
                if (c.LastModifiedById != currentUserId && c.LastModifiedDate < now.addHours(-24)) {
                    wrapper.needsResponse = true;
                }

                // Determine resolution momentum (status changed recently)
                wrapper.hasResolutionMomentum = false;
                if (c.LastModifiedDate > fortyEightHoursAgo &&
                    (c.Status == 'In Progress' || c.Status == 'Pending Customer')) {
                    wrapper.hasResolutionMomentum = true;
                }

                wrappers.add(wrapper);
            }

            return wrappers;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving open cases: ' + e.getMessage());
        }
    }

    /**
     * Retrieves queue summary metrics
     */
    @AuraEnabled(cacheable=false)
    public static QueueSummary getQueueSummary() {
        try {
            List<CaseWrapper> cases = getOpenCases();

            QueueSummary summary = new QueueSummary();
            summary.totalOpen = cases.size();
            summary.slaRiskCount = 0;
            summary.escalatedCount = 0;
            summary.needsResponseCount = 0;

            for (CaseWrapper c : cases) {
                if (c.slaRiskLevel == 'high' || c.slaRiskLevel == 'medium') {
                    summary.slaRiskCount++;
                }
                if (c.isEscalated) {
                    summary.escalatedCount++;
                }
                if (c.needsResponse) {
                    summary.needsResponseCount++;
                }
            }

            return summary;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving queue summary: ' + e.getMessage());
        }
    }

    /**
     * Retrieves proactive case insights
     */
    @AuraEnabled(cacheable=false)
    public static CaseInsights getCaseInsights() {
        try {
            List<CaseWrapper> allCases = getOpenCases();

            CaseInsights insights = new CaseInsights();
            insights.casesAtRisk = new List<CaseWrapper>();
            insights.staleCases = new List<CaseWrapper>();
            insights.trendingCases = new List<CaseWrapper>();

            DateTime fortyEightHoursAgo = DateTime.now().addHours(-48);
            DateTime seventyTwoHoursAgo = DateTime.now().addHours(-72);

            for (CaseWrapper c : allCases) {
                // Cases at risk (SLA breach within 1 day)
                if (c.slaRiskLevel == 'high') {
                    insights.casesAtRisk.add(c);
                }

                // Stale cases (no update in 48+ hours for high priority, 72+ for others)
                if (c.priority == 'High' && c.lastModifiedDate < fortyEightHoursAgo) {
                    insights.staleCases.add(c);
                } else if (c.priority != 'High' && c.lastModifiedDate < seventyTwoHoursAgo) {
                    insights.staleCases.add(c);
                }

                // Trending cases (showing resolution momentum)
                if (c.hasResolutionMomentum) {
                    insights.trendingCases.add(c);
                }
            }

            return insights;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving case insights: ' + e.getMessage());
        }
    }
}
