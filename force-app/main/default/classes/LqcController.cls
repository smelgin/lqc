/**
 * @description Server-side controller for the Liquidity Calculator (LQC) LWC.
 *
 * Responsibilities:
 *  - Serve the JSON configuration stored in Custom_Configuration__mdt.
 *  - Load / persist the calculator state through the ILqcStorage strategy named by the
 *    config's "storageClass" key (defaults to LqcEstateCaseStorage).
 *  - Dynamically instantiate ILqcPrefill implementations to refresh tab rows.
 * @author Ernesto S Melgin
 */
public with sharing class LqcController {
  @TestVisible
  private static final String DEFAULT_CONFIG_DEV_NAME = 'DE_LQC';

  private static final String DEFAULT_STORAGE_CLASS = 'LqcEstateCaseStorage';

  /**
   * @description Returns the raw JSON configuration for the LQC tabs, stored in the shared
   * Custom_Configuration__mdt CMT (default record: DE_LQC).
   * @param configName DeveloperName of the Custom_Configuration__mdt record to load, or
   * null/blank to use the default (DE_LQC).
   * @return The configuration's raw JSON (Value__c).
   * @throws AuraHandledException When no matching, non-blank configuration record exists.
   */
  @AuraEnabled(cacheable=true)
  public static String getConfig(String configName) {
    String devName = String.isBlank(configName)
      ? DEFAULT_CONFIG_DEV_NAME
      : configName;
    List<Custom_Configuration__mdt> configs = [
      SELECT Value__c
      FROM Custom_Configuration__mdt
      WHERE DeveloperName = :devName
      LIMIT 1
    ];
    if (configs.isEmpty() || String.isBlank(configs[0].Value__c)) {
      throw new AuraHandledException(
        'LQC configuration "' +
          devName +
          '" was not found in Custom_Configuration__mdt.'
      );
    }
    return configs[0].Value__c;
  }

  /**
   * @description Returns the previously saved LQC payload for the given record, or null.
   * Delegates to the ILqcStorage strategy named in the JSON config.
   * @param recordId Id of the record the Liquidity Calculator is placed on (the Case).
   * @param configName DeveloperName of the Custom_Configuration__mdt record to use, or
   * null/blank to use the default.
   * @return The previously saved JSON payload, or null when nothing has been saved yet.
   * @throws AuraHandledException When the configuration or storage strategy cannot be
   * resolved, or the underlying strategy fails to load.
   */
  @AuraEnabled
  public static String getSavedResult(Id recordId, String configName) {
    try {
      return storageFor(configName).load(recordId);
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Unable to load saved LQC data: ' + e.getMessage()
      );
    }
  }

  /**
   * @description Persists the LQC payload (rows of every tab plus the published flag)
   * through the configured ILqcStorage strategy. Used by Save and Publish.
   * @param recordId Id of the record the Liquidity Calculator is placed on (the Case).
   * @param payload Serialized Liquidity Calculator state to persist.
   * @param configName DeveloperName of the Custom_Configuration__mdt record to use, or
   * null/blank to use the default.
   * @throws AuraHandledException When the configuration or storage strategy cannot be
   * resolved, or the underlying strategy fails to save.
   */
  @AuraEnabled
  public static void saveResult(
    Id recordId,
    String payload,
    String configName
  ) {
    try {
      storageFor(configName).save(recordId, payload);
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Unable to save LQC data: ' + e.getMessage()
      );
    }
  }

  /* ------------------------------------------------------------ storage */

  /**
   * @description Injection seam for tests. FFLIB replaces this with
   * Application.Service/Selector mocking - see ILqcStorage.
   */
  @TestVisible
  private static ILqcStorage storageOverride;

  /**
   * @description Instantiates the storage strategy named by the config's "storageClass"
   * key, falling back to LqcEstateCaseStorage. The class name comes from Custom Metadata
   * (admin-controlled), never from the browser.
   * @param configName DeveloperName of the Custom_Configuration__mdt record to read
   * "storageClass" from, or null/blank to use the default configuration.
   * @return The resolved ILqcStorage strategy (storageOverride when set, for tests).
   * @throws AuraHandledException When the configured class cannot be found or does not
   * implement ILqcStorage.
   */
  @TestVisible
  private static ILqcStorage storageFor(String configName) {
    return storageOverride != null
      ? storageOverride
      : storageInstance(storageClassName(getConfig(configName)));
  }

  /**
   * @description Instantiates and validates a storage strategy by class name.
   * @param className Fully qualified Apex class name expected to implement ILqcStorage.
   * @return A new instance of the named class, cast to ILqcStorage.
   * @throws AuraHandledException When the class cannot be found or does not implement
   * ILqcStorage.
   */
  @TestVisible
  private static ILqcStorage storageInstance(String className) {
    Type storageType = Type.forName(className);
    if (storageType == null) {
      throw new AuraHandledException(
        'Storage class "' + className + '" was not found.'
      );
    }
    Object instance = storageType.newInstance();
    if (!(instance instanceof ILqcStorage)) {
      throw new AuraHandledException(
        'Class "' + className + '" does not implement ILqcStorage.'
      );
    }
    return (ILqcStorage) instance;
  }

  /**
   * @description Extracts the "storageClass" key from the config JSON, falling back to
   * LqcEstateCaseStorage when absent or blank.
   * @param configJson Raw configuration JSON, as returned by getConfig.
   * @return The configured storage class name, or the default when none is set.
   */
  @TestVisible
  private static String storageClassName(String configJson) {
    Map<String, Object> config = (Map<String, Object>) JSON.deserializeUntyped(
      configJson
    );
    Object configured = config.get('storageClass');
    return configured == null || String.isBlank(String.valueOf(configured))
      ? DEFAULT_STORAGE_CLASS
      : String.valueOf(configured);
  }

  /**
   * @description Dynamically instantiates the configured prefill class and returns its
   * rows serialized as JSON (a List<Map<String, Object>>).
   * @param className Fully qualified Apex class name expected to implement ILqcPrefill.
   * @param recordId Id of the record the Liquidity Calculator is placed on (the Case).
   * @return The prefill rows serialized as a JSON array of objects.
   * @throws AuraHandledException When className is blank, the class cannot be found, does
   * not implement ILqcPrefill, or refresh() throws.
   */
  @AuraEnabled
  public static String refreshRows(String className, Id recordId) {
    if (String.isBlank(className)) {
      throw new AuraHandledException(
        'No refresh class is configured for this tab.'
      );
    }
    Type prefillType = Type.forName(className);
    if (prefillType == null) {
      throw new AuraHandledException(
        'Refresh class "' + className + '" was not found.'
      );
    }
    Object instance = prefillType.newInstance();
    if (!(instance instanceof ILqcPrefill)) {
      throw new AuraHandledException(
        'Class "' + className + '" does not implement ILqcPrefill.'
      );
    }
    try {
      List<Map<String, Object>> rows = ((ILqcPrefill) instance)
        .refresh(recordId);
      return JSON.serialize(
        rows == null ? new List<Map<String, Object>>() : rows
      );
    } catch (Exception e) {
      throw new AuraHandledException('Refresh failed: ' + e.getMessage());
    }
  }

  /**
   * @description Derives the camelCase row key for a column label. Must stay in sync with
   * fieldKey() in the lqcUtils LWC module.
   * @param label Column label as configured in the JSON config, e.g. "Balance at DoD".
   * @return The camelCase key, e.g. "balanceAtDod"; an empty string when label is blank.
   * @example
   * LqcController.fieldKey('Account Number'); // 'accountNumber'
   */
  public static String fieldKey(String label) {
    if (String.isBlank(label)) {
      return '';
    }
    List<String> words = label.split('[^a-zA-Z0-9]+');
    String key = '';
    for (String word : words) {
      if (String.isBlank(word)) {
        continue;
      }
      String lower = word.toLowerCase();
      key += String.isBlank(key)
        ? lower
        : lower.substring(0, 1).toUpperCase() + lower.substring(1);
    }
    return key;
  }
}
