/**
 * REFERENCE IMPLEMENTATION - lives in /examples, not inside the LQC managed
 * package. Deploy this whole bundle (examples/fsc-estate-case-demo) alongside
 * the installed package to run these tests.
 *
 * @description Tests for LqcCreditAccounts, the "Credit Accounts" tab's ILqcPrefill provider.
 * Requires Financial Services Cloud enabled on the org.
 */
@IsTest
private class LqcCreditAccountsTest {
  @IsTest
  static void requiresTheDeceasedAccount() {
    Case withoutDeceased = LqcFscTestData.makeCase(); // AccountId is blank
    try {
      new LqcCreditAccounts().refresh(withoutDeceased.Id);
      System.assert(false, 'Should fail without a Deceased Account');
    } catch (AuraHandledException e) {
      System.assert(true);
    }
  }

  @IsTest
  static void includeJointHoldingsViaParties() {
    Account deceased = LqcFscTestData.makeDeceased();
    Account spouse = new Account(Name = 'Surviving Spouse');
    insert spouse;
    Case c = LqcFscTestData.makeCaseFor(deceased);

    FinancialAccount ownLoan = LqcFscTestData.makeFinancialAccount('Loan');
    // Outstanding amount present: used in preference to a balance row.
    ownLoan.TotalOutstandingAmount = 15000;
    // Jointly held: two Owner-role parties on the same account.
    FinancialAccount jointCard = LqcFscTestData.makeFinancialAccount(
      'Credit Card'
    );
    insert new List<FinancialAccount>{ ownLoan, jointCard };
    insert new List<FinancialAccountParty>{
      LqcFscTestData.makeOwnerParty(ownLoan, deceased),
      LqcFscTestData.makeOwnerParty(jointCard, spouse),
      LqcFscTestData.makeOwnerParty(jointCard, deceased)
    };

    Test.startTest();
    List<Map<String, Object>> rows = new LqcCreditAccounts().refresh(c.Id);
    Test.stopTest();

    System.assertEquals(
      2,
      rows.size(),
      'Solely and jointly held liability accounts both qualify'
    );
    for (Map<String, Object> row : rows) {
      Decimal balance = (Decimal) row.get('balanceAtDod');
      if ((String) row.get('accountNumber') == 'ACC-Loan') {
        System.assertEquals(
          15000,
          balance,
          'TotalOutstandingAmount is preferred over a balance row'
        );
      } else {
        System.assertEquals(
          null,
          balance,
          'No TotalOutstandingAmount and no balance row (read-only, unseedable in tests) means null'
        );
      }
    }
  }

  /**
   * LqcController.refreshRows() instantiates this class dynamically with
   * Type.forName('', className).newInstance() from inside the packaged absa0 namespace -
   * that requires LqcCreditAccounts to be global, not public (see LqcShares.cls's class doc
   * comment). A regression here would pass direct-call tests above but break at runtime
   * through the real LWC call path.
   */
  @IsTest
  static void dispatchesThroughLqcController() {
    Case c = LqcFscTestData.makeCaseFor(LqcFscTestData.makeDeceased());

    String rowsJson = absa0.LqcController.refreshRows(
      'LqcCreditAccounts',
      c.Id
    );

    System.assertEquals(
      0,
      ((List<Object>) JSON.deserializeUntyped(rowsJson)).size(),
      'No accounts means no rows, but the dispatch itself must not throw'
    );
  }
}
