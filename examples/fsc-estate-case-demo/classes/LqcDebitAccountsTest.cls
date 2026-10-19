/**
 * REFERENCE IMPLEMENTATION - lives in /examples, not inside the LQC managed
 * package. Deploy this whole bundle (examples/fsc-estate-case-demo) alongside
 * the installed package to run these tests.
 *
 * @description Tests for LqcDebitAccounts, the "Debit Accounts" tab's ILqcPrefill provider.
 * Requires Financial Services Cloud enabled on the org.
 */
@IsTest
private class LqcDebitAccountsTest {
  @IsTest
  static void requiresTheDeceasedAccount() {
    Case withoutDeceased = LqcFscTestData.makeCase(); // AccountId is blank
    try {
      new LqcDebitAccounts().refresh(withoutDeceased.Id);
      System.assert(false, 'Should fail without a Deceased Account');
    } catch (AuraHandledException e) {
      System.assert(true);
    }
  }

  @IsTest
  static void returnsAssetTypeAccountsOfTheDeceased() {
    Account deceased = LqcFscTestData.makeDeceased();
    Account stranger = new Account(Name = 'Someone Else');
    insert stranger;
    Case c = LqcFscTestData.makeCaseFor(deceased);

    FinancialAccount checking = LqcFscTestData.makeFinancialAccount('Checking');
    FinancialAccount savings = LqcFscTestData.makeFinancialAccount('Savings');
    FinancialAccount creditCard = LqcFscTestData.makeFinancialAccount(
      'Credit Card'
    ); // liability: excluded
    FinancialAccount strangers = LqcFscTestData.makeFinancialAccount(
      'Checking'
    ); // not the deceased
    FinancialAccount closedRole = LqcFscTestData.makeFinancialAccount(
      'Savings'
    ); // role already ended
    insert new List<FinancialAccount>{
      checking,
      savings,
      creditCard,
      strangers,
      closedRole
    };

    FinancialAccountParty endedParty = LqcFscTestData.makeOwnerParty(
      closedRole,
      deceased
    );
    endedParty.RoleEndDate = Date.today().addDays(-1);
    insert new List<FinancialAccountParty>{
      LqcFscTestData.makeOwnerParty(checking, deceased),
      LqcFscTestData.makeOwnerParty(savings, deceased),
      LqcFscTestData.makeOwnerParty(creditCard, deceased),
      LqcFscTestData.makeOwnerParty(strangers, stranger),
      endedParty
    };

    Test.startTest();
    List<Map<String, Object>> rows = new LqcDebitAccounts().refresh(c.Id);
    Test.stopTest();

    System.assertEquals(
      2,
      rows.size(),
      'Only currently-held asset accounts of the deceased qualify'
    );
    for (Map<String, Object> row : rows) {
      System.assert(
        LqcDebitAccounts.ACCOUNT_TYPES.contains((String) row.get('accountType'))
      );
      System.assertNotEquals(null, row.get('accountNumberRecordId'));
    }
  }

  /**
   * LqcController.refreshRows() instantiates this class dynamically with
   * Type.forName('', className).newInstance() from inside the packaged absa0 namespace -
   * that requires LqcDebitAccounts to be global, not public (see its class doc comment).
   * A regression here would pass direct-call tests above but break at runtime through the
   * real LWC call path.
   */
  @IsTest
  static void dispatchesThroughLqcController() {
    Case c = LqcFscTestData.makeCaseFor(LqcFscTestData.makeDeceased());

    String rowsJson = absa0.LqcController.refreshRows('LqcDebitAccounts', c.Id);

    System.assertEquals(
      0,
      ((List<Object>) JSON.deserializeUntyped(rowsJson)).size(),
      'No accounts means no rows, but the dispatch itself must not throw'
    );
  }
}
