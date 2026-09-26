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

Deploy the package to an org:

```bash
sf project deploy start --source-dir force-app --target-org <alias>
```

Deploy the reference example on top of it (optional — see [`examples/README.md`](examples/README.md)):

```bash
sf project deploy start --source-dir examples/fsc-estate-case-demo --target-org <alias>
```

Validate against production with Apex tests:

```bash
sf project deploy start --source-dir force-app --target-org <alias> --test-level RunSpecifiedTests --tests LqcControllerTest
```

## Origin

Extracted from the [jsonlwc](https://github.com/smelgin/jsonlwc) repository, where LQC lived
alongside the IDP components as a separate package directory. The two share no code; this repo is
now the home of the Liquidity Calculator.
