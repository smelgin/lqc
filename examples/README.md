# LQC examples

Reference implementations of the Liquidity Calculator's two extension points —
`ILqcPrefill` and `ILqcStorage` — kept **outside** the managed package in
`force-app/`. They are not deployed with the package and the package does not
depend on them; they exist to show one way to implement each contract, for you
to copy, adapt, or replace outright.

## What's here

`fsc-estate-case-demo/` is one complete, working example: it wires up all six
data tabs shipped in the package's default `DE_LQC` custom metadata record
against Financial Services Cloud standard objects, plus a default storage
destination.

| Component                                                       | Implements    | Notes                                                                                                                                  |
| --------------------------------------------------------------- | ------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `LqcFscService.cls`                                             | —             | Shared FSC query/ownership helper the providers below reuse.                                                                           |
| `LqcDebitAccounts.cls`, `LqcCreditAccounts.cls`                 | `ILqcPrefill` | Query `FinancialAccount` via `FinancialAccountParty` ownership.                                                                        |
| `LqcInsurancePolicies.cls`                                      | `ILqcPrefill` | Queries `InsurancePolicy` / `InsurancePolicyParticipant`.                                                                              |
| `LqcFixedProperties.cls`, `LqcShares.cls`, `LqcOtherAssets.cls` | `ILqcPrefill` | Static stub rows — no real data source wired up yet.                                                                                   |
| `LqcEstateCaseStorage.cls`                                      | `ILqcStorage` | Default-flavored strategy: stores the payload on `Estate_Case__c`.                                                                     |
| `LqcTestIds.cls`                                                | —             | Test-only helper: synthesizes Ids for FSC objects that Apex tests can't insert (e.g. `FinancialAccountBalance`, read-only in the API). |
| `LqcFscExampleProvidersTest.cls`                                | —             | Tests for everything above, including a round-trip proving the package's shipped default config resolves once this bundle is deployed. |
| `objects/Estate_Case__c/`                                       | —             | Minimal custom object `LqcEstateCaseStorage` reads/writes.                                                                             |
| `permissionsets/LQC_Estate_Case_Access.permissionset-meta.xml`  | —             | Object/field access to `Estate_Case__c` that `LqcEstateCaseStorage` needs under `USER_MODE`.                                           |

## Deploying it

```bash
sf project deploy start --source-dir examples/fsc-estate-case-demo --target-org <alias>
```

**Prerequisites:** Financial Services Cloud enabled on the target org (API
v61.0+ standard objects — `FinancialAccount`, `FinancialAccountParty`,
`FinancialAccountBalance`, `InsurancePolicy`, `InsurancePolicyParticipant`).
The package itself has no such dependency; this examples bundle does.

**Assign the permission set to real users.** Deploying a custom field via the
Metadata API grants no profile access to it — not even to System
Administrator — so `LqcEstateCaseStorage`'s `USER_MODE` queries against
`Estate_Case__c.Case__c` / `LQC_Result__c` fail with a misleading "No such
column" error until `LQC_Estate_Case_Access` is assigned:

```bash
sf org assign permset --name LQC_Estate_Case_Access --target-org <alias>
```

`LqcFscExampleProvidersTest` assigns it to the running user itself in
`@TestSetup`, so the test suite doesn't need this step.

**If the org already has its own `Estate_Case__c`**, skip
`objects/Estate_Case__c/` and point `LqcEstateCaseStorage` (or your own
`ILqcStorage`) at the org's existing object instead.

## Why this isn't in the package

The package ships two contracts, not an opinion on FSC or on where the
payload is stored — every org's data model differs, and this repo doesn't
know which storage strategy exists in yours before it exists. The shipped
`DE_LQC` custom metadata record deliberately still names these classes
(`lqcEstateCaseStorage`, `lqcDebitAccounts`, ...) as a template: deploy this
bundle as-is to get a working demo, or point the same JSON keys at your own
classes once you've written them.

## Adapting this once the package has a namespace

`force-app/` is packaged under the `absa1` namespace, so every `implements
ILqcPrefill` / `implements ILqcStorage` line in this bundle is namespace-
qualified: `implements absa1.ILqcPrefill` / `implements absa1.ILqcStorage`.
**This means these classes no longer compile as plain, unpackaged Apex** —
they only resolve once `absa1.ILqcPrefill` / `absa1.ILqcStorage` actually
exist in the org, i.e. once the `force-app` package is installed under that
namespace. If you're adapting this bundle for an unnamespaced or
differently-namespaced install, update these `implements` lines to match.

The class name _strings_ in the `DE_LQC` JSON config (`lqcEstateCaseStorage`,
`lqcDebitAccounts`, ...) do **not** need namespace-qualifying: `LqcController`
resolves them with `Type.forName('', className)`, which explicitly looks in
the local (subscriber-org) namespace rather than the package's own — exactly
where these example classes live.
