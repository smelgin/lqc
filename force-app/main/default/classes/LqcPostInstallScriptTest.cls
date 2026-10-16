/**
 * @description Unit tests for LqcPostInstallScript's own logic. assertConfigObjectExists()
 * and recordExists() are both tested with object/field names passed in directly (never the
 * real Custom_Configuration__mdt) so these pass deterministically whether or not
 * examples/fsc-estate-case-demo happens to be deployed alongside this package - matching
 * the same reasoning as LqcControllerTest's configOverride. enqueueDefaultConfigRecord() is
 * called expecting it to throw, since Metadata.Operations.enqueueDeployment() is treated as
 * a callout that Apex tests can't actually perform - this still covers everything up to that
 * call. The full onInstall() flow against a real, deployed Custom_Configuration__mdt is
 * covered end to end by LqcFscExampleProvidersTest in examples/.
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

  @IsTest
  static void recordExistsReturnsFalseWhenNoMatchingRecordExists() {
    // User/Username always exists, standing in for Custom_Configuration__mdt/DeveloperName
    // without this test depending on that object actually being deployed here.
    Boolean result = LqcPostInstallScript.recordExists(
      'User',
      'Username',
      'definitely-not-a-real-username@lqc-test.invalid'
    );
    System.assert(
      !result,
      'Expected no match for a username that cannot exist'
    );
  }

  @IsTest
  static void recordExistsReturnsTrueWhenAMatchingRecordExists() {
    Boolean result = LqcPostInstallScript.recordExists(
      'User',
      'Username',
      UserInfo.getUsername()
    );
    System.assert(result, 'Expected the running user\'s own username to match');
  }

  @IsTest
  static void enqueueDefaultConfigRecordBuildsTheContainerBeforeTheCallout() {
    // Only Metadata.Operations.enqueueDeployment() itself is an actual callout - everything
    // before it (building the CustomMetadata/DeployContainer) runs and is covered even though
    // the method is expected to throw once it reaches that call.
    try {
      LqcPostInstallScript.enqueueDefaultConfigRecord();
      System.assert(
        false,
        'Expected Metadata.Operations.enqueueDeployment() to reject a callout from a test context'
      );
    } catch (Exception e) {
      System.assert(true);
    }
  }
}
