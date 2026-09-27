# Liquidity Calculator (LQC)

A configuration-driven Lightning Web Component for Case record pages. It renders a tab set where
each tab is an editable grid, plus a calculated report tab that summarizes the others.

**Everything visible — tabs, columns, data types, widths, picklist values, the report layout — is
driven by a single JSON document stored in `Custom_Configuration__mdt`.** Adding a tab or a column
is a metadata change, not a code change.

Full developer manual: **[LIQUIDITY_CALCULATOR.md](LIQUIDITY_CALCULATOR.md)**.

## Repository layout

```
force-app/main/default/        the managed package — no FSC or Estate_Case__c dependency
  lwc/                  liquidityCalculator (container), lqcGrid, lqcDatatable,
                        lqcReport, lqcBanner, lqcUtils
  classes/              LqcController, the ILqcPrefill / ILqcStorage contracts,
                        plus LqcControllerTest
  customMetadata/       Custom_Configuration.DE_LQC — the configuration record
  objects/
    Custom_Configuration__mdt/   shared config type, JSON lives in Value__c

examples/fsc-estate-case-demo/  reference implementation, NOT part of the package — see
                        examples/README.md
  classes/              LqcEstateCaseStorage, LqcFscService and the Lqc* prefill
                        providers, LqcTestIds, LqcFscExampleProvidersTest
  objects/
    Estate_Case__c/              minimal storage object the example writes to

docs/images/            screenshots referenced by the manual
```

## Prerequisites

The package itself has no compile-time dependency on Financial Services Cloud or on
`Estate_Case__c` — it ships only the `ILqcPrefill` / `ILqcStorage` contracts, the controller, the
LWCs, and the `Custom_Configuration__mdt` framework type. Its shipped `DE_LQC` default config
names classes it doesn't contain (`lqcEstateCaseStorage`, `lqcDebitAccounts`, ...) as a template —
resolving them requires deploying an implementation, your own or the one in
[`examples/fsc-estate-case-demo`](examples/README.md), which does depend on **Financial Services
Cloud** (`FinancialAccount`, `FinancialAccountParty`, `FinancialAccountBalance`, `InsurancePolicy`,
API v61.0+) and ships its own minimal `Estate_Case__c`.

See [§8.1 of the manual](LIQUIDITY_CALCULATOR.md#81-prerequisite-estate_case__c) for the full list.

## Getting started

```bash
npm install
```

Run the LWC unit tests:

```bash
npm run test:unit
```

## Installing the managed package

`force-app` ships as a 2GP managed package under namespace `absa1`, not as source you deploy
directly — install it with `sf package install`, not `sf project deploy start`. Current Beta
version is aliased in [`sfdx-project.json`](sfdx-project.json) as `LQC@0.1.0-2`; Beta versions
only install into **scratch orgs and Developer Edition orgs**, not sandboxes or production
(promote to Released first — see [`examples/README.md`](examples/README.md) for the coverage
caveat that currently blocks that).

**The install order matters.** `LqcPostInstallScript` aborts the install if
`Custom_Configuration__mdt` doesn't already exist in the target org, and `examples/`'s Apex
classes `implement absa1.ILqcPrefill` / `absa1.ILqcStorage`, so they only compile once the package
is installed. That means the CMDT _object_ has to land before the package, and the rest of
`examples/` has to land after:

1. **Deploy just the `Custom_Configuration__mdt` object** (not its `DE_LQC` record, not the
   classes) so the post-install script's existence check passes:

   ```bash
   sf project deploy start --source-dir examples/fsc-estate-case-demo/objects/Custom_Configuration__mdt --target-org <alias>
   ```

2. **Install the package.** The post-install script sees the object, then asynchronously creates
   a default `DE_LQC` record (a Metadata API deployment, so it appears a few seconds after this
   command returns, not instantly):

   ```bash
   sf package install --package LQC@0.1.0-2 --target-org <alias> --wait 10
   ```

3. **Deploy the rest of the reference example** (optional — see
   [`examples/README.md`](examples/README.md) for what it contains and why it's separate). This
   also redeploys `Custom_Configuration__mdt` and its `DE_LQC` record, which is harmless — same
   object, same default JSON the post-install script already wrote:

   ```bash
   sf project deploy start --source-dir examples/fsc-estate-case-demo --target-org <alias>
   ```

4. **Assign the example's permission set** so its `USER_MODE` queries against `Estate_Case__c`
   don't fail with a misleading "No such column" error (deploying a field via the Metadata API
   grants no profile access, not even to System Administrator):

   ```bash
   sf org assign permset --name LQC_Estate_Case_Access --target-org <alias>
   ```

**Uninstalling** removes the package but not `Custom_Configuration__mdt` (it's subscriber-owned,
never packaged) — `LqcUninstallScript` best-effort blanks the `DE_LQC` record's value instead of
deleting it (Apex's Metadata API has no delete operation; see
[`examples/README.md`](examples/README.md) for why).

## Developing from source

If you're changing `force-app` itself rather than installing it as a package, deploy it straight
from source to a scratch org instead of building a package version each time — but note this
bypasses the post-install script, so seed `Custom_Configuration__mdt`/`DE_LQC` yourself (deploy
`examples/fsc-estate-case-demo/customMetadata` and `objects/Custom_Configuration__mdt`, or run the
LWC against a `configOverride`):

```bash
sf project deploy start --source-dir force-app --target-org <alias>
```

Validate with Apex tests:

```bash
sf project deploy start --source-dir force-app --target-org <alias> --test-level RunSpecifiedTests --tests LqcControllerTest
```
