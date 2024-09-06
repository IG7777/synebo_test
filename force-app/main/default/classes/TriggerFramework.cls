public without sharing virtual class TriggerFramework {
    public class TriggerFrameworkException extends Exception {}

    private static final String BEFORE_INSERT = 'before insert';
    private static final String AFTER_INSERT = 'after insert';
    private static final String BEFORE_UPDATE = 'before update';
    private static final String AFTER_UPDATE = 'after update';
    private static final String BEFORE_DELETE = 'before delete';
    private static final String AFTER_DELETE = 'after delete';
    private static final String AFTER_UNDELETE = 'after undelete';

    @TestVisible
    protected TriggerContext context;

    public TriggerFramework() {
        this.setTriggerContext();
    }

    public void run() {
        if (!validateRun()) {
            return;
        }

        dispatchHandlerMethod();
    }

    private void dispatchHandlerMethod() {
        if (isBeforeInsert()) {
            this.beforeInsert();
        } else if (isBeforeUpdate()) {
            this.beforeUpdate();
        } else if (isBeforeDelete()) {
            this.beforeDelete();
        } else if (isAfterInsert()) {
            this.afterInsert();
        } else if (isAfterUpdate()) {
            this.afterUpdate();
        } else if (isAfterDelete()) {
            this.afterDelete();
        } else if (isAfterUnDelete()) {
            this.afterUndelete();
        }
    }

     private void setTriggerContext() {
         if ((isBeforeInsert())) {
            this.context = TriggerContext.BEFORE_INSERT;
        } else if (isBeforeUpdate()) {
            this.context = TriggerContext.BEFORE_UPDATE;
        } else if (isBeforeDelete()) {
            this.context = TriggerContext.BEFORE_DELETE;
        } else if (isAfterInsert()) {
            this.context = TriggerContext.AFTER_INSERT;
        } else if (isAfterUpdate()) {
            this.context = TriggerContext.AFTER_UPDATE;
        } else if(isAfterDelete()) {
            this.context = TriggerContext.AFTER_DELETE;
        } else if (isAfterUnDelete()) {
            this.context = TriggerContext.AFTER_UNDELETE;
        }
     }

    private Boolean isBeforeInsert() {
        return (Trigger.isExecuting && Trigger.isBefore && Trigger.isInsert);
    }

    private Boolean isBeforeUpdate() {
        return (Trigger.isExecuting && Trigger.isBefore && Trigger.isUpdate);
    }

    private Boolean isBeforeDelete() {
        return (Trigger.isExecuting && Trigger.isBefore && Trigger.isDelete);
    }

    private Boolean isAfterInsert() {
        return (Trigger.isExecuting && Trigger.isAfter && Trigger.isInsert);
    }

    private Boolean isAfterUpdate() {
        return (Trigger.isExecuting && Trigger.isAfter && Trigger.isUpdate);
    }

    private Boolean isAfterDelete() {
        return (Trigger.isExecuting && Trigger.isAfter && Trigger.isDelete);
    }

    private Boolean isAfterUnDelete() {
        return (Trigger.isExecuting && Trigger.isAfter && Trigger.isUndelete);
    }

    @TestVisible
    private Boolean validateRun() {
        if (!Trigger.isExecuting || this.context == null) {
            throw new TriggerFrameworkException('some error message here');
        }

        return true;
    }

    @TestVisible
    protected virtual void beforeInsert(){}
    @TestVisible
    protected virtual void beforeUpdate(){}
    @TestVisible
    protected virtual void beforeDelete(){}
    @TestVisible
    protected virtual void afterInsert(){}
    @TestVisible
    protected virtual void afterUpdate(){}
    @TestVisible
    protected virtual void afterDelete(){}
    @TestVisible
    protected virtual void afterUndelete(){}

    @TestVisible
    public enum TriggerContext {
        BEFORE_INSERT, BEFORE_UPDATE, BEFORE_DELETE,
        AFTER_INSERT, AFTER_UPDATE, AFTER_DELETE,
        AFTER_UNDELETE
    }
}