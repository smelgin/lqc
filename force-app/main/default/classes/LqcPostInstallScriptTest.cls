/**
 * @description Unit tests for LqcPostInstallScript's own logic. assertConfigObjectExists()
 * is tested with object/field names passed in directly (never the real
 * Custom_Configuration__mdt) so these pass deterministically whether or not
 * examples/fsc-estate-case-demo happens to be deployed alongside this package - matching
 * the same reasoning as LqcControllerTest's configOverride. The full onInstall() flow
 * (recordExists/enqueueDefaultConfigRecord) against a real, deployed
 * Custom_Configuration__mdt is covered end to end by LqcFscExampleProvidersTest in
 * examples/.
 * @author Ernesto S Melgin
 */
@IsTest
private class LqcPostInstallScriptTest {
  @IsTest
  static void assertConfigObjectExistsThrowsWhenObjectIsMissing() {
    try {
      LqcPostInstallScript.assertConfigObjectExists(
        'Definitely_Not_A_Real_Object__mdt',
        'Value__c'
      );
      System.assert(false, 'Expected an exception for a nonexistent object');
    } catch (Exception e) {
      System.assert(
        e.getMessage().contains('Custom_Configuration__mdt'),
        'The abort message should name the missing object'
      );
    }
  }

  @IsTest
  static void assertConfigObjectExistsThrowsWhenFieldIsMissing() {
    try {
      // Case is real, but this field isn't - proves the field check independently of the
      // object check.
      LqcPostInstallScript.assertConfigObjectExists(
        'Case',
        'Definitely_Not_A_Real_Field__c'
      );
      System.assert(false, 'Expected an exception for a nonexistent field');
    } catch (Exception e) {
      System.assert(true);
    }
  }

  @IsTest
  static void assertConfigObjectExistsPassesWhenBothAreReal() {
    // Case.Subject always exists, standing in for a real Custom_Configuration__mdt.Value__c
    // without this test depending on that object actually being deployed here.
    try {
      LqcPostInstallScript.assertConfigObjectExists('Case', 'Subject');
      System.assert(true);
    } catch (Exception e) {
      System.assert(
        false,
        'Did not expect an exception for a real object/field: ' + e.getMessage()
      );
    }
  }
}
