/**
 * @description Uninstall script for the LQC managed package (registered as the package
 * version's uninstall script; see sf package version create --uninstall-script).
 *
 * Custom_Configuration__mdt/DE_LQC is subscriber-owned, not part of this package, so it
 * survives uninstall on its own. IMPORTANT LIMITATION: Apex's Metadata API deployment
 * (Metadata.Operations.enqueueDeployment) only supports creating/updating custom metadata
 * records, not deleting them - there is no supported way to actually delete a custom
 * metadata record from Apex. This clears the record's Value__c instead, so a leftover
 * DE_LQC record can't silently keep pointing the calculator at classes this package just
 * removed; deleting the record itself (optional) requires Setup, Workbench, or a follow-up
 * Metadata API deploy from outside Apex.
 * @author Ernesto S Melgin
 */
global class LqcUninstallScript implements UninstallHandler {
  @TestVisible
  private static final String CONFIG_OBJECT = 'Custom_Configuration__mdt';
  @TestVisible
  private static final String CONFIG_VALUE_FIELD = 'Value__c';
  @TestVisible
  private static final String DEFAULT_CONFIG_DEV_NAME = 'DE_LQC';

  global void onUninstall(UninstallContext context) {
    // onUninstall() can't abort the uninstall - an uncaught exception here is only logged
    // (Salesforce emails the uninstalling admin), the uninstall proceeds regardless. Best
    // effort only: if Custom_Configuration__mdt is already gone too, there's nothing to do.
    if (recordExists(CONFIG_OBJECT, DEFAULT_CONFIG_DEV_NAME)) {
      enqueueBlankedConfigRecord();
    }
  }

  /**
   * @description Takes the object name as a parameter (rather than reading CONFIG_OBJECT
   * directly) purely so tests can prove the "object doesn't exist" branch deterministically
   * without depending on whether Custom_Configuration__mdt happens to be deployed in the
   * org running the test.
   */
  @TestVisible
  private static Boolean recordExists(String objectApiName, String devName) {
    Schema.SObjectType objectType = Schema.getGlobalDescribe()
      .get(objectApiName);
    if (objectType == null) {
      return false;
    }
    List<SObject> existing = Database.query(
      'SELECT Id FROM ' +
        objectApiName +
        ' WHERE DeveloperName = :devName LIMIT 1'
    );
    return !existing.isEmpty();
  }

  /**
   * @description Enqueues an asynchronous Metadata API deployment that blanks DE_LQC's
   * Value__c - the closest supported equivalent to deletion (see class-level limitation).
   */
  @TestVisible
  private static void enqueueBlankedConfigRecord() {
    Metadata.CustomMetadata record = new Metadata.CustomMetadata();
    record.fullName = CONFIG_OBJECT + '.' + DEFAULT_CONFIG_DEV_NAME;
    record.label = 'DE Liquidity Calculator (uninstalled)';
    Metadata.CustomMetadataValue value = new Metadata.CustomMetadataValue();
    value.field = CONFIG_VALUE_FIELD;
    value.value = '';
    record.values.add(value);

    Metadata.DeployContainer container = new Metadata.DeployContainer();
    container.addMetadata(record);
    Metadata.Operations.enqueueDeployment(container, null);
  }
}
