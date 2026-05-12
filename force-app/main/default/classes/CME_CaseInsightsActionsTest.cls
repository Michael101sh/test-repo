@isTest
private class CME_CaseInsightsActionsTest {

    @testSetup
    static void setupTestData() {
        // Create test account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        // Create test cases with various scenarios
        List<Case> testCases = new List<Case>();

        // Cases with SLA risk (SLA exit within 24 hours)
        testCases.add(new Case(
            Subject = 'SLA Risk Case 1',
            Priority = 'High',
            Status = 'New',
            AccountId = testAccount.Id,
            SlaStartDate = DateTime.now().addDays(-5)
        ));

        testCases.add(new Case(
            Subject = 'SLA Risk Case 2',
            Priority = 'Medium',
            Status = 'New',
            AccountId = testAccount.Id,
            SlaStartDate = DateTime.now().addDays(-3)
        ));

        // High priority stale case (will set LastModifiedDate via test context)
        testCases.add(new Case(
            Subject = 'Stale High Priority Case',
            Priority = 'High',
            Status = 'New',
            AccountId = testAccount.Id,
            SlaStartDate = DateTime.now().addDays(-5)
        ));

        // Medium priority stale case
        testCases.add(new Case(
            Subject = 'Stale Medium Priority Case',
            Priority = 'Medium',
            Status = 'New',
            AccountId = testAccount.Id,
            SlaStartDate = DateTime.now().addDays(-4)
        ));

        // Cases with resolution momentum
        testCases.add(new Case(
            Subject = 'In Progress Case',
            Priority = 'Medium',
            Status = 'In Progress',
            AccountId = testAccount.Id,
            SlaStartDate = DateTime.now().addDays(-2)
        ));

        testCases.add(new Case(
            Subject = 'Pending Customer Case',
            Priority = 'Low',
            Status = 'Pending Customer',
            AccountId = testAccount.Id,
            SlaStartDate = DateTime.now().addDays(-1)
        ));

        // Cases created in last 7 days (for trend analysis)
        for (Integer i = 0; i < 5; i++) {
            testCases.add(new Case(
                Subject = 'Recent Case ' + i,
                Priority = 'Low',
                Status = 'New',
                AccountId = testAccount.Id
            ));
        }

        insert testCases;
    }

