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

| Component                                          | Implements    | Notes                                                              |
| --------------------------------------------------- | ------------- | ------------------------------------------------------------------- |
| `LqcFscService.cls`                                 | —             | Shared FSC query/ownership helper the providers below reuse.        |
| `LqcDebitAccounts.cls`, `LqcCreditAccounts.cls`      | `ILqcPrefill` | Query `FinancialAccount` via `FinancialAccountParty` ownership.      |
| `LqcInsurancePolicies.cls`                          | `ILqcPrefill` | Queries `InsurancePolicy` / `InsurancePolicyParticipant`.            |
| `LqcFixedProperties.cls`, `LqcShares.cls`, `LqcOtherAssets.cls` | `ILqcPrefill` | Static stub rows — no real data source wired up yet.        |
| `LqcEstateCaseStorage.cls`                          | `ILqcStorage` | Default-flavored strategy: stores the payload on `Estate_Case__c`.  |
| `LqcTestIds.cls`                                    | —             | Test-only helper: synthesizes Ids for FSC objects that Apex tests can't insert (e.g. `FinancialAccountBalance`, read-only in the API). |
| `LqcFscExampleProvidersTest.cls`                    | —             | Tests for everything above, including a round-trip proving the package's shipped default config resolves once this bundle is deployed. |
| `objects/Estate_Case__c/`                           | —             | Minimal custom object `LqcEstateCaseStorage` reads/writes.          |

## Deploying it

```bash
sf project deploy start --source-dir examples/fsc-estate-case-demo --target-org <alias>
```

**Prerequisites:** Financial Services Cloud enabled on the target org (API
v61.0+ standard objects — `FinancialAccount`, `FinancialAccountParty`,
`FinancialAccountBalance`, `InsurancePolicy`, `InsurancePolicyParticipant`).
The package itself has no such dependency; this examples bundle does.

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

Today this repo has no namespace, so these classes compile as plain,
unnamespaced Apex — `implements ILqcPrefill` resolves directly. Once the core
package (`force-app/`) is installed under a namespace, every `implements
ILqcPrefill` / `implements ILqcStorage` line in this bundle needs to become
`implements yourNamespace.ILqcPrefill` / `implements yourNamespace.ILqcStorage`
(each is flagged with a comment above the line). Whether the class name
strings in the `DE_LQC` JSON also need namespace-qualifying depends on how
`Type.forName` resolves an unqualified name across that namespace boundary —
verify that against a real packaging/subscriber org pair before relying on
it either way.
