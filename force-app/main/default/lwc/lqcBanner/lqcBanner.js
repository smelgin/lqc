import { LightningElement, api } from "lwc";

/**
 * Reusable success / error / info banner used above the LQC tabset and
 * above each editable grid, matching the WinDeed-extract style bar.
 */
export default class LqcBanner extends LightningElement {
  /** @type {'success'|'error'|'info'} Visual style and icon of the banner. */
  @api variant = "info";
  /** Message text to display; the banner renders nothing while this is falsy. */
  @api message;

  get hasMessage() {
    return !!this.message;
  }

  get bannerClass() {
    return `lqc-banner lqc-banner_${this.variant}`;
  }

  get iconName() {
    if (this.variant === "success") {
      return "utility:success";
    }
    if (this.variant === "error") {
      return "utility:error";
    }
    return "utility:info";
  }

  handleClose() {
    this.dispatchEvent(new CustomEvent("close"));
  }
}
