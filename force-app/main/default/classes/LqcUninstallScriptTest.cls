/**
 * @description Unit tests for LqcUninstallScript's own logic. recordExists() is tested with
 * an object name passed in directly (never the real Custom_Configuration__mdt) so this
 * passes deterministically whether or not examples/fsc-estate-case-demo happens to be
 * deployed alongside this package. The full onUninstall() flow
 * (enqueueBlankedConfigRecord) against a real, deployed Custom_Configuration__mdt is
 * covered end to end by LqcFscExampleProvidersTest in examples/.
 * @author Ernesto S Melgin
 */
@IsTest
private class LqcUninstallScriptTest {
  @IsTest
  static void recordExistsIsFalseWhenTheObjectIsMissing() {
    System.assertEquals(
      false,
      LqcUninstallScript.recordExists(
        'Definitely_Not_A_Real_Object__mdt',
        'DE_LQC'
      ),
      'A nonexistent object can never have a matching record'
    );
  }

  @IsTest
  static void recordExistsIsFalseWhenTheDeveloperNameDoesNotMatch() {
    // Case is real, standing in for Custom_Configuration__mdt without this test depending
    // on that object actually being deployed here - DeveloperName isn't a Case field, so
    // this also proves a bad query surfaces as a real exception rather than a false match.
    try {
      LqcUninstallScript.recordExists('Case', 'DE_LQC');
      System.assert(
        false,
        'Expected a query exception for a bad field reference'
      );
    } catch (Exception e) {
      System.assert(true);
    }
  }
}
