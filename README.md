# Liquidity Calculator (LQC)

A configuration-driven Lightning Web Component for Case record pages. It renders a tab set where
each tab is an editable grid, plus a calculated report tab that summarizes the others.

**Everything visible — tabs, columns, data types, widths, picklist values, the report layout — is
driven by a single JSON document stored in `Custom_Configuration__mdt`.** Adding a tab or a column
is a metadata change, not a code change.

Full developer manual: **[LIQUIDITY_CALCULATOR.md](LIQUIDITY_CALCULATOR.md)**.

## Repository layout

```
force-app/main/default/
  lwc/                  liquidityCalculator (container), lqcGrid, lqcDatatable,
                        lqcReport, lqcBanner, lqcUtils
  classes/              LqcController, the ILqcPrefill / ILqcStorage contracts,
                        LqcEstateCaseStorage, LqcFscService and the Lqc* prefill
                        providers, plus LqcControllerTest
  customMetadata/       Custom_Configuration.DE_LQC — the configuration record
  objects/
    Custom_Configuration__mdt/   shared config type, JSON lives in Value__c
    Estate_Case__c/              minimal default storage object — see below
docs/images/            screenshots referenced by the manual
```

## Prerequisites

The default storage strategy writes to `Estate_Case__c.LQC_Result__c`, and the prefill providers
query **Financial Services Cloud** standard objects (`FinancialAccount`, `FinancialAccountParty`,
`FinancialAccountBalance`, `InsurancePolicy`, API v61.0+). Both are compile-time dependencies.

A minimal `Estate_Case__c` ships in this repo so a clean org can deploy and run the tests. **If the
target org already has an `Estate_Case__c`, exclude that folder** and point the storage strategy at
the org's own object instead. Storage is pluggable via `ILqcStorage` if you'd rather keep the
payload somewhere else entirely.

See [§8.1 of the manual](LIQUIDITY_CALCULATOR.md#81-prerequisite-estate_case__c) for the full list.

## Getting started

```bash
npm install
```

Run the LWC unit tests:

```bash
npm run test:unit
```

Deploy to an org:

```bash
sf project deploy start --source-dir force-app --target-org <alias>
```

Validate against production with Apex tests:

```bash
sf project deploy start --source-dir force-app --target-org <alias> --test-level RunSpecifiedTests --tests LqcControllerTest
```

## Origin

Extracted from the [jsonlwc](https://github.com/smelgin/jsonlwc) repository, where LQC lived
alongside the IDP components as a separate package directory. The two share no code; this repo is
now the home of the Liquidity Calculator.
