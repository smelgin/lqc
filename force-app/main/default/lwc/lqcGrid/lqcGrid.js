import { LightningElement, api, track } from "lwc";
import refreshRows from "@salesforce/apex/LqcController.refreshRows";
import {
  fieldKey,
  widthToPixels,
  reduceError,
  parseColumnType,
  picklistOptions
} from "c/lqcUtils";

const ROW_ACTION_DELETE = "delete";

/**
 * Reusable editable grid for one LQC tab.
 *
 * Fires a 'rowschange' event with { name, rows } on every mutation, so the parent always
 * holds the latest state for Save / Publish.
 */
export default class LqcGrid extends LightningElement {
  /** Id of the record the Liquidity Calculator is placed on (the Case). */
  @api recordId;
  /** One entry of tabs[] from the Custom_Configuration__mdt JSON config. */
  @api config;
  /** Whether the grid is locked read-only (true once the payload is published). */
  @api readOnly = false;

  @track rows = [];
  draftValues = [];
  sortedBy;
  sortDirection = "asc";
  isLoading = false;
  banner; // { variant, message }
  showAddModal = false;
  @track modalInputs = [];

  _initialized = false;

  /**
   * Rows from the saved payload. Only the first assignment seeds `rows`; later
   * reassignments (e.g. the parent re-rendering) are ignored so in-progress edits and
   * refreshed/added rows are never clobbered.
   */
  @api
  get initialRows() {
    return this._initialRows;
  }
  set initialRows(value) {
    this._initialRows = value;
    if (!this._initialized) {
      this.rows = (value || []).map((row) => ({ ...row }));
      this._initialized = true;
    }
  }

  /* ---------------------------------------------------------- getters */

  get title() {
    return this.config?.title || "";
  }

  get isBlank() {
    // A tab configured without columns renders a placeholder body.
    return !this.config?.columns?.length;
  }

  get columns() {
    if (this.isBlank) {
      return [];
    }
    const cols = this.config.columns.map((col) => {
      const key = fieldKey(col.name);
      const base = {
        label: col.name,
        fieldName: key,
        sortable: true,
        initialWidth: widthToPixels(col.width),
        hideDefaultActions: true
      };
      const parsed = parseColumnType(col.type);
      switch (parsed.base) {
        case "textLink":
          // Never editable, per requirements.
          return {
            ...base,
            type: "url",
            fieldName: `${key}Url`,
            typeAttributes: {
              label: { fieldName: key },
              target: "_blank"
            },
            sortable: true
          };
        case "number":
          return {
            ...base,
            type: "number",
            editable: this.cellEditable,
            // Explicit, although 'number' cells right-align by default.
            cellAttributes: { alignment: "right" },
            typeAttributes: {
              minimumFractionDigits: 0,
              maximumFractionDigits: parsed.decimals ?? 2
            }
          };
        case "date":
          return {
            ...base,
            type: "date-local",
            editable: this.cellEditable
          };
        case "picklist":
          return {
            ...base,
            type: "picklist",
            editable: this.cellEditable,
            typeAttributes: { options: picklistOptions(col) }
          };
        default:
          return { ...base, type: "text", editable: this.cellEditable };
      }
    });
    cols.push({
      type: "action",
      typeAttributes: { rowActions: this.getRowActions.bind(this) }
    });
    return cols;
  }

  // Cell-level editability: only manually added rows carry editable = true.
  get cellEditable() {
    return this.readOnly ? false : { fieldName: "editable" };
  }

  get sortedRows() {
    if (!this.sortedBy) {
      return this.rows;
    }
    const key = this.sortedBy;
    const factor = this.sortDirection === "asc" ? 1 : -1;
    return [...this.rows].sort((a, b) => {
      const va = a[key];
      const vb = b[key];
      if (va == null) return 1;
      if (vb == null) return -1;
      if (typeof va === "number" && typeof vb === "number") {
        return (va - vb) * factor;
      }
      return String(va).localeCompare(String(vb)) * factor;
    });
  }

  get addDisabled() {
    return this.readOnly || this.config?.canAddRows === false;
  }

  get refreshDisabled() {
    return this.readOnly || !this.config?.refreshClass;
  }

  get textLinkKeys() {
    return (this.config?.columns || [])
      .filter((col) => col.type === "textLink")
      .map((col) => fieldKey(col.name));
  }

  /* ---------------------------------------------------------- banner */

  showBanner(variant, message) {
    this.banner = { variant, message };
  }

  handleBannerClose() {
    this.banner = undefined;
  }

  /* ---------------------------------------------------------- refresh */

