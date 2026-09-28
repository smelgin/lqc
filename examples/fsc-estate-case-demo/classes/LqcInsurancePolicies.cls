/**
 * REFERENCE IMPLEMENTATION - lives in /examples, not inside the LQC managed
 * package. Deploy it separately, alongside the installed package, as a
 * worked example of the packaged ILqcPrefill contract. Copy and adapt it;
 * do not expect it to ship with the package itself.
 *
 * @description Prefill provider for the "Insurance Policies" LQC tab, backed by the FSC
 * Insurance data model (standard objects): InsurancePolicy records where the Deceased (the
 * Case's standard Account, Case.AccountId) is the Named Insured, with the beneficiary
 * resolved from InsurancePolicyParticipant.
 *
 * ------------------------------------------------------------------ FFLIB --
 * On FFLIB adoption: move both queries into an InsurancePoliciesSelector /
 * InsurancePolicyParticipantsSelector (fflib_SObjectSelector), resolved via
 * Application.Selector so tests stub them with fflib_ApexMocks; this class keeps only the
 * row-mapping. No DML here - persistence goes through ILqcStorage, which should use
 * fflib_ISObjectUnitOfWork when FFLIB lands.
 * ---------------------------------------------------------------------------
 * @author Ernesto S Melgin
 */
public with sharing class LqcInsurancePolicies implements absa1.ILqcPrefill {
  @TestVisible
  private static final String BENEFICIARY_ROLE = 'Beneficiary';

  /**
   * @description Builds one row per InsurancePolicy where the deceased is the Named Insured,
   * with beneficiaries joined into a single display string.
   * @param recordId Id of the record the Liquidity Calculator is placed on (the Case).
   * @return List of rows keyed by the "Insurance Policies" tab's column keys.
   * @throws AuraHandledException When the Case has no Account (the Deceased).
   */
  public List<Map<String, Object>> refresh(Id recordId) {
    Id deceasedId = LqcFscService.deceasedAccountId(recordId);

    List<InsurancePolicy> policies = [
      SELECT Id, Name, PolicyType, Status, PremiumAmount
      FROM InsurancePolicy
      WHERE NameInsuredId = :deceasedId
      WITH USER_MODE
      ORDER BY Name
    ];

    Map<Id, String> beneficiaryByPolicy = beneficiaryNames(policies);

    List<Map<String, Object>> rows = new List<Map<String, Object>>();
    for (InsurancePolicy policy : policies) {
      rows.add(
        new Map<String, Object>{
          'policyNumber' => policy.Name,
          'policyNumberRecordId' => policy.Id,
          'policyType' => policy.PolicyType,
          'status' => policy.Status,
          // TODO: PremiumAmount is a PLACEHOLDER. The cover amount lives
          // in your org's product design - typically a custom field such
          // as Sum_Insured__c on InsurancePolicy, or an aggregate over
          // the policy's InsurancePolicyCoverage records. Replace before
          // relying on the subtotal.
          'coverAmount' => policy.PremiumAmount,
          'beneficiary' => beneficiaryByPolicy.get(policy.Id)
        }
      );
    }
    return rows;
  }

  /**
   * @description Beneficiary participant names per policy. Multiple beneficiaries on the
   * same policy are joined with ", ".
   * @param policies Policies to resolve beneficiaries for.
   * @return Map of InsurancePolicy Id to its joined beneficiary display name.
   */
  private static Map<Id, String> beneficiaryNames(
    List<InsurancePolicy> policies
  ) {
    Map<Id, String> names = new Map<Id, String>();
    if (policies.isEmpty()) {
      return names;
    }
    for (InsurancePolicyParticipant participant : [
      SELECT InsurancePolicyId, PrimaryParticipantAccount.Name
      FROM InsurancePolicyParticipant
      WHERE InsurancePolicyId IN :policies AND Role = :BENEFICIARY_ROLE
      WITH USER_MODE
      ORDER BY PrimaryParticipantAccount.Name
    ]) {
      String participantName = participant.PrimaryParticipantAccount?.Name;
      if (String.isBlank(participantName)) {
        continue;
      }
      String existing = names.get(participant.InsurancePolicyId);
      names.put(
        participant.InsurancePolicyId,
        existing == null ? participantName : existing + ', ' + participantName
      );
    }
    return names;
  }
}
