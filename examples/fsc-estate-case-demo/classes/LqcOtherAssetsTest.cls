/**
 * REFERENCE IMPLEMENTATION - lives in /examples, not inside the LQC managed
 * package. Deploy this whole bundle (examples/fsc-estate-case-demo) alongside
 * the installed package to run these tests.
 *
 * @description Tests for LqcOtherAssets, the "Other Assets" tab's PLACEHOLDER
 * ILqcPrefill provider.
 */
@IsTest
private class LqcOtherAssetsTest {
  @IsTest
  static void returnsItsStubRows() {
    Id recordId = LqcTestIds.next(Case.SObjectType);

    List<Map<String, Object>> rows = new LqcOtherAssets().refresh(recordId);

    System.assertEquals(2, rows.size());
    for (Map<String, Object> row : rows) {
      System.assertNotEquals(null, row.get('asset'));
      System.assertNotEquals(null, row.get('type'));
      System.assertNotEquals(null, row.get('value'));
    }
  }

  /**
   * LqcController.refreshRows() instantiates this class dynamically with
   * Type.forName('', className).newInstance() from inside the packaged absa1 namespace -
   * that requires LqcOtherAssets to be global, not public (see LqcShares.cls's class doc
   * comment). A regression here would pass the direct-call test above but break at runtime
   * through the real LWC call path.
   */
  @IsTest
  static void dispatchesThroughLqcController() {
    Case c = LqcFscTestData.makeCase();

    String rowsJson = absa1.LqcController.refreshRows('LqcOtherAssets', c.Id);

    System.assertEquals(
      2,
      ((List<Object>) JSON.deserializeUntyped(rowsJson)).size()
    );
  }
}
