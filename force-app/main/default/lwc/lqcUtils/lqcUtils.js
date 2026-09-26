/**
 * Shared helpers for the Liquidity Calculator components.
 */

/**
 * Derives the camelCase row key for a column label. Must stay in sync with
 * LqcController.fieldKey in Apex.
 * @param {string} label Column label as configured in the JSON config.
 * @returns {string} The camelCase key, e.g. "accountNumber"; an empty string when blank.
 * @example
 * fieldKey('Share Name/Holding'); // 'shareNameHolding'
 */
export function fieldKey(label) {
  if (!label) {
    return "";
  }
  return label
    .split(/[^a-zA-Z0-9]+/)
    .filter(Boolean)
    .map((word, index) => {
      const lower = word.toLowerCase();
      return index === 0
        ? lower
        : lower.charAt(0).toUpperCase() + lower.slice(1);
    })
    .join("");
}

const NUMBER_TYPE_PATTERN = /^number\((\d+),(\d+)\)$/;

/**
 * Parses a configured column type string into its parts.
 * @param {string} type Column type from the JSON config, e.g. "number(6,2)" or "picklist".
 * @returns {{base: string, intDigits?: number, decimals?: number}} The parsed type; base is
 * "text" when type is blank, "number" with decimals defaulting to 2 when type is bare
 * "number", and the literal type string otherwise (textLink, date, picklist, ...).
 * @example
 * parseColumnType('number(6,2)'); // { base: 'number', intDigits: 6, decimals: 2 }
 */
export function parseColumnType(type) {
  if (!type) {
    return { base: "text" };
  }
  const match = NUMBER_TYPE_PATTERN.exec(type);
  if (match) {
    return {
      base: "number",
      intDigits: parseInt(match[1], 10),
      decimals: parseInt(match[2], 10)
    };
  }
  if (type === "number") {
    return { base: "number", decimals: 2 };
  }
  return { base: type };
}

/**
 * Converts a pipe-separated picklist definition ("Open|Closed|Deferred") into
 * lightning-combobox options. Accepts the legacy "value" key too.
 * @param {{values?: string, value?: string}} column Column config carrying the picklist
 * definition under "values" (or the legacy "value").
 * @returns {Array<{label: string, value: string}>} lightning-combobox option list.
 */
export function picklistOptions(column) {
  const raw = column?.values ?? column?.value ?? "";
  return String(raw)
    .split("|")
    .filter(Boolean)
    .map((entry) => ({ label: entry, value: entry }));
}

/**
 * Converts a configured percentage width ("20%") into an initial pixel width for
 * lightning-datatable (which does not accept percentages).
 * @param {string} width Configured column width, e.g. "20%".
 * @param {number} [totalPixels=1200] Pixel width that 100% maps to.
 * @returns {number|undefined} The pixel width, or undefined when width is missing or not a
 * positive percentage.
 */
export function widthToPixels(width, totalPixels = 1200) {
  const pct = parseFloat(width);
  if (Number.isNaN(pct) || pct <= 0) {
    return undefined;
  }
  return Math.round((pct / 100) * totalPixels);
}

/**
 * Extracts a user-friendly message from an LWC/Apex error.
 * @param {Error|{body: (Array|{message: string})}} error Error thrown by an imperative Apex
 * call, or a plain JS Error.
 * @returns {string} A displayable error message, or "Unknown error" when none can be found.
 */
export function reduceError(error) {
  if (!error) {
    return "Unknown error";
  }
  if (Array.isArray(error.body)) {
    return error.body.map((e) => e.message).join(", ");
  }
  if (error.body && typeof error.body.message === "string") {
    return error.body.message;
  }
  if (typeof error.message === "string") {
    return error.message;
  }
  return "Unknown error";
}
