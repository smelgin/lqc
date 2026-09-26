/**
 * @description Unit tests for LqcController itself, using in-package test doubles for
 * ILqcStorage/ILqcPrefill. The reference implementations that back the shipped default
 * config (LqcEstateCaseStorage, LqcFscService, the ILqcPrefill providers) live outside this
 * package in examples/fsc-estate-case-demo and are covered by
 * LqcFscExampleProvidersTest there.
 * @author Ernesto S Melgin
 */
@IsTest
private class LqcControllerTest {
  private static Case makeCase() {
    Case c = new Case(
      Subject = 'LQC Test Case',
      Status = 'New',
      Origin = 'Web'
    );
    insert c;
    return c;
  }

  @IsTest
  static void getConfigReturnsDefaultJson() {
    // Custom metadata records are visible in tests without seeAllData.
    String config = LqcController.getConfig(null);
    System.assert(
      String.isNotBlank(config),
      'Default config JSON should be returned'
    );
    Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(
      config
    );
    System.assert(
      parsed.containsKey('tabs'),
      'Config should contain a tabs array'
    );
  }

  @IsTest
  static void getConfigThrowsForUnknownName() {
    try {
      LqcController.getConfig('DoesNotExist');
      System.assert(false, 'Expected AuraHandledException');
    } catch (AuraHandledException e) {
      System.assert(true);
    }
  }

  /**
   * The controller's save/load wiring, proven against a storage strategy the
   * package itself owns end to end - no concrete ILqcStorage implementation
   * (Estate_Case__c-backed or otherwise) is part of this package, so the
   * pluggability contract is what gets tested here, not any one destination.
   */
  @IsTest
  static void saveAndReadResultRoundTripThroughAPluggableStorage() {
    Case c = makeCase();
    String payload = '{"version":1,"published":false,"tabs":{"shares":[]}}';
    LqcController.storageOverride = new InMemoryStorage();

    try {
      Test.startTest();
      System.assertEquals(null, LqcController.getSavedResult(c.Id, null));
      LqcController.saveResult(c.Id, payload, null);
      String stored = LqcController.getSavedResult(c.Id, null);
      Test.stopTest();

      System.assertEquals(payload, stored, 'Saved payload should round-trip');
    } finally {
      LqcController.storageOverride = null;
    }
  }

  /**
   * The shipped DE_LQC config intentionally names a storage class
   * (lqcEstateCaseStorage) that lives in examples/fsc-estate-case-demo, not
   * in this package - resolving it requires that bundle (or an equivalent of
   * your own) deployed alongside the package. This is a template-content
   * assertion only: it must NOT call storageFor()/Type.forName, because
   * whether that class actually resolves depends on what else is deployed
   * in the org running this test, which this package's own suite has no
   * business asserting on either way.
   */
  @IsTest
  static void defaultStorageClassNameMatchesTheDocumentedExample() {
    System.assertEquals(
      'lqcEstateCaseStorage',
      LqcController.storageClassName(LqcController.getConfig(null)),
      'The shipped template should still point at the documented example storage class'
    );
  }

  @IsTest
  static void storageClassNameDefaultsAndOverrides() {
    System.assertEquals(
      'LqcEstateCaseStorage',
      LqcController.storageClassName('{"tabs":[]}'),
      'Absent storageClass falls back to the Estate Case strategy'
    );
    System.assertEquals(
      'lqcEstateCaseStorage',
      LqcController.storageClassName(
        '{"storageClass":"lqcEstateCaseStorage","tabs":[]}'
      )
    );
    System.assertEquals(
      'LqcEstateCaseStorage',
      LqcController.storageClassName('{"storageClass":"  ","tabs":[]}'),
      'Blank storageClass falls back too'
    );
  }

