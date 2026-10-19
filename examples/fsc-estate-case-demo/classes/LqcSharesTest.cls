/**
 * REFERENCE IMPLEMENTATION - lives in /examples, not inside the LQC managed
 * package. Deploy this whole bundle (examples/fsc-estate-case-demo) alongside
 * the installed package to run these tests.
 *
 * @description Tests for LqcShares, the "Shares" tab's PLACEHOLDER ILqcPrefill provider.
 */
@IsTest
private class LqcSharesTest {
  @IsTest
  static void returnsItsStubRows() {
    Id recordId = LqcTestIds.next(Case.SObjectType);

    List<Map<String, Object>> rows = new LqcShares().refresh(recordId);

    System.assertEquals(2, rows.size());
    for (Map<String, Object> row : rows) {
      System.assertEquals(recordId, row.get('shareNameHoldingRecordId'));
      System.assertNotEquals(null, row.get('numberOfShares'));
      System.assertNotEquals(null, row.get('currentValue'));
    }
  }

  /**
   * LqcController.refreshRows() dispatches by className via Type.forName('', className), and
   * the shipped DE_LQC config uses lowerCamelCase names (e.g. "lqcShares") rather than the
   * class name itself - this must still resolve to LqcShares. This is also the test that
   * first caught this class needing to be global rather than public - see its class doc
   * comment: Type.newInstance() can't construct a public class from a different namespace,
   * so this dispatch silently throws at runtime (though it compiles and deploys cleanly)
   * until the class is global.
   */
  @IsTest
  static void isResolvedByItsLowerCamelCaseDispatchName() {
    Case c = LqcFscTestData.makeCase();

    String rowsJson = absa1.LqcController.refreshRows('lqcShares', c.Id);

    List<Object> rows = (List<Object>) JSON.deserializeUntyped(rowsJson);
    System.assertEquals(2, rows.size());
  }
}
