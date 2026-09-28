/**
 * Test helper for this examples bundle - lives in /examples, not inside the
 * LQC managed package.
 *
 * @description Generates syntactically valid, unique SObject Ids without DML.
 *
 * Needed because parts of the FSC model are read-only in the API (FinancialAccountBalance)
 * and cannot be inserted from Apex tests, so the logic that consumes them is tested against
 * in-memory data instead.
 *
 * FFLIB note: once fflib-apex-mocks is in place, prefer fflib_IDGenerator.generate(SObjectType)
 * and drop this class.
 * @author Ernesto S Melgin
 */
@IsTest
public class LqcTestIds {
  private static Integer counter = 1;

  /**
   * @description Builds a unique, syntactically valid Id for the given SObject type.
   * @param sobjectType SObject type the Id's key prefix must match.
   * @return A new, unique Id for that type.
   */
  public static Id next(Schema.SObjectType sobjectType) {
    String suffix = String.valueOf(counter++);
    return Id.valueOf(
      sobjectType.getDescribe().getKeyPrefix() +
        '0'.repeat(12 - suffix.length()) +
        suffix
    );
  }
}
