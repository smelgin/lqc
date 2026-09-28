/**
 * @description Post-install script for the LQC managed package (registered as the package
 * version's post-install script; see sf package version create --post-install-script).
 *
 * Custom_Configuration__mdt is a subscriber-owned object, not part of this package (see
 * LqcController.queryConfigJson) - a real install has no config until something creates a
 * DE_LQC record there. This seeds that record, but only when Custom_Configuration__mdt
 * already exists: if it doesn't, the calculator has no config object to read from at all,
 * so the install is aborted (an uncaught exception here rolls back the whole install)
 * rather than left half-configured.
 * @author Ernesto S Melgin
 */
global class LqcPostInstallScript implements InstallHandler {
  @TestVisible
  private static final String CONFIG_OBJECT = 'Custom_Configuration__mdt';
  @TestVisible
  private static final String CONFIG_VALUE_FIELD = 'Value__c';
  @TestVisible
  private static final String DEFAULT_CONFIG_DEV_NAME = 'DE_LQC';

  @TestVisible
  private static final String DEFAULT_CONFIG_JSON = '{"storageClass":"lqcEstateCaseStorage","tabs":[{"name":"debitAccount","title":"Debit Accounts","columns":[{"name":"Account Number","type":"textLink","width":"20%"},{"name":"Account Type","type":"picklist","values":"Debit","width":"10%"},{"name":"Available Balance","type":"number","width":"20%"},{"name":"Account Status","type":"text","width":"10%"},{"name":"Account Name","type":"text","width":"15%"},{"name":"Balance","type":"number","width":"15%","subtotal":true},{"name":"Date Closed","type":"date","width":"10%"}],"refreshClass":"lqcDebitAccounts","canAddRows":true},{"name":"creditAccount","title":"Credit Accounts","columns":[{"name":"Account Number","type":"textLink","width":"20%"},{"name":"Account Type","type":"picklist","values":"Credit","width":"10%"},{"name":"Balance at DoD","type":"number","width":"20%"},{"name":"Account Status","type":"text","width":"10%"},{"name":"Interest on Acct","type":"number","width":"15%"},{"name":"Current Balance","type":"number(6,2)","width":"15%","subtotal":true},{"name":"Account Name","type":"text","width":"10%"}],"refreshClass":"lqcCreditAccounts","canAddRows":true},{"name":"insurancePolicies","title":"Insurance Policies","columns":[{"name":"Policy Number","type":"textLink","width":"20%"},{"name":"Policy Type","type":"picklist","values":"Vehicle|Home|Life","groupBy":true,"width":"10%"},{"name":"Status","type":"picklist","values":"Covered|Uncovered|Disputed|Other","width":"15%"},{"name":"Cover Amount","type":"number(6,2)","width":"20%","subtotal":true},{"name":"Beneficiary","type":"text","width":"35%"}],"refreshClass":"lqcInsurancePolicies","canAddRows":true},{"name":"fixedProperties","title":"Fixed Properties","columns":[{"name":"Title Deed Nbr","type":"textLink","width":"20%"},{"name":"Property Type","type":"text","width":"10%"},{"name":"Property Desc","type":"text","width":"15%"},{"name":"Provisional Value","type":"number(6,2)","width":"15%","subtotal":true},{"name":"Address","type":"text","width":"30%"},{"name":"Document OCR","type":"picklist","values":"No|Success|Failed","width":"10%"}],"refreshClass":"lqcFixedProperties","canAddRows":true},{"name":"shares","title":"Shares","columns":[{"name":"Share Name/Holding","type":"text","width":"30%"},{"name":"Number of Shares","type":"number","width":"20%"},{"name":"Current Value","type":"number(6,2)","width":"30%","subtotal":true},{"name":"Status","type":"text","width":"20%"}],"refreshClass":"lqcShares","canAddRows":true},{"name":"otherAssets","title":"Other Assets","columns":[{"name":"Asset","type":"text","width":"30%"},{"name":"Type","type":"picklist","values":"Firearms|Fixed Asset|Listed Shares|Part Bonds/Growth Funds|Live Stock|Favourable Bonds|Cash and Investments|Unit Trusts and Portfolios|Vehicles|Businesses|Funeral Details|Creditors|Consumer Services","width":"20%"},{"name":"Value","type":"number(6,2)","width":"20%","subtotal":true},{"name":"Status","type":"text","width":"15%"},{"name":"Owner","type":"text","width":"15%"}],"refreshClass":"lqcOtherAssets","canAddRows":true},{"name":"estimatedEstateValue","title":"Estimated Estate Value","type":"report","reportTitle":"Estimated Net Estate Value","currencyCode":"ZAR"}]}';

  global void onInstall(InstallContext context) {
    assertConfigObjectExists(CONFIG_OBJECT, CONFIG_VALUE_FIELD);
    if (!recordExists(DEFAULT_CONFIG_DEV_NAME)) {
      enqueueDefaultConfigRecord();
    }
  }

  /**
   * @description Confirms the given object and field exist in this org, throwing to abort
   * the install when they don't. Takes the names as parameters (rather than reading the
   * CONFIG_OBJECT/CONFIG_VALUE_FIELD constants directly) purely so tests can prove both
   * branches deterministically without depending on whether Custom_Configuration__mdt
   * happens to be deployed in the org running the test.
   * @param objectApiName API name of the object expected to exist.
   * @param fieldApiName API name of the field expected to exist on that object.
   * @throws LqcPostInstallException When the object or field cannot be found.
   */
  @TestVisible
  private static void assertConfigObjectExists(
    String objectApiName,
    String fieldApiName
  ) {
    Schema.SObjectType objectType = Schema.getGlobalDescribe()
      .get(objectApiName);
    Boolean fieldExists =
      objectType != null &&
      objectType.getDescribe().fields.getMap().containsKey(fieldApiName);
    if (!fieldExists) {
      throw new LqcPostInstallException(
        CONFIG_OBJECT +
          ' (with a ' +
          CONFIG_VALUE_FIELD +
          ' field) was not found in this org. Create it - see ' +
          'examples/fsc-estate-case-demo - before installing this package.'
      );
    }
  }

  @TestVisible
  private static Boolean recordExists(String devName) {
    List<SObject> existing = Database.query(
      'SELECT Id FROM ' +
        CONFIG_OBJECT +
        ' WHERE DeveloperName = :devName LIMIT 1'
    );
    return !existing.isEmpty();
  }

  /**
   * @description Enqueues an asynchronous Metadata API deployment that creates the DE_LQC
   * record. Custom metadata records can only be written through the Metadata API, so this
   * completes shortly after onInstall() returns, not within the install transaction itself.
   */
  @TestVisible
  private static void enqueueDefaultConfigRecord() {
    Metadata.CustomMetadata record = new Metadata.CustomMetadata();
    record.fullName = CONFIG_OBJECT + '.' + DEFAULT_CONFIG_DEV_NAME;
    record.label = 'DE Liquidity Calculator';
    Metadata.CustomMetadataValue value = new Metadata.CustomMetadataValue();
    value.field = CONFIG_VALUE_FIELD;
    value.value = DEFAULT_CONFIG_JSON;
    record.values.add(value);

    Metadata.DeployContainer container = new Metadata.DeployContainer();
    container.addMetadata(record);
    Metadata.Operations.enqueueDeployment(container, null);
  }

  private class LqcPostInstallException extends Exception {
  }
}
