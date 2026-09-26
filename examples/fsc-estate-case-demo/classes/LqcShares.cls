/**
 * REFERENCE IMPLEMENTATION - lives in /examples, not inside the LQC managed
 * package. Deploy it separately, alongside the installed package, as a
 * worked example of the packaged ILqcPrefill contract.
 *
 * @description PLACEHOLDER prefill provider for the "Shares" LQC tab. Replace the stub rows
 * with the real data source (SOQL / callout) when available.
 * @author Ernesto S Melgin
 */
public with sharing class LqcShares implements absa1.ILqcPrefill {
  /**
   * @description Returns hardcoded placeholder rows until a real shareholding data source is
   * wired up.
   * @param recordId Id of the record the Liquidity Calculator is placed on (the Case).
   * @return Stub rows for the "Shares" tab.
   */
  public List<Map<String, Object>> refresh(Id recordId) {
    // TODO v2: query the real shareholding records related to the Case.
    List<Map<String, Object>> rows = new List<Map<String, Object>>();
    rows.add(
      new Map<String, Object>{
        'shareNameHolding' => '00000064536768661',
        'shareNameHoldingRecordId' => recordId,
        'numberOfShares' => 100,
        'currentValue' => 1500000,
        'status' => 'Active'
      }
    );
    rows.add(
      new Map<String, Object>{
        'shareNameHolding' => '00000064536768661',
        'shareNameHoldingRecordId' => recordId,
        'numberOfShares' => 200,
        'currentValue' => 2500000,
        'status' => 'Sold'
      }
    );
    return rows;
  }
}
