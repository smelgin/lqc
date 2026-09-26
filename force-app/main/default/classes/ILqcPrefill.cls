/**
 * @description Contract for LQC tab prefill providers. Implementations are instantiated
 * dynamically by LqcController.refreshRows using the class name configured in
 * LQC_Config__mdt (tabs[N].refreshClass).
 *
 * Each returned row is a map of columnKey => value, where columnKey is the camelCase key
 * derived from the column label (see LqcController.fieldKey). For textLink columns, an
 * additional "<columnKey>RecordId" entry may be provided so the UI can render a link to
 * that record.
 * @author Ernesto S Melgin
 */
public interface ILqcPrefill {
  /**
   * @description Builds the prefill rows for one LQC tab.
   * @param recordId Id of the record the Liquidity Calculator is placed on (the Case).
   * @return List of rows, each a map of columnKey => value.
   */
  List<Map<String, Object>> refresh(Id recordId);
}
