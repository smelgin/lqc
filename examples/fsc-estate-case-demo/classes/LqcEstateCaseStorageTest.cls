/**
 * REFERENCE IMPLEMENTATION - lives in /examples, not inside the LQC managed
 * package. Deploy this whole bundle (examples/fsc-estate-case-demo) alongside
 * the installed package to run these tests.
 *
 * @description Tests for LqcEstateCaseStorage, the default ILqcStorage strategy, plus the
 * bundle-level wiring that resolves to it: the shipped DE_LQC template, and
 * LqcPostInstallScript's "already exists" branch once this bundle's CMDT is deployed.
 */
@IsTest
private class LqcEstateCaseStorageTest {
  /**
   * LqcEstateCaseStorage reads/writes Estate_Case__c under USER_MODE, but deploying a custom
   * field via the Metadata API grants no profile access to it - not even to System
   * Administrator. Assign the bundled permission set so the running user can see
   * Case__c/LQC_Result__c, the same way a real org would need to for the Liquidity
   * Calculator's actual users.
   */
  @TestSetup
  static void setup() {
    LqcFscTestData.assignEstateCaseAccess();
  }

  @IsTest
  static void saveCreatesTheEstateCaseAndLoadReturnsTheSamePayload() {
    Case c = LqcFscTestData.makeCase();
    LqcEstateCaseStorage storage = new LqcEstateCaseStorage();
    String payload = '{"version":1,"published":false,"tabs":{"shares":[]}}';

    Test.startTest();
    System.assertEquals(null, storage.load(c.Id));
    storage.save(c.Id, payload);
    storage.save(c.Id, payload);
    String stored = storage.load(c.Id);
    Test.stopTest();

    System.assertEquals(payload, stored, 'Saved payload should round-trip');
    System.assertEquals(
      1,
      [SELECT COUNT() FROM Estate_Case__c],
      'Saving twice must reuse the same Estate Case'
    );
  }

  @IsTest
  static void estateCaseStorageFindsTheCaseLookup() {
    String lookup = LqcEstateCaseStorage.caseLookup();
    System.assert(
      String.isNotBlank(lookup),
      'Estate_Case__c must expose a lookup to Case'
    );
  }

  @IsTest
  static void estateCaseStorageDiscoversTheLookupAndIgnoresOtherFields() {
    // Falls back to scanning when the preferred name is absent, and still
    // lands on the same Case lookup.
    System.assertEquals(
      LqcEstateCaseStorage.caseLookup(),
      LqcEstateCaseStorage.discoverCaseLookup('Not_A_Real_Field__c'),
      'The fallback scan must find the same Case lookup'
    );

    Map<String, Schema.SObjectField> fields = Estate_Case__c.SObjectType.getDescribe()
      .fields.getMap();
    System.assertEquals(
      false,
      LqcEstateCaseStorage.referencesCase(fields.get('Name')),
      'A non-reference field does not reference Case'
    );
    System.assertEquals(
      false,
      LqcEstateCaseStorage.referencesCase(fields.get('OwnerId')),
      'A reference to something other than Case does not qualify'
    );
  }

  /**
   * Custom_Configuration__mdt and its DE_LQC record live in this bundle, not the package
   * (see absa1.LqcController.queryConfigJson) - a real install creates DE_LQC via
   * LqcPostInstallScript, but for a source deploy like this one it's just part of
   * examples/fsc-estate-case-demo/customMetadata. Proves the shipped template still points
   * at this documented example storage class. Parses getConfig()'s JSON directly rather than
   * calling absa1.LqcController.storageClassName(): that method is private to the package, so
   * unpackaged code in this bundle can't reach it across the package boundary.
   */
  @IsTest
  static void defaultConfigNamesThisDocumentedExampleStorageClass() {
    Map<String, Object> config = (Map<String, Object>) JSON.deserializeUntyped(
      absa1.LqcController.getConfig(null)
    );
    System.assertEquals(
      'lqcEstateCaseStorage',
      config.get('storageClass'),
      'The shipped template should still point at the documented example storage class'
    );
  }

  /**
   * Metadata.Operations.enqueueDeployment (used by enqueueDefaultConfigRecord() when no
   * DE_LQC record exists yet) is a Metadata API callout, and callouts aren't supported in
   * Apex tests - so onInstall() can only be exercised here in the "already deployed, skip
   * creation" branch, which is exactly the state this bundle's source deploy leaves the org
   * in. The create branch is verified manually against a real install instead - see
   * examples/README.md. A plain SOQL count is used rather than
   * LqcPostInstallScript.recordExists(), also private to the package.
   */
  @IsTest
  static void postInstallScriptSkipsCreationWhenTheTemplateAlreadyExists() {
    Test.testInstall(new absa1.LqcPostInstallScript(), null);
    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM Custom_Configuration__mdt
        WHERE DeveloperName = 'DE_LQC'
      ],
      'onInstall() must not duplicate an already-existing DE_LQC record'
    );
  }

  /**
   * Proves the shipped DE_LQC template actually resolves to this class end-to-end through
   * LqcController once this examples bundle is deployed alongside the package.
   */
  @IsTest
  static void defaultConfigResolvesWhenTheExampleIsDeployed() {
    Case c = LqcFscTestData.makeCase();
    String payload = '{"version":1,"published":false,"tabs":{"shares":[]}}';

    Test.startTest();
    System.assertEquals(null, absa1.LqcController.getSavedResult(c.Id, null));
    absa1.LqcController.saveResult(c.Id, payload, null);
    absa1.LqcController.saveResult(c.Id, payload, null);
    String stored = absa1.LqcController.getSavedResult(c.Id, null);
    Test.stopTest();

    System.assertEquals(payload, stored, 'Saved payload should round-trip');
    System.assertEquals(
      1,
      [SELECT COUNT() FROM Estate_Case__c],
      'Saving twice must reuse the same Estate Case'
    );
  }
}
