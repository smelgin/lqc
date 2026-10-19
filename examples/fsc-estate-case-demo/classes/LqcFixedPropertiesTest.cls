/**
 * REFERENCE IMPLEMENTATION - lives in /examples, not inside the LQC managed
 * package. Deploy this whole bundle (examples/fsc-estate-case-demo) alongside
 * the installed package to run these tests.
 *
 * @description Tests for LqcFixedProperties, the "Fixed Properties" tab's PLACEHOLDER
 * ILqcPrefill provider.
 */
@IsTest
private class LqcFixedPropertiesTest {
  @IsTest
  static void returnsItsStubRows() {
    Id recordId = LqcTestIds.next(Case.SObjectType);

    List<Map<String, Object>> rows = new LqcFixedProperties().refresh(recordId);

    System.assertEquals(3, rows.size());
    for (Map<String, Object> row : rows) {
      System.assertEquals(recordId, row.get('titleDeedNbrRecordId'));
      System.assertNotEquals(null, row.get('propertyType'));
      System.assertNotEquals(null, row.get('provisionalValue'));
    }
  }

  /**
   * LqcController.refreshRows() instantiates this class dynamically with
   * Type.forName('', className).newInstance() from inside the packaged absa0 namespace -
   * that requires LqcFixedProperties to be global, not public (see LqcShares.cls's class doc
   * comment). A regression here would pass the direct-call test above but break at runtime
   * through the real LWC call path.
   */
  @IsTest
  static void dispatchesThroughLqcController() {
    Case c = LqcFscTestData.makeCase();

    String rowsJson = absa0.LqcController.refreshRows(
      'LqcFixedProperties',
      c.Id
    );

    System.assertEquals(
      3,
      ((List<Object>) JSON.deserializeUntyped(rowsJson)).size()
    );
  }
}
