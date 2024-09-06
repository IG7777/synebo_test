public with sharing class CaseTriggerHandler extends TriggerFramework {
    public class CaseTriggerHandlerException extends Exception {}
    private final List<Case> newCases;
    private final Map<Id, Case> oldCasesMap;
    private Map<Id, AccountCaseWrapper> wrappersMap;
    @TestVisible
    private List<Database.SaveResult> updateResults;

    public CaseTriggerHandler() {
        newCases = Trigger.new;
        oldCasesMap = (Map<Id, Case>) Trigger.oldMap;
        wrappersMap = new Map<Id, AccountCaseWrapper>();
    }

    public override void afterInsert() {
        updateAccountRollUps();
    }

    public override void afterUpdate() {
        updateAccountRollUps();
    }

    public override void afterDelete() {
        updateAccountRollUps();
    }

    public override void afterUndelete() {
        updateAccountRollUps();
    }

    //Better to move all of this logic to helper but I wanna do that because its not real project :-P
    private void updateAccountRollUps() {
        populateWrapersMap();
        List<Account> toUpdate = claculateRollUps();
        updateAccounts(toUpdate);
    }

    private void populateWrapersMap() {
        List<Case> cases = this.context == TriggerFramework.TriggerContext.AFTER_DELETE ? oldCasesMap.values() : newCases;
        for (Case cs: cases) {
            switch on this.context {
                when AFTER_UPDATE {
                    if (isClosed(cs, TriggerFramework.TriggerContext.AFTER_UPDATE)) {
                        addAsChangedToClosed(cs.AccountId);
                    } else if (isOpened(cs, TriggerFramework.TriggerContext.AFTER_UPDATE)) {
                        addAsChangedToOpened(cs.AccountId);
                    }
                }
                when AFTER_INSERT {
                    if (isClosed(cs, TriggerFramework.TriggerContext.AFTER_INSERT)) {
                        addAsNewClosed(cs.AccountId);
                    } else if (isOpened(cs, TriggerFramework.TriggerContext.AFTER_INSERT)) {
                        addAsNewOpened(cs.AccountId);
                    }
                }
                when AFTER_DELETE {
                    if (isClosed(cs, TriggerFramework.TriggerContext.AFTER_DELETE)) {
                        addAsDeletedClosed(cs.AccountId);
                    } else if (isOpened(cs, TriggerFramework.TriggerContext.AFTER_DELETE)) {
                        addAsDeletedOpened(cs.AccountId);
                    }
                }
                when AFTER_UNDELETE {
                    if (isClosed(cs, TriggerFramework.TriggerContext.AFTER_UNDELETE)) {
                        addAsNewClosed(cs.AccountId);
                    } else if (isOpened(cs, TriggerFramework.TriggerContext.AFTER_UNDELETE)) {
                        addAsNewOpened(cs.AccountId);
                    }
                }
            }
        }
    }

    private Boolean isClosed(Case cs, TriggerFramework.TriggerContext ctx) {
        if (
            cs.IsClosed && 
            (ctx != TriggerFramework.TriggerContext.AFTER_UPDATE || 
            cs.IsClosed != oldCasesMap.get(cs.Id).IsClosed)
        ) {
            return true;
        } else {
            return false;
        }
    }

    private Boolean isOpened(Case cs, TriggerFramework.TriggerContext ctx) {
        if (
            !cs.IsClosed && 
            (ctx != TriggerFramework.TriggerContext.AFTER_UPDATE || 
            cs.IsClosed != oldCasesMap.get(cs.Id).IsClosed)
        ) {
            return true;
        } else {
            return false;
        }
    }

    private List<Account> claculateRollUps() {
        List<Account> accountsToUpdate = getAccountsToUpdate(this.wrappersMap.keySet());
        for (Account account: accountsToUpdate) {
            Integer previousClosed = account.TotalClosedCases__c == null ? 0 : Integer.valueOf(account.TotalClosedCases__c);
            Integer previousOpened = account.TotalOpenedCases__c == null ? 0 : Integer.valueOf(account.TotalOpenedCases__c);

            account.TotalClosedCases__c = previousClosed 
                - this.wrappersMap.get(account.Id).nuberOfChangedToOpen 
                + this.wrappersMap.get(account.Id).nuberOfChangedToClosed
                + this.wrappersMap.get(account.Id).nuberOfNewClosed
                - this.wrappersMap.get(account.Id).nuberOfDeletedClosed
            ;
            account.TotalOpenedCases__c = previousOpened 
                - this.wrappersMap.get(account.Id).nuberOfChangedToClosed 
                + this.wrappersMap.get(account.Id).nuberOfChangedToOpen
                + this.wrappersMap.get(account.Id).nuberOfNewOpened
                - this.wrappersMap.get(account.Id).nuberOfDeletedOpened
            ;
            account = validateValues(account);
        }

        return accountsToUpdate;
    }

    private List<Account> getAccountsToUpdate(Set<Id> accountIds) {
        List<Account> accounts = new List<Account>();
        // better to use specific object selector with all necessary CRUD and errors validations;
        try {
            accounts = [
                SELECT Id, TotalClosedCases__c, TotalOpenedCases__c 
                FROM Account 
                WHERE Id IN :accountIds
            ];
        } catch (QueryException ex) {
            throw new CaseTriggerHandlerException('Query Accounts failed. Error: ' + ex.getMessage());
            //add loging of failed Accounts Id's and rollups using some logger
        }

        return accounts;
    }

    private void updateAccounts(List<SObject> records) {
        //all this logic should be in separate object DML oprations util with all necessary CRUD and errors validations;
        if (records.isEmpty()) {
            return;
        }

        try {
            List<Database.SaveResult> results = Database.update(records, false);
            parseResults(results);
            this.updateResults = results;
        } catch (DmlException ex) {
            throw new CaseTriggerHandlerException('Update Accounts failed. Error: ' + ex.getMessage());
            //loging of failed Accounts Id's and rollups using some logger
        }
    }

    private Account validateValues(Account acc) {
        // to prevent such cases better have one time batch that will update all cases, to have correctly populated fields right after deploying trigger
        if (acc.TotalClosedCases__c < 0) {
            acc.TotalClosedCases__c = 0;
        }

        if (acc.TotalOpenedCases__c < 0) {
            acc.TotalOpenedCases__c = 0;
        }

        return acc;
    }

    private void parseResults(List<Database.SaveResult> results) {
        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()) {           
                for(Database.Error err : sr.getErrors()) {
                    // log to log object failed results err.getMessage;
                }
            }
        }
    }

    private void addAsChangedToClosed(Id accountId) {
        if (this.wrappersMap.get(accountId) != null) {
            this.wrappersMap.get(accountId).nuberOfChangedToClosed++;
        } else {
            this.wrappersMap.put(accountId, new AccountCaseWrapper());
            this.wrappersMap.get(accountId).nuberOfChangedToClosed++;
        }
    }

    private void addAsChangedToOpened(Id accountId) {
        if (this.wrappersMap.get(accountId) != null) {
            this.wrappersMap.get(accountId).nuberOfChangedToOpen++;
        } else {
            this.wrappersMap.put(accountId, new AccountCaseWrapper());
            this.wrappersMap.get(accountId).nuberOfChangedToOpen++;
        }
    }

    private void addAsNewClosed(Id accountId) {
        if (this.wrappersMap.get(accountId) != null) {
            this.wrappersMap.get(accountId).nuberOfNewClosed++;
        } else {
            this.wrappersMap.put(accountId, new AccountCaseWrapper());
            this.wrappersMap.get(accountId).nuberOfNewClosed++;
        }
    }

    private void addAsNewOpened(Id accountId) {
        if (this.wrappersMap.get(accountId) != null) {
            this.wrappersMap.get(accountId).nuberOfNewOpened++;
        } else {
            this.wrappersMap.put(accountId, new AccountCaseWrapper());
            this.wrappersMap.get(accountId).nuberOfNewOpened++;
        }
    }

    private void addAsDeletedClosed(Id accountId) {
        if (this.wrappersMap.get(accountId) != null) {
            this.wrappersMap.get(accountId).nuberOfDeletedClosed++;
        } else {
            this.wrappersMap.put(accountId, new AccountCaseWrapper());
            this.wrappersMap.get(accountId).nuberOfDeletedClosed++;
        }
    }

    private void addAsDeletedOpened(Id accountId) {
        if (this.wrappersMap.get(accountId) != null) {
            this.wrappersMap.get(accountId).nuberOfDeletedOpened++;
        } else {
            this.wrappersMap.put(accountId, new AccountCaseWrapper());
            this.wrappersMap.get(accountId).nuberOfDeletedOpened++;
        }
    }

    public class AccountCaseWrapper {
        private Integer nuberOfChangedToClosed = 0;
        private Integer nuberOfChangedToOpen = 0;
        private Integer nuberOfNewOpened = 0;
        private Integer nuberOfNewClosed = 0;
        private Integer nuberOfDeletedClosed = 0;
        private Integer nuberOfDeletedOpened = 0;
    }
}