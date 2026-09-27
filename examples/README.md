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

| Component                                                                                      | Implements    | Notes                                                                                                                                                                                          |
| ---------------------------------------------------------------------------------------------- | ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `LqcFscService.cls`                                                                            | —             | Shared FSC query/ownership helper the providers below reuse.                                                                                                                                   |
| `LqcDebitAccounts.cls`, `LqcCreditAccounts.cls`                                                | `ILqcPrefill` | Query `FinancialAccount` via `FinancialAccountParty` ownership.                                                                                                                                |
| `LqcInsurancePolicies.cls`                                                                     | `ILqcPrefill` | Queries `InsurancePolicy` / `InsurancePolicyParticipant`.                                                                                                                                      |
| `LqcFixedProperties.cls`, `LqcShares.cls`, `LqcOtherAssets.cls`                                | `ILqcPrefill` | Static stub rows — no real data source wired up yet.                                                                                                                                           |
| `LqcEstateCaseStorage.cls`                                                                     | `ILqcStorage` | Default-flavored strategy: stores the payload on `Estate_Case__c`.                                                                                                                             |
| `LqcTestIds.cls`                                                                               | —             | Test-only helper: synthesizes Ids for FSC objects that Apex tests can't insert (e.g. `FinancialAccountBalance`, read-only in the API).                                                         |
| `LqcFscExampleProvidersTest.cls`                                                               | —             | Tests for everything above, including a round-trip proving the package's shipped default config resolves once this bundle is deployed.                                                         |
| `objects/Estate_Case__c/`                                                                      | —             | Minimal custom object `LqcEstateCaseStorage` reads/writes.                                                                                                                                     |
| `permissionsets/LQC_Estate_Case_Access.permissionset-meta.xml`                                 | —             | Object/field access to `Estate_Case__c` that `LqcEstateCaseStorage` needs under `USER_MODE`.                                                                                                   |
| `objects/Custom_Configuration__mdt/`, `customMetadata/Custom_Configuration.DE_LQC.md-meta.xml` | —             | The config object `LqcController.getConfig()` reads, plus the shipped default template. Not part of the package (see below); a real install gets `DE_LQC` from `LqcPostInstallScript` instead. |

## Deploying it

This bundle's classes `implement absa1.ILqcPrefill` / `absa1.ILqcStorage`, so they only compile
once the `LQC` package is installed — and the package's post-install script only succeeds if
`Custom_Configuration__mdt` already exists. Those two facts mean this can't go in as one deploy
before or after the package; see the [top-level README](../README.md#installing-the-managed-package)
for the full 4-step sequence. Summarized:

```bash
# 1. before installing the package — just the CMDT object
sf project deploy start --source-dir examples/fsc-estate-case-demo/objects/Custom_Configuration__mdt --target-org <alias>

# 2. sf package install ... (see top-level README)

# 3. after installing the package — everything else in this bundle
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

`Custom_Configuration__mdt` itself is unpackaged for the same namespace
reason `ILqcPrefill`/`ILqcStorage` implementers are (see below): a custom
object shipped _inside_ a namespaced package is always namespaced on
install, so a packaged `Custom_Configuration__mdt` would install as
`absa1__Custom_Configuration__mdt` — colliding with, not reusing, a
subscriber's already-existing unnamespaced one. `LqcController.getConfig()`
reads it with a dynamic `Database.query()` rather than a static SOQL, both to
avoid that namespace collision and so `force-app` can build as a package
without owning this object at all.

## Post-install / uninstall scripts

The package's version is built with two scripts from `force-app` (see
`sf package version create --post-install-script` / `--uninstall-script`):

- **`LqcPostInstallScript`** checks that `Custom_Configuration__mdt` (with a
  `Value__c` field) already exists in the installing org and **aborts the
  install** if it doesn't — an uncaught exception in `InstallHandler.onInstall`
  rolls back the whole installation. If it exists and no `DE_LQC` record is
  there yet, it creates one with this bundle's default JSON (this repo's
  `customMetadata/Custom_Configuration.DE_LQC.md-meta.xml`, embedded as a
  string constant since the script can't reference a CMDT record the package
  doesn't ship). Creation goes through
  `Metadata.Operations.enqueueDeployment`, an asynchronous Metadata API call,
  so `DE_LQC` appears shortly after install finishes, not instantly.
- **`LqcUninstallScript`** blanks `DE_LQC.Value__c` on uninstall, best effort.
  **It cannot actually delete the record**: Apex's Metadata API deployment
  (`Metadata.Operations.enqueueDeployment`) only supports creating/updating
  custom metadata, never deleting it. Blanking the value stops a leftover
  record from silently pointing the calculator at classes the uninstall just
  removed; deleting the record itself needs Setup, Workbench, or a metadata
  deploy from outside Apex.
- Metadata API calls are treated as callouts, and Apex tests don't support
  callouts, so the create/blank paths in both scripts can't be covered by
  automated tests — see `LqcPostInstallScriptTest.cls` /
  `LqcUninstallScriptTest.cls` in `force-app` (pure logic, no callout) and
  `postInstallScriptSkipsCreationWhenTheTemplateAlreadyExists` here (the one
  `onInstall()`/`onUninstall()` branch that doesn't reach a callout). Verify
  the create/blank paths themselves manually against a real install/uninstall.
- Both scripts' own helper methods (`recordExists`, `assertConfigObjectExists`,
  `LqcController.storageClassName`) are `private` to the package, so tests in
  this unpackaged bundle can't call them directly — the tests here go through
  each class's public/global surface (`getConfig()`, `Test.testInstall()`,
  plain SOQL) instead.

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
