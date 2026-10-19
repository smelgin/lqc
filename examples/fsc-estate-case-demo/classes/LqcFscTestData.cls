/**
 * Test helper for this examples bundle - lives in /examples, not inside the
 * LQC managed package.
 *
 * @description Shared record builders and setup for the per-class test suites below
 * (LqcDebitAccountsTest, LqcCreditAccountsTest, LqcInsurancePoliciesTest,
 * LqcEstateCaseStorageTest, LqcFscServiceTest), so each test class doesn't redeclare the
 * same Case/Account/FinancialAccount/FinancialAccountParty fixtures.
 * @author Ernesto S Melgin
 */
@IsTest
public class LqcFscTestData {
  public static Case makeCase() {
    Case c = new Case(
      Subject = 'LQC Test Case',
      Status = 'New',
      Origin = 'Web'
    );
    insert c;
    return c;
  }

  public static Account makeDeceased() {
    Account deceased = new Account(Name = 'Deceased Person');
    insert deceased;
    return deceased;
  }

  /** Case linked to the Deceased through the standard Account lookup. */
  public static Case makeCaseFor(Account deceased) {
    Case c = new Case(
      Subject = 'LQC Test Case',
      Status = 'New',
      Origin = 'Web',
      AccountId = deceased.Id
    );
    insert c;
    return c;
  }

  public static FinancialAccount makeFinancialAccount(String accountType) {
    return new FinancialAccount(
      Name = accountType + ' account',
      Type = accountType,
      FinancialAccountNumber = 'ACC-' + accountType,
      Status = 'Active'
    );
  }

  /**
   * Ownership in the standard model: an Owner-role party row whose date window is currently
   * open. IsRoleActive is read-only in the API, so the dates are what both the provider and
   * these tests rely on.
   */
  public static FinancialAccountParty makeOwnerParty(
    FinancialAccount financialAccount,
    Account owner
  ) {
    return new FinancialAccountParty(
      FinancialAccountId = financialAccount.Id,
      AccountId = owner.Id,
      Role = 'Owner',
      RoleStartDate = Date.today().addDays(-30)
    );
  }

  /**
   * @description Assigns LQC_Estate_Case_Access to the running user so LqcEstateCaseStorage's
   * USER_MODE queries against Estate_Case__c.Case__c/LQC_Result__c can see those fields -
   * deploying a custom field via the Metadata API grants no profile access to it, not even to
   * System Administrator. Skipped when already assigned (e.g. a real user who followed the
   * README) since PermissionSetAssignment is setup data - visible, and enforced as unique, in
   * every test's transaction regardless of @testSetup.
   */
  public static void assignEstateCaseAccess() {
    Id userId = UserInfo.getUserId();
    PermissionSet ps = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'LQC_Estate_Case_Access'
      LIMIT 1
    ];
    Boolean alreadyAssigned = ![
        SELECT Id
        FROM PermissionSetAssignment
        WHERE AssigneeId = :userId AND PermissionSetId = :ps.Id
        LIMIT 1
      ]
      .isEmpty();
    if (!alreadyAssigned) {
      insert new PermissionSetAssignment(
        AssigneeId = userId,
        PermissionSetId = ps.Id
      );
    }
  }
}