    @isTest
    static void testGetSLABreachRisks_Positive() {
        String userId = UserInfo.getUserId();

        Test.startTest();
        CME_CaseInsightsActions.SLABreachResult result =
            CME_CaseInsightsActions.getSLABreachRisks(userId);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.riskCount, 'Risk count should not be null');
        System.assertNotEquals(null, result.casesAtRisk, 'Cases list should not be null');
        System.assertNotEquals(null, result.summary, 'Summary should not be null');
        System.assert(result.summary.contains('cases are at risk') || result.summary.contains('case is at risk') || result.summary.contains('No cases'), 'Summary should describe SLA risks');
    }

    @isTest
    static void testGetSLABreachRisks_NoRisks() {
        // Close all SLA risk cases
        List<Case> cases = [SELECT Id FROM Case WHERE SlaExitDate != null];
        for (Case c : cases) {
            c.Status = 'Closed';
        }
        update cases;

        String userId = UserInfo.getUserId();

        Test.startTest();
        CME_CaseInsightsActions.SLABreachResult result =
            CME_CaseInsightsActions.getSLABreachRisks(userId);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.riskCount, 'Should have no SLA risks');
        System.assert(result.summary.contains('No cases'), 'Summary should indicate no risks');
    }

    @isTest
    static void testGetStaleCases_Positive() {
        String userId = UserInfo.getUserId();

        Test.startTest();
        CME_CaseInsightsActions.StaleCasesResult result =
            CME_CaseInsightsActions.getStaleCases(userId);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.staleCount, 'Stale count should not be null');
        System.assertNotEquals(null, result.staleCases, 'Cases list should not be null');
        System.assertNotEquals(null, result.summary, 'Summary should not be null');
    }

    @isTest
    static void testGetStaleCases_NoStale() {
        // Close all stale cases
        delete [SELECT Id FROM Case WHERE Subject LIKE 'Stale%'];

        String userId = UserInfo.getUserId();

        Test.startTest();
        CME_CaseInsightsActions.StaleCasesResult result =
            CME_CaseInsightsActions.getStaleCases(userId);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.staleCount, 'Should have no stale cases');
        System.assert(result.summary.contains('No stale'), 'Summary should indicate no stale cases');
    }

    @isTest
    static void testGetResolutionMomentum_Positive() {
        String userId = UserInfo.getUserId();

        Test.startTest();
        CME_CaseInsightsActions.ResolutionMomentumResult result =
            CME_CaseInsightsActions.getResolutionMomentum(userId);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.momentumCount, 'Momentum count should not be null');
        System.assert(result.momentumCount >= 2, 'Should identify at least 2 cases with momentum');
        System.assertNotEquals(null, result.momentumCases, 'Cases list should not be null');
        System.assertNotEquals(null, result.summary, 'Summary should not be null');
        System.assert(result.summary.contains('progressing') || result.summary.contains('No cases'), 'Summary should describe momentum');
    }

    @isTest
    static void testGetResolutionMomentum_NoMomentum() {
        // Update all momentum cases to different status
        List<Case> cases = [SELECT Id FROM Case WHERE Status IN ('In Progress', 'Pending Customer')];
        for (Case c : cases) {
            c.Status = 'New';
        }
        update cases;

        String userId = UserInfo.getUserId();

        Test.startTest();
        CME_CaseInsightsActions.ResolutionMomentumResult result =
            CME_CaseInsightsActions.getResolutionMomentum(userId);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.summary, 'Summary should not be null');
    }

    @isTest
    static void testGetQueueTrends_Positive() {
        String userId = UserInfo.getUserId();

        Test.startTest();
        CME_CaseInsightsActions.QueueTrendsResult result =
            CME_CaseInsightsActions.getQueueTrends(userId);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.currentVolume, 'Current volume should not be null');
        System.assertNotEquals(null, result.previousVolume, 'Previous volume should not be null');
        System.assertNotEquals(null, result.trendDirection, 'Trend direction should not be null');
        System.assert(
            result.trendDirection == 'increasing' ||
            result.trendDirection == 'decreasing' ||
            result.trendDirection == 'stable',
            'Trend direction should be valid'
        );
        System.assertNotEquals(null, result.summary, 'Summary should not be null');
        System.assert(result.summary.contains('volume'), 'Summary should describe trends');
    }

    @isTest
    static void testGetQueueTrends_NoPreviousVolume() {
        // Delete all cases to test edge case
        delete [SELECT Id FROM Case];

        String userId = UserInfo.getUserId();

        Test.startTest();
        CME_CaseInsightsActions.QueueTrendsResult result =
            CME_CaseInsightsActions.getQueueTrends(userId);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.currentVolume, 'Current volume should be 0');
        System.assertEquals(0, result.previousVolume, 'Previous volume should be 0');
        System.assertEquals('stable', result.trendDirection, 'Trend should be stable when no cases');
    }

    @isTest
    static void testDetectAnomalies_Positive() {
        String userId = UserInfo.getUserId();

        Test.startTest();
        CME_CaseInsightsActions.AnomaliesResult result =
            CME_CaseInsightsActions.detectAnomalies(userId);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.anomalyCount, 'Anomaly count should not be null');
        System.assertNotEquals(null, result.anomalies, 'Anomalies list should not be null');
        System.assertNotEquals(null, result.summary, 'Summary should not be null');
    }

    @isTest
    static void testDetectAnomalies_NoAnomalies() {
        // Delete high priority cases
        delete [SELECT Id FROM Case WHERE Priority = 'High'];

        String userId = UserInfo.getUserId();

        Test.startTest();
        CME_CaseInsightsActions.AnomaliesResult result =
            CME_CaseInsightsActions.detectAnomalies(userId);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.anomalyCount, 'Should have no anomalies');
        System.assert(result.summary.contains('No anomalies'), 'Summary should indicate no anomalies');
    }

    @isTest
    static void testBulkProcessing() {
        // Delete existing test cases
        delete [SELECT Id FROM Case];

        // Create 200+ cases for bulk testing
        List<Case> bulkCases = new List<Case>();
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        for (Integer i = 0; i < 210; i++) {
            bulkCases.add(new Case(
                Subject = 'Bulk Test Case ' + i,
                Priority = Math.mod(i, 3) == 0 ? 'High' : 'Medium',
                Status = Math.mod(i, 5) == 0 ? 'In Progress' : 'New',
                AccountId = testAccount.Id,
                SlaStartDate = DateTime.now().addDays(-2)
            ));
        }

        insert bulkCases;

        String userId = UserInfo.getUserId();

        Test.startTest();
        CME_CaseInsightsActions.SLABreachResult slaResult =
            CME_CaseInsightsActions.getSLABreachRisks(userId);
        CME_CaseInsightsActions.StaleCasesResult staleResult =
            CME_CaseInsightsActions.getStaleCases(userId);
        CME_CaseInsightsActions.ResolutionMomentumResult momentumResult =
            CME_CaseInsightsActions.getResolutionMomentum(userId);
        CME_CaseInsightsActions.QueueTrendsResult trendResult =
            CME_CaseInsightsActions.getQueueTrends(userId);
        CME_CaseInsightsActions.AnomaliesResult anomalyResult =
            CME_CaseInsightsActions.detectAnomalies(userId);
        Test.stopTest();

        // Verify all methods handle bulk data correctly
        System.assertNotEquals(null, slaResult, 'SLA result should not be null');
        System.assertNotEquals(null, staleResult, 'Stale result should not be null');
        System.assertNotEquals(null, momentumResult, 'Momentum result should not be null');
        System.assertNotEquals(null, trendResult, 'Trend result should not be null');
        System.assertNotEquals(null, anomalyResult, 'Anomaly result should not be null');
    }

    @isTest
    static void testDefaultUserId() {
        // Test that methods default to current user when userId is null
        Test.startTest();
        CME_CaseInsightsActions.SLABreachResult result =
            CME_CaseInsightsActions.getSLABreachRisks(null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        // Method should use UserInfo.getUserId() as default
    }

    @isTest
    static void testNullUserId() {
        // Test all methods with null userId parameter
        Test.startTest();
        CME_CaseInsightsActions.SLABreachResult slaResult =
            CME_CaseInsightsActions.getSLABreachRisks(null);
        CME_CaseInsightsActions.StaleCasesResult staleResult =
            CME_CaseInsightsActions.getStaleCases(null);
        CME_CaseInsightsActions.ResolutionMomentumResult momentumResult =
            CME_CaseInsightsActions.getResolutionMomentum(null);
        CME_CaseInsightsActions.QueueTrendsResult trendResult =
            CME_CaseInsightsActions.getQueueTrends(null);
        CME_CaseInsightsActions.AnomaliesResult anomalyResult =
            CME_CaseInsightsActions.detectAnomalies(null);
        Test.stopTest();

        System.assertNotEquals(null, slaResult, 'SLA result should not be null');
        System.assertNotEquals(null, staleResult, 'Stale result should not be null');
        System.assertNotEquals(null, momentumResult, 'Momentum result should not be null');
        System.assertNotEquals(null, trendResult, 'Trend result should not be null');
        System.assertNotEquals(null, anomalyResult, 'Anomaly result should not be null');
    }
}
