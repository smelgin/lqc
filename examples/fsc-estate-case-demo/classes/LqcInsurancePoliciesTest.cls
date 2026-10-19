/**
 * REFERENCE IMPLEMENTATION - lives in /examples, not inside the LQC managed
 * package. Deploy this whole bundle (examples/fsc-estate-case-demo) alongside
 * the installed package to run these tests.
 *
 * @description Tests for LqcInsurancePolicies, the "Insurance Policies" tab's ILqcPrefill
 * provider. Requires Financial Services Cloud (Insurance) enabled on the org.
 */
@IsTest
private class LqcInsurancePoliciesTest {
  @IsTest
  static void requiresTheDeceasedAccount() {
    Case withoutDeceased = LqcFscTestData.makeCase(); // AccountId is blank
    try {
      new LqcInsurancePolicies().refresh(withoutDeceased.Id);
      System.assert(false, 'Should fail without a Deceased Account');
    } catch (AuraHandledException e) {
      System.assert(true);
    }
  }

  @IsTest
  static void returnsPoliciesOfTheNamedInsured() {
    Account deceased = LqcFscTestData.makeDeceased();
    Account other = new Account(Name = 'Someone Else');
    Account beneficiaryA = new Account(Name = 'Alice Beneficiary');
    Account beneficiaryB = new Account(Name = 'Bob Beneficiary');
    insert new List<Account>{ other, beneficiaryA, beneficiaryB };
    Case c = LqcFscTestData.makeCaseFor(deceased);

    InsurancePolicy ownPolicy = new InsurancePolicy(
      Name = 'POL-001',
      NameInsuredId = deceased.Id
    );
    insert new List<InsurancePolicy>{
      ownPolicy,
      new InsurancePolicy(Name = 'POL-002', NameInsuredId = other.Id)
    };
    // Two beneficiaries on the same policy exercise the name join.
    insert new List<InsurancePolicyParticipant>{
      new InsurancePolicyParticipant(
        InsurancePolicyId = ownPolicy.Id,
        PrimaryParticipantAccountId = beneficiaryA.Id,
        Role = 'Beneficiary'
      ),
      new InsurancePolicyParticipant(
        InsurancePolicyId = ownPolicy.Id,
        PrimaryParticipantAccountId = beneficiaryB.Id,
        Role = 'Beneficiary'
      ),
      // Non-beneficiary role: must not appear.
      new InsurancePolicyParticipant(
        InsurancePolicyId = ownPolicy.Id,
        PrimaryParticipantAccountId = other.Id,
        Role = 'Insured'
      )
    };

    Test.startTest();
    List<Map<String, Object>> rows = new LqcInsurancePolicies().refresh(c.Id);
    Test.stopTest();

    System.assertEquals(1, rows.size(), 'Only the deceased policies qualify');
    Map<String, Object> row = rows[0];
    System.assertEquals('POL-001', row.get('policyNumber'));
    System.assertEquals(
      'Alice Beneficiary, Bob Beneficiary',
      row.get('beneficiary'),
      'Multiple beneficiaries are joined, non-beneficiary roles excluded'
    );
  }

  @IsTest
  static void returnsNothingWhenTheDeceasedHasNone() {
    Case c = LqcFscTestData.makeCaseFor(LqcFscTestData.makeDeceased());

    List<Map<String, Object>> rows = new LqcInsurancePolicies().refresh(c.Id);

    System.assertEquals(
      0,
      rows.size(),
      'No policies means no rows and no participant query'
    );
  }

  /**
   * LqcController.refreshRows() instantiates this class dynamically with
   * Type.forName('', className).newInstance() from inside the packaged absa0 namespace -
   * that requires LqcInsurancePolicies to be global, not public (see LqcShares.cls's class
   * doc comment). A regression here would pass direct-call tests above but break at runtime
   * through the real LWC call path.
   */
  @IsTest
  static void dispatchesThroughLqcController() {
    Case c = LqcFscTestData.makeCaseFor(LqcFscTestData.makeDeceased());

    String rowsJson = absa0.LqcController.refreshRows(
      'LqcInsurancePolicies',
      c.Id
    );

    System.assertEquals(
      0,
      ((List<Object>) JSON.deserializeUntyped(rowsJson)).size(),
      'No policies means no rows, but the dispatch itself must not throw'
    );
  }
}
