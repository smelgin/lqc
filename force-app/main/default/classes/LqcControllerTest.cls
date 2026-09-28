/**
 * @description Unit tests for LqcController itself, using in-package test doubles for
 * ILqcStorage/ILqcPrefill/Custom_Configuration__mdt (configOverride). None of those three
 * are part of this package - the concrete storage/prefill implementations and the CMDT
 * record they're wired up through both live outside this package in
 * examples/fsc-estate-case-demo and are covered end to end by LqcFscExampleProvidersTest
 * there.
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

  /**
   * Custom_Configuration__mdt is not part of this package (see
   * LqcController.queryConfigJson) - it's created by the post-install script in a real
   * install, or by hand otherwise. This package's own suite exercises getConfig() through
   * configOverride instead of depending on a record actually existing; the real, deployed
   * DE_LQC record is covered end to end by LqcFscExampleProvidersTest in examples/.
   */
  @IsTest
  static void getConfigReturnsOverriddenJson() {
    LqcController.configOverride = new Map<String, String>{
      'DE_LQC' => '{"storageClass":"lqcEstateCaseStorage","tabs":[]}'
    };
    try {
      String config = LqcController.getConfig(null);
      Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(
        config
      );
      System.assert(
        parsed.containsKey('tabs'),
        'Config should contain a tabs array'
      );
    } finally {
      LqcController.configOverride = null;
    }
  }

  @IsTest
  static void getConfigThrowsForUnknownName() {
    LqcController.configOverride = new Map<String, String>{
      'DE_LQC' => '{"tabs":[]}'
    };
    try {
      LqcController.getConfig('DoesNotExist');
      System.assert(false, 'Expected AuraHandledException');
    } catch (AuraHandledException e) {
      System.assert(true);
    } finally {
      LqcController.configOverride = null;
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
    LqcController.configOverride = new Map<String, String>{
      'DE_LQC' => '{"tabs":[]}'
    };
    try {
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
    } finally {
      LqcController.configOverride = null;
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
