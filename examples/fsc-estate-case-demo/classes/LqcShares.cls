/**
 * REFERENCE IMPLEMENTATION - lives in /examples, not inside the LQC managed
 * package. Deploy it separately, alongside the installed package, as a
 * worked example of the packaged ILqcPrefill contract.
 *
 * Declared global, not public: LqcController.refreshRows() resolves this class dynamically
 * with Type.forName('', className).newInstance() from inside the packaged absa1 namespace.
 * Type.newInstance() can't construct a class in a different namespace - including the
 * subscriber's local, unnamespaced one - unless that class (and so its implicit no-arg
 * constructor) is global; public only grants same-namespace access. A public implementation
 * here compiles and deploys cleanly but fails at runtime the moment LqcController actually
 * dispatches to it.
 *
 * @description PLACEHOLDER prefill provider for the "Shares" LQC tab. Replace the stub rows
 * with the real data source (SOQL / callout) when available.
 * @author Ernesto S Melgin
 */
global with sharing class LqcShares implements absa1.ILqcPrefill {
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
