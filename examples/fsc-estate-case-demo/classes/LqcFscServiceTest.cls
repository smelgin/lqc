/**
 * REFERENCE IMPLEMENTATION - lives in /examples, not inside the LQC managed
 * package. Deploy this whole bundle (examples/fsc-estate-case-demo) alongside
 * the installed package to run these tests.
 *
 * @description Tests for LqcFscService, the shared FSC query/ownership helper the prefill
 * providers reuse. Requires Financial Services Cloud enabled on the org.
 */
@IsTest
private class LqcFscServiceTest {
  /**
   * FinancialAccountBalance rows are read-only in the API (written by the FSC integration),
   * so the balance selection logic is verified directly rather than through DML.
   */
  @IsTest
  static void balanceForPicksTheFirstAvailableTypeByPreference() {
    Id accountId = LqcTestIds.next(FinancialAccount.SObjectType);
    Map<Id, Map<String, Decimal>> balances = new Map<Id, Map<String, Decimal>>{
      accountId => new Map<String, Decimal>{
        LqcFscService.BALANCE_TOTAL => 13000,
        LqcFscService.BALANCE_CURRENT_POSTED => 12500
      }
    };

    System.assertEquals(
      12500,
      LqcFscService.balanceFor(
        balances,
        accountId,
        new List<String>{
          LqcFscService.BALANCE_CURRENT_POSTED,
          LqcFscService.BALANCE_TOTAL
        }
      ),
      'The preferred type wins'
    );
    System.assertEquals(
      13000,
      LqcFscService.balanceFor(
        balances,
        accountId,
        new List<String>{ 'Available Credit', LqcFscService.BALANCE_TOTAL }
      ),
      'Falls through to the next available type'
    );
    System.assertEquals(
      null,
      LqcFscService.balanceFor(
        balances,
        accountId,
        new List<String>{ 'Available Credit' }
      ),
      'Null when no preferred type is present'
    );
    System.assertEquals(
      null,
      LqcFscService.balanceFor(
        balances,
        LqcTestIds.next(FinancialAccount.SObjectType),
        new List<String>{ LqcFscService.BALANCE_TOTAL }
      ),
      'Null when the account has no balance rows'
    );
  }

  @IsTest
  static void fscServiceHandlesEmptyInputs() {
    Account deceased = LqcFscTestData.makeDeceased();
    // Owns nothing: the party query short-circuits before the account query.
    System.assertEquals(
      0,
      LqcFscService.financialAccountsForDeceased(
          deceased.Id,
          new Set<String>{ 'Checking' }
        )
        .size()
    );
    System.assertEquals(
      0,
      LqcFscService.balancesByAccount(new Set<Id>()).size(),
      'No accounts means no balance query'
    );
  }

  @IsTest
  static void deceasedAccountIdReturnsTheCasesAccount() {
    Account deceased = LqcFscTestData.makeDeceased();
    Case c = LqcFscTestData.makeCaseFor(deceased);

    System.assertEquals(deceased.Id, LqcFscService.deceasedAccountId(c.Id));
  }

  @IsTest
  static void deceasedAccountIdThrowsWhenTheCaseHasNoAccount() {
    Case c = LqcFscTestData.makeCase(); // AccountId is blank
    try {
      LqcFscService.deceasedAccountId(c.Id);
      System.assert(false, 'Should fail without a Deceased Account');
    } catch (AuraHandledException e) {
      System.assert(true);
    }
  }

  @IsTest
  static void displayNumberFallsBackToTheRecordName() {
    System.assertEquals(
      'ACC-1',
      LqcFscService.displayNumber(
        new FinancialAccount(Name = 'Cheque', FinancialAccountNumber = 'ACC-1')
      )
    );
    System.assertEquals(
      'Cheque',
      LqcFscService.displayNumber(new FinancialAccount(Name = 'Cheque')),
      'A blank account number falls back to the Name'
    );
  }
}
