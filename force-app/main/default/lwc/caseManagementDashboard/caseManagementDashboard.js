import { LightningElement, track } from 'lwc';
import getOpenCases from '@salesforce/apex/CME_CaseQueueController.getOpenCases';
import getQueueSummary from '@salesforce/apex/CME_CaseQueueController.getQueueSummary';
import getCaseInsights from '@salesforce/apex/CME_CaseQueueController.getCaseInsights';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const COLUMNS = [
    { label: 'Case Number', fieldName: 'caseNumber', type: 'text', sortable: true },
    { label: 'Subject', fieldName: 'subject', type: 'text', sortable: true },
    { label: 'Priority', fieldName: 'priority', type: 'text', sortable: true },
    { label: 'Status', fieldName: 'status', type: 'text', sortable: true },
    { label: 'Days Open', fieldName: 'daysOpen', type: 'number', sortable: true },
    { label: 'SLA Days Remaining', fieldName: 'slaDaysRemaining', type: 'number', sortable: true },
    { label: 'Account', fieldName: 'accountName', type: 'text', sortable: true },
    { label: 'Escalated', fieldName: 'isEscalated', type: 'boolean' }
];

const REFRESH_INTERVAL = 300000; // 5 minutes in milliseconds

export default class CaseManagementDashboard extends LightningElement {
    columns = COLUMNS;

    @track cases = [];
    @track summary = {};
    @track insights = {};
    @track sortedBy;
    @track sortedDirection = 'asc';
    @track isLoading = false;
    @track error;
    @track lastRefreshTime;

    refreshIntervalId;

    connectedCallback() {
        this.loadDashboardData();
        this.startAutoRefresh();
    }

    disconnectedCallback() {
        this.stopAutoRefresh();
    }

    async loadDashboardData() {
        this.isLoading = true;
        this.error = null;

        try {
            const [casesData, summaryData, insightsData] = await Promise.all([
                getOpenCases(),
                getQueueSummary(),
                getCaseInsights()
            ]);

            this.cases = casesData || [];
            this.summary = summaryData || {};
            this.insights = insightsData || {};
            this.lastRefreshTime = new Date().toLocaleTimeString();

        } catch (error) {
            this.error = error.body?.message || 'Error loading dashboard data';
            this.showToast('Error', this.error, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleRefresh() {
        this.loadDashboardData();
    }

    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;
        this.sortData(fieldName, sortDirection);
    }

    sortData(fieldName, direction) {
        const cloneData = [...this.cases];

        cloneData.sort((a, b) => {
            let aVal = a[fieldName];
            let bVal = b[fieldName];

            // Handle null values
            if (aVal === null || aVal === undefined) return direction === 'asc' ? 1 : -1;
            if (bVal === null || bVal === undefined) return direction === 'asc' ? -1 : 1;

            // Convert to strings for comparison if needed
            if (typeof aVal === 'string') aVal = aVal.toLowerCase();
            if (typeof bVal === 'string') bVal = bVal.toLowerCase();

            if (aVal < bVal) {
                return direction === 'asc' ? -1 : 1;
            } else if (aVal > bVal) {
                return direction === 'asc' ? 1 : -1;
            }
            return 0;
        });

        this.cases = cloneData;
    }

    startAutoRefresh() {
        this.refreshIntervalId = setInterval(() => {
            this.loadDashboardData();
        }, REFRESH_INTERVAL);
    }

    stopAutoRefresh() {
        if (this.refreshIntervalId) {
            clearInterval(this.refreshIntervalId);
        }
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(event);
    }

    // Computed properties
    get hasCases() {
        return this.cases && this.cases.length > 0;
    }

    get hasError() {
        return !!this.error;
    }

    get formattedLastRefresh() {
        return this.lastRefreshTime ? `Last refreshed: ${this.lastRefreshTime}` : '';
    }

    get totalOpenCount() {
        return this.summary.totalOpen || 0;
    }

    get slaRiskCount() {
        return this.summary.slaRiskCount || 0;
    }

    get escalatedCount() {
        return this.summary.escalatedCount || 0;
    }

    get needsResponseCount() {
        return this.summary.needsResponseCount || 0;
    }

    get casesAtRiskCount() {
        return this.insights.casesAtRisk?.length || 0;
    }

    get staleCasesCount() {
        return this.insights.staleCases?.length || 0;
    }

    get trendingCasesCount() {
        return this.insights.trendingCases?.length || 0;
    }

    get hasInsights() {
        return this.casesAtRiskCount > 0 || this.staleCasesCount > 0 || this.trendingCasesCount > 0;
    }
}
