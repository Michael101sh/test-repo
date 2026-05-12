@isTest
private class CME_CaseQueueControllerTest {

    @testSetup
    static void setupTestData() {
        // Create test account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        // Create test cases with various scenarios
        List<Case> testCases = new List<Case>();

        // Case 1: High priority with SLA risk (SLA exit date within 24 hours)
        testCases.add(new Case(
            Subject = 'SLA Risk Case',
            Priority = 'High',
            Status = 'New',
            AccountId = testAccount.Id,
            IsEscalated = false,
            SlaStartDate = DateTime.now().addDays(-5)
        ));

        // Case 2: Escalated case
        testCases.add(new Case(
            Subject = 'Escalated Case',
            Priority = 'Medium',
            Status = 'Escalated',
            AccountId = testAccount.Id,
            IsEscalated = true,
            SlaStartDate = DateTime.now().addDays(-3)
        ));

        // Case 3: Case with resolution momentum
        testCases.add(new Case(
            Subject = 'In Progress Case',
            Priority = 'Medium',
            Status = 'In Progress',
            AccountId = testAccount.Id,
            IsEscalated = false,
            SlaStartDate = DateTime.now().addDays(-2)
        ));

        // Case 4: Stale high priority case (created 5 days ago, last modified will be set)
        testCases.add(new Case(
            Subject = 'Stale High Priority Case',
            Priority = 'High',
            Status = 'New',
            AccountId = testAccount.Id,
            IsEscalated = false,
            SlaStartDate = DateTime.now().addDays(-5)
        ));

        // Case 5: Low priority case
        testCases.add(new Case(
            Subject = 'Low Priority Case',
            Priority = 'Low',
            Status = 'New',
            AccountId = testAccount.Id,
            IsEscalated = false
        ));

        insert testCases;
    }

    @isTest
    static void testGetOpenCases_Positive() {
        // Verify test data exists
        List<Case> cases = [SELECT Id FROM Case WHERE IsClosed = false];
        System.assertEquals(5, cases.size(), 'Should have 5 test cases');

        Test.startTest();
        List<CME_CaseQueueController.CaseWrapper> results = CME_CaseQueueController.getOpenCases();
        Test.stopTest();

        // Verify results
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(5, results.size(), 'Should return all 5 open cases');

        // Verify wrapper fields are populated
        for (CME_CaseQueueController.CaseWrapper wrapper : results) {
            System.assertNotEquals(null, wrapper.caseId, 'Case ID should be populated');
            System.assertNotEquals(null, wrapper.caseNumber, 'Case Number should be populated');
            System.assertNotEquals(null, wrapper.subject, 'Subject should be populated');
            System.assertNotEquals(null, wrapper.priority, 'Priority should be populated');
            System.assertNotEquals(null, wrapper.status, 'Status should be populated');
            System.assertNotEquals(null, wrapper.daysOpen, 'Days Open should be calculated');
        }

        // Verify SLA risk case is identified
        Boolean foundSlaRisk = false;
        for (CME_CaseQueueController.CaseWrapper wrapper : results) {
            if (wrapper.subject == 'SLA Risk Case' && wrapper.slaRiskLevel == 'high') {
                foundSlaRisk = true;
                break;
            }
        }
        System.assert(foundSlaRisk, 'Should identify SLA risk case');
    }

    @isTest
    static void testGetOpenCases_NoOpenCases() {
        // Close all test cases
        List<Case> cases = [SELECT Id FROM Case WHERE IsClosed = false];
        for (Case c : cases) {
            c.Status = 'Closed';
        }
        update cases;

        Test.startTest();
        List<CME_CaseQueueController.CaseWrapper> results = CME_CaseQueueController.getOpenCases();
        Test.stopTest();

        // Verify no cases returned
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(0, results.size(), 'Should return no open cases');
    }

    @isTest
    static void testGetQueueSummary_Positive() {
        Test.startTest();
        CME_CaseQueueController.QueueSummary summary = CME_CaseQueueController.getQueueSummary();
        Test.stopTest();

        // Verify summary metrics
        System.assertNotEquals(null, summary, 'Summary should not be null');
        System.assertEquals(5, summary.totalOpen, 'Should have 5 total open cases');
        System.assert(summary.slaRiskCount >= 1, 'Should have at least 1 SLA risk case');
        System.assert(summary.escalatedCount >= 1, 'Should have at least 1 escalated case');
    }