  /**
   * Re-fetches prefill rows from the tab's configured refresh class and replaces the
   * previous prefilled rows, preserving manually added rows.
   * @returns {Promise<void>} Resolves once the refresh attempt finishes.
   */
  async handleRefresh() {
    this.isLoading = true;
    this.banner = undefined;
    try {
      const rowsJson = await refreshRows({
        className: this.config.refreshClass,
        recordId: this.recordId
      });
      const prefilled = JSON.parse(rowsJson).map((raw, index) =>
        this.toPrefilledRow(raw, index)
      );
      // Replace old prefilled rows; manual rows are preserved.
      this.rows = [...prefilled, ...this.rows.filter((r) => r.isManual)];
      this.draftValues = [];
      this.emitRows();
      this.showBanner("success", `${this.title} Extract - Success`);
    } catch (error) {
      this.showBanner("error", `${this.title} Extract - ${reduceError(error)}`);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * Normalizes a raw prefill row into datatable shape: assigns a stable row id and, for
   * every textLink column, derives the "<columnKey>Url" the datatable's url type needs from
   * the "<columnKey>RecordId" the Apex provider returned.
   * @param {Object} raw Row returned by the Apex refresh provider.
   * @param {number} index Row position, used to build a unique id.
   * @returns {Object} The row augmented with id, isManual, editable, and link URLs.
   */
  toPrefilledRow(raw, index) {
    const row = {
      ...raw,
      id: `${this.config.name}-prefill-${index}`,
      isManual: false,
      editable: false
    };
    this.textLinkKeys.forEach((key) => {
      const linkedId = row[`${key}RecordId`];
      if (linkedId) {
        row[`${key}Url`] = `/lightning/r/${linkedId}/view`;
      }
    });
    return row;
  }

  /* ---------------------------------------------------------- add row */

  /**
   * Builds the "Add row" modal's input definitions from the tab's column config (skipping
   * textLink columns, which are never manually entered) and opens the modal.
   */
  handleAdd() {
    this.modalInputs = (this.config.columns || [])
      .filter((col) => parseColumnType(col.type).base !== "textLink")
      .map((col) => {
        const parsed = parseColumnType(col.type);
        const isNumber = parsed.base === "number";
        const input = {
          key: fieldKey(col.name),
          label: col.name,
          isPicklist: parsed.base === "picklist",
          inputType:
            parsed.base === "date" ? "date" : isNumber ? "number" : "text",
          value: ""
        };
        if (input.isPicklist) {
          input.options = picklistOptions(col);
        }
        if (isNumber) {
          // number(6,2) -> step 0.01, max 999999.99
          input.step = parsed.decimals
            ? (10 ** -parsed.decimals).toFixed(parsed.decimals)
            : "any";
          input.max = parsed.intDigits
            ? 10 ** parsed.intDigits - 10 ** -(parsed.decimals || 0)
            : undefined;
        }
        return input;
      });
    this.showAddModal = true;
  }

  handleModalInputChange(event) {
    const key = event.target.dataset.key;
    this.modalInputs = this.modalInputs.map((input) => {
      return input.key === key
        ? { ...input, value: event.target.value }
        : input;
    });
  }

  handleModalCancel() {
    this.showAddModal = false;
  }

  /**
   * Validates the "Add row" modal's inputs and, when valid, appends a new manual row built
   * from their values and closes the modal.
   */
  handleModalSave() {
    const inputs = [...this.template.querySelectorAll("[data-key]")];
    const allValid = inputs.reduce(
      (valid, input) => input.reportValidity() && valid,
      true
    );
    if (!allValid) {
      return;
    }
    const row = {
      id: `${this.config.name}-manual-${Date.now()}`,
      isManual: true,
      editable: true
    };
    this.modalInputs.forEach((input) => {
      row[input.key] =
        input.inputType === "number" && input.value !== ""
          ? parseFloat(input.value)
          : input.value || null;
    });
    this.rows = [...this.rows, row];
    this.showAddModal = false;
    this.emitRows();
  }

  /* ------------------------------------------------- edit / delete */

  /**
   * Merges inline-edited draft values into their rows. Only manually added rows accept
   * edits; drafts against prefilled rows are ignored.
   * @param {CustomEvent} event lightning-datatable 'cellchange'-save event.
   */
  handleCellSave(event) {
    const drafts = event.detail.draftValues || [];
    const byId = new Map(drafts.map((d) => [d.id, d]));
    this.rows = this.rows.map((row) => {
      const draft = byId.get(row.id);
      if (!draft || !row.isManual) {
        return row;
      }
      const merged = { ...row };
      Object.keys(draft).forEach((field) => {
        if (field === "id") return;
        const colType = this.columnTypeForField(field);
        merged[field] =
          colType === "number" && draft[field] !== "" && draft[field] != null
            ? parseFloat(draft[field])
            : draft[field];
      });
      return merged;
    });
    this.draftValues = [];
    this.emitRows();
  }

  /** Resolves the configured column type (e.g. 'number') for a datatable field name. */
  columnTypeForField(field) {
    const col = (this.config.columns || []).find(
      (c) => fieldKey(c.name) === field
    );
    return parseColumnType(col?.type).base;
  }

  getRowActions(row, doneCallback) {
    // Only manually added rows can be deleted.
    doneCallback(
      row.isManual && !this.readOnly
        ? [{ label: "Delete", name: ROW_ACTION_DELETE }]
        : [{ label: "Delete", name: ROW_ACTION_DELETE, disabled: true }]
    );
  }

  handleRowAction(event) {
    if (event.detail.action.name === ROW_ACTION_DELETE) {
      const rowId = event.detail.row.id;
      this.rows = this.rows.filter((r) => r.id !== rowId);
      this.emitRows();
    }
  }

  /* ---------------------------------------------------------- sort */

  handleSort(event) {
    this.sortedBy = event.detail.fieldName;
    this.sortDirection = event.detail.sortDirection;
  }

  /* ---------------------------------------------------------- output */

  emitRows() {
    this.dispatchEvent(
      new CustomEvent("rowschange", {
        detail: { name: this.config.name, rows: this.rows }
      })
    );
  }
}
