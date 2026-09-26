/**
 * REFERENCE IMPLEMENTATION - lives in /examples, not inside the LQC managed
 * package. Deploy it separately, alongside the installed package, as a
 * worked example of the packaged ILqcPrefill contract.
 *
 * @description PLACEHOLDER prefill provider for the "Fixed Properties" LQC tab (WinDeed).
 * Replace the stub rows with the real WinDeed extract when available.
 * @author Ernesto S Melgin
 */
// Once the core package is installed under a namespace, this becomes
// "implements yourNamespace.ILqcPrefill".
public with sharing class LqcFixedProperties implements ILqcPrefill {
  /**
   * @description Returns hardcoded placeholder rows until the WinDeed extract integration
   * is built.
   * @param recordId Id of the record the Liquidity Calculator is placed on (the Case).
   * @return Stub rows for the "Fixed Properties" tab.
   */
  public List<Map<String, Object>> refresh(Id recordId) {
    // TODO v2: call the WinDeed extract service for the Case.
    List<Map<String, Object>> rows = new List<Map<String, Object>>();
    rows.add(
      new Map<String, Object>{
        'titleDeedNbr' => '64536768635',
        'titleDeedNbrRecordId' => recordId,
        'propertyType' => 'House',
        'propertyDesc' => 'Type Value',
        'provisionalValue' => 10563000,
        'address' => '99 4th Street Montgomery Park',
        'documentOcr' => 'Successful OCR'
      }
    );
    rows.add(
      new Map<String, Object>{
        'titleDeedNbr' => '64536768635',
        'titleDeedNbrRecordId' => recordId,
        'propertyType' => 'Farm',
        'propertyDesc' => 'Type Value',
        'provisionalValue' => 563000,
        'address' => '99 4th Street Montgomery Park',
        'documentOcr' => 'Successful OCR'
      }
    );
    rows.add(
      new Map<String, Object>{
        'titleDeedNbr' => '64536768635',
        'titleDeedNbrRecordId' => recordId,
        'propertyType' => 'Farm',
        'propertyDesc' => 'Type Value',
        'provisionalValue' => 1982000,
        'address' => '99 4th Street Montgomery Park',
        'documentOcr' => 'Successful OCR'
      }
    );
    return rows;
  }
}