    @isTest
    static void testGetQueueSummary_EmptyQueue() {
        // Close all test cases
        List<Case> cases = [SELECT Id FROM Case WHERE IsClosed = false];
        for (Case c : cases) {
            c.Status = 'Closed';
        }
        update cases;

        Test.startTest();
        CME_CaseQueueController.QueueSummary summary = CME_CaseQueueController.getQueueSummary();
        Test.stopTest();

        // Verify empty summary
        System.assertNotEquals(null, summary, 'Summary should not be null');
        System.assertEquals(0, summary.totalOpen, 'Should have 0 total open cases');
        System.assertEquals(0, summary.slaRiskCount, 'Should have 0 SLA risk cases');
        System.assertEquals(0, summary.escalatedCount, 'Should have 0 escalated cases');
        System.assertEquals(0, summary.needsResponseCount, 'Should have 0 cases needing response');
    }

    @isTest
    static void testGetCaseInsights_Positive() {
        Test.startTest();
        CME_CaseQueueController.CaseInsights insights = CME_CaseQueueController.getCaseInsights();
        Test.stopTest();

        // Verify insights structure
        System.assertNotEquals(null, insights, 'Insights should not be null');
        System.assertNotEquals(null, insights.casesAtRisk, 'Cases at risk list should not be null');
        System.assertNotEquals(null, insights.staleCases, 'Stale cases list should not be null');
        System.assertNotEquals(null, insights.trendingCases, 'Trending cases list should not be null');

        // Verify at least one case at risk (SLA risk case)
        System.assert(insights.casesAtRisk.size() >= 1, 'Should have at least 1 case at SLA risk');
    }

    @isTest
    static void testGetCaseInsights_EmptyQueue() {
        // Close all test cases
        List<Case> cases = [SELECT Id FROM Case WHERE IsClosed = false];
        for (Case c : cases) {
            c.Status = 'Closed';
        }
        update cases;

        Test.startTest();
        CME_CaseQueueController.CaseInsights insights = CME_CaseQueueController.getCaseInsights();
        Test.stopTest();

        // Verify empty insights
        System.assertNotEquals(null, insights, 'Insights should not be null');
        System.assertEquals(0, insights.casesAtRisk.size(), 'Should have 0 cases at risk');
        System.assertEquals(0, insights.staleCases.size(), 'Should have 0 stale cases');
        System.assertEquals(0, insights.trendingCases.size(), 'Should have 0 trending cases');
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
                Status = 'New',
                AccountId = testAccount.Id,
                IsEscalated = Math.mod(i, 10) == 0,
                SlaStartDate = DateTime.now().addDays(-2)
            ));
        }

        insert bulkCases;

        Test.startTest();
        List<CME_CaseQueueController.CaseWrapper> results = CME_CaseQueueController.getOpenCases();
        CME_CaseQueueController.QueueSummary summary = CME_CaseQueueController.getQueueSummary();
        CME_CaseQueueController.CaseInsights insights = CME_CaseQueueController.getCaseInsights();
        Test.stopTest();

        // Verify bulk processing works correctly
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assert(results.size() >= 200, 'Should handle 200+ cases');
        System.assertNotEquals(null, summary, 'Summary should handle bulk data');
        System.assertNotEquals(null, insights, 'Insights should handle bulk data');
    }

    @isTest
    static void testNullSafetyForAccountName() {
        // Create case without account
        Case caseWithoutAccount = new Case(
            Subject = 'No Account Case',
            Priority = 'Low',
            Status = 'New'
        );
        insert caseWithoutAccount;

        Test.startTest();
        List<CME_CaseQueueController.CaseWrapper> results = CME_CaseQueueController.getOpenCases();
        Test.stopTest();

        // Verify account name is handled gracefully when null
        Boolean foundCaseWithoutAccount = false;
        for (CME_CaseQueueController.CaseWrapper wrapper : results) {
            if (wrapper.subject == 'No Account Case') {
                foundCaseWithoutAccount = true;
                System.assertEquals('', wrapper.accountName, 'Account name should be empty string when null');
                break;
            }
        }
        System.assert(foundCaseWithoutAccount, 'Should find case without account');
    }

    @isTest
    static void testNullSafetyForSLADates() {
        // Create case without SLA dates
        Case caseWithoutSLA = new Case(
            Subject = 'No SLA Case',
            Priority = 'Low',
            Status = 'New'
        );
        insert caseWithoutSLA;

        Test.startTest();
        List<CME_CaseQueueController.CaseWrapper> results = CME_CaseQueueController.getOpenCases();
        Test.stopTest();

        // Verify SLA fields are handled gracefully when null
        Boolean foundCaseWithoutSLA = false;
        for (CME_CaseQueueController.CaseWrapper wrapper : results) {
            if (wrapper.subject == 'No SLA Case') {
                foundCaseWithoutSLA = true;
                System.assertEquals(null, wrapper.slaDaysRemaining, 'SLA days remaining should be null when SLA not set');
                System.assertEquals('none', wrapper.slaRiskLevel, 'SLA risk level should be none when SLA not set');
                break;
            }
        }
        System.assert(foundCaseWithoutSLA, 'Should find case without SLA');
    }
}