  @IsTest
  static void refreshRowsRejectsInvalidClasses() {
    Case c = makeCase();
    try {
      LqcController.refreshRows('NoSuchClass', c.Id);
      System.assert(false, 'Expected AuraHandledException for missing class');
    } catch (AuraHandledException e) {
      System.assert(true);
    }
    try {
      // Exists but does not implement ILqcPrefill.
      LqcController.refreshRows('LqcController', c.Id);
      System.assert(
        false,
        'Expected AuraHandledException for non-conforming class'
      );
    } catch (AuraHandledException e) {
      System.assert(true);
    }
    try {
      LqcController.refreshRows('', c.Id);
      System.assert(
        false,
        'Expected AuraHandledException for blank class name'
      );
    } catch (AuraHandledException e) {
      System.assert(true);
    }
  }

  @IsTest
  static void fieldKeyDerivesCamelCaseKeys() {
    System.assertEquals(
      'accountNumber',
      LqcController.fieldKey('Account Number')
    );
    System.assertEquals(
      'balanceAtDod',
      LqcController.fieldKey('Balance at DoD')
    );
    System.assertEquals(
      'shareNameHolding',
      LqcController.fieldKey('Share Name/Holding')
    );
    System.assertEquals('', LqcController.fieldKey(null));
    // Leading/duplicated separators produce blank words that are skipped.
    System.assertEquals(
      'accountNumber',
      LqcController.fieldKey('  Account   Number ')
    );
    System.assertEquals(
      'titleDeedNbr',
      LqcController.fieldKey('/Title-Deed  Nbr')
    );
  }

  @IsTest
  static void storageInstanceRejectsInvalidClasses() {
    try {
      LqcController.storageInstance('NoSuchStorageClass');
      System.assert(false, 'Expected AuraHandledException for a missing class');
    } catch (AuraHandledException e) {
      System.assert(true);
    }
    try {
      // Exists but does not implement ILqcStorage.
      LqcController.storageInstance('LqcController');
      System.assert(
        false,
        'Expected AuraHandledException for a non-conforming class'
      );
    } catch (AuraHandledException e) {
      System.assert(true);
    }
  }

  @IsTest
  static void saveAndLoadRethrowConfigurationErrors() {
    Case c = makeCase();
    // An unknown config record makes getConfig throw; the controller must
    // surface it unchanged rather than wrapping it.
    try {
      LqcController.getSavedResult(c.Id, 'DoesNotExist');
      System.assert(false, 'Expected AuraHandledException on load');
    } catch (AuraHandledException e) {
      System.assert(true);
    }
    try {
      LqcController.saveResult(c.Id, '{}', 'DoesNotExist');
      System.assert(false, 'Expected AuraHandledException on save');
    } catch (AuraHandledException e) {
      System.assert(true);
    }
  }

  /** Storage strategy that always blows up, to prove errors are wrapped. */
  private class FailingStorage implements ILqcStorage {
    public String load(Id recordId) {
      throw new FailingStorageException('load exploded');
    }
    public void save(Id recordId, String payload) {
      throw new FailingStorageException('save exploded');
    }
  }

  private class FailingStorageException extends Exception {
  }

  /** In-memory storage strategy used to test the pluggable save/load contract. */
  private class InMemoryStorage implements ILqcStorage {
    private Map<Id, String> payloadsByRecordId = new Map<Id, String>();
    public String load(Id recordId) {
      return payloadsByRecordId.get(recordId);
    }
    public void save(Id recordId, String payload) {
      payloadsByRecordId.put(recordId, payload);
    }
  }

  @IsTest
  static void saveAndLoadWrapUnexpectedFailures() {
    Case c = makeCase();
    LqcController.storageOverride = new FailingStorage();
    try {
      try {
        LqcController.getSavedResult(c.Id, null);
        System.assert(false, 'Expected the load failure to be wrapped');
      } catch (Exception e) {
        System.assert(
          e instanceof AuraHandledException,
          'Storage exceptions must surface as AuraHandledException, got: ' +
          e.getTypeName()
        );
      }
      try {
        LqcController.saveResult(c.Id, '{}', null);
        System.assert(false, 'Expected the save failure to be wrapped');
      } catch (Exception e) {
        System.assert(
          e instanceof AuraHandledException,
          'Storage exceptions must surface as AuraHandledException, got: ' +
          e.getTypeName()
        );
      }
    } finally {
      LqcController.storageOverride = null;
    }
  }
}
