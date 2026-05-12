public with sharing class CME_CaseInsightsActions {

    // Output wrapper for SLA breach risks
    public class SLABreachResult {
        @AuraEnabled public List<Case> casesAtRisk { get; set; }
        @AuraEnabled public Integer riskCount { get; set; }
        @AuraEnabled public String summary { get; set; }
    }

    // Output wrapper for stale cases
    public class StaleCasesResult {
        @AuraEnabled public List<Case> staleCases { get; set; }
        @AuraEnabled public Integer staleCount { get; set; }
        @AuraEnabled public String summary { get; set; }
    }

    // Output wrapper for resolution momentum
    public class ResolutionMomentumResult {
        @AuraEnabled public List<Case> momentumCases { get; set; }
        @AuraEnabled public Integer momentumCount { get; set; }
        @AuraEnabled public String summary { get; set; }
    }

    // Output wrapper for queue trends
    public class QueueTrendsResult {
        @AuraEnabled public Integer currentVolume { get; set; }
        @AuraEnabled public Integer previousVolume { get; set; }
        @AuraEnabled public String trendDirection { get; set; }
        @AuraEnabled public String summary { get; set; }
    }

    // Output wrapper for anomalies
    public class AnomaliesResult {
        @AuraEnabled public List<Case> anomalies { get; set; }
        @AuraEnabled public Integer anomalyCount { get; set; }
        @AuraEnabled public String summary { get; set; }
    }

    /**
     * Get cases at risk of SLA breach (within 24 hours)
     */
    @AuraEnabled(cacheable=false)
    public static SLABreachResult getSLABreachRisks(String userId) {
        Id targetUserId = String.isNotBlank(userId) ? userId : UserInfo.getUserId();

        DateTime twentyFourHoursFromNow = DateTime.now().addHours(24);

        List<Case> casesAtRisk = [
            SELECT Id, CaseNumber, Subject, Priority, Status, SlaExitDate, Account.Name
            FROM Case
            WHERE OwnerId = :targetUserId
              AND IsClosed = false
              AND SlaExitDate != null
              AND SlaExitDate <= :twentyFourHoursFromNow
            ORDER BY SlaExitDate ASC
            LIMIT 50
        ];

        SLABreachResult result = new SLABreachResult();
        result.casesAtRisk = casesAtRisk;
        result.riskCount = casesAtRisk.size();

        if (result.riskCount == 0) {
            result.summary = 'No cases at immediate SLA risk.';
        } else if (result.riskCount == 1) {
            result.summary = '1 case is at risk of breaching SLA within 24 hours.';
        } else {
            result.summary = result.riskCount + ' cases are at risk of breaching SLA within 24 hours.';
        }

        return result;
    }

    /**
     * Get stale cases (no update in 48+ hours for high priority, 72+ for others)
     */
    @AuraEnabled(cacheable=false)
    public static StaleCasesResult getStaleCases(String userId) {
        Id targetUserId = String.isNotBlank(userId) ? userId : UserInfo.getUserId();

        DateTime fortyEightHoursAgo = DateTime.now().addHours(-48);
        DateTime seventyTwoHoursAgo = DateTime.now().addHours(-72);

        List<Case> staleCases = [
            SELECT Id, CaseNumber, Subject, Priority, Status, LastModifiedDate, Account.Name
            FROM Case
            WHERE OwnerId = :targetUserId
              AND IsClosed = false
              AND ((Priority = 'High' AND LastModifiedDate < :fortyEightHoursAgo)
                   OR (Priority != 'High' AND LastModifiedDate < :seventyTwoHoursAgo))
            ORDER BY LastModifiedDate ASC
            LIMIT 50
        ];

        StaleCasesResult result = new StaleCasesResult();
        result.staleCases = staleCases;
        result.staleCount = staleCases.size();

        if (result.staleCount == 0) {
            result.summary = 'No stale cases detected.';
        } else if (result.staleCount == 1) {
            result.summary = '1 case needs attention due to lack of recent activity.';
        } else {
            result.summary = result.staleCount + ' cases need attention due to lack of recent activity.';
        }

        return result;
    }

    /**
     * Get cases showing resolution momentum (status progressed in last 48 hours)
     */
    @AuraEnabled(cacheable=false)
    public static ResolutionMomentumResult getResolutionMomentum(String userId) {
        Id targetUserId = String.isNotBlank(userId) ? userId : UserInfo.getUserId();

        DateTime fortyEightHoursAgo = DateTime.now().addHours(-48);

        List<Case> momentumCases = [
            SELECT Id, CaseNumber, Subject, Priority, Status, LastModifiedDate, Account.Name
            FROM Case
            WHERE OwnerId = :targetUserId
              AND IsClosed = false
              AND LastModifiedDate > :fortyEightHoursAgo
              AND (Status = 'In Progress' OR Status = 'Pending Customer')
            ORDER BY LastModifiedDate DESC
            LIMIT 50
        ];

        ResolutionMomentumResult result = new ResolutionMomentumResult();
        result.momentumCases = momentumCases;
        result.momentumCount = momentumCases.size();

        if (result.momentumCount == 0) {
            result.summary = 'No cases showing recent resolution momentum.';
        } else if (result.momentumCount == 1) {
            result.summary = '1 case is progressing toward resolution.';
        } else {
            result.summary = result.momentumCount + ' cases are progressing toward resolution.';
        }

        return result;
    }

    /**
     * Get queue trends (compare last 7 days to previous 7 days)
     */
    @AuraEnabled(cacheable=false)
    public static QueueTrendsResult getQueueTrends(String userId) {
        Id targetUserId = String.isNotBlank(userId) ? userId : UserInfo.getUserId();

        DateTime sevenDaysAgo = DateTime.now().addDays(-7);
        DateTime fourteenDaysAgo = DateTime.now().addDays(-14);

        // Current period (last 7 days)
        Integer currentVolume = [
            SELECT COUNT()
            FROM Case
            WHERE OwnerId = :targetUserId
              AND CreatedDate >= :sevenDaysAgo
        ];

        // Previous period (8-14 days ago)
        Integer previousVolume = [
            SELECT COUNT()
            FROM Case
            WHERE OwnerId = :targetUserId
              AND CreatedDate >= :fourteenDaysAgo
              AND CreatedDate < :sevenDaysAgo
        ];

        QueueTrendsResult result = new QueueTrendsResult();
        result.currentVolume = currentVolume;
        result.previousVolume = previousVolume;

        // Determine trend direction
        if (previousVolume == 0) {
            result.trendDirection = currentVolume > 0 ? 'increasing' : 'stable';
        } else {
            Decimal changePercent = ((Decimal)(currentVolume - previousVolume) / previousVolume) * 100;
            if (changePercent > 10) {
                result.trendDirection = 'increasing';
            } else if (changePercent < -10) {
                result.trendDirection = 'decreasing';
            } else {
                result.trendDirection = 'stable';
            }
        }

        result.summary = 'Case volume is ' + result.trendDirection + '. Current: ' + currentVolume + ', Previous: ' + previousVolume + '.';

        return result;
    }

    /**
     * Detect anomalies (high priority cases with no update in 48+ hours)
     */
    @AuraEnabled(cacheable=false)
    public static AnomaliesResult detectAnomalies(String userId) {
        Id targetUserId = String.isNotBlank(userId) ? userId : UserInfo.getUserId();

        DateTime fortyEightHoursAgo = DateTime.now().addHours(-48);

        List<Case> anomalyCases = [
            SELECT Id, CaseNumber, Subject, Priority, Status, LastModifiedDate, CreatedDate, Account.Name
            FROM Case
            WHERE OwnerId = :targetUserId
              AND IsClosed = false
              AND Priority = 'High'
              AND LastModifiedDate < :fortyEightHoursAgo
            ORDER BY LastModifiedDate ASC
            LIMIT 50
        ];

        AnomaliesResult result = new AnomaliesResult();
        result.anomalies = anomalyCases;
        result.anomalyCount = anomalyCases.size();

        if (result.anomalyCount == 0) {
            result.summary = 'No anomalies detected in your queue.';
        } else if (result.anomalyCount == 1) {
            result.summary = '1 high-priority case has had no updates in 48+ hours.';
        } else {
            result.summary = result.anomalyCount + ' high-priority cases have had no updates in 48+ hours.';
        }

        return result;
    }
}
