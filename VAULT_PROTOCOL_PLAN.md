# Vault Protocol Plan and Guide

This guide is based on the current repository state as of February 11, 2026.

## 1) Current Reality (What Is Blocking Progress)

### A. Build and test currently fail at compile stage
- Dependencies are now installed in this workspace.
- `forge build` / `forge test` fail on project code issues (not import resolution).
- You should still keep dependency bootstrap checks for fresh clones and CI.

### B. Core compile/runtime issues in `src`
- `src/VaultEngine.sol` constructor loop has no increment (infinite loop risk at deploy time).
- `src/VaultEngine.sol` uses an undefined variable in `_getUsdValue`.
- `src/VaultEngine.sol` calls `VaultMath.getUsdValue` with wrong arguments.
- `src/VaultEngine.sol` does not match `src/interfaces/IVaultEngine.sol` (`getCollateralValue` signature mismatch).
- `src/libraries/VaultMath.sol` has an incorrect health-factor formula.
- `src/VaultStablecoin.sol` mint limiter blocks first mint (`currentSupply == 0` case).

### C. Test suite is incomplete/inconsistent
- Empty files:
  - `test/unit/VaultStablecoinTest.t.sol`
  - `test/unit/VaultEngineTest.t.sol`
  - `test/integration/LiquidationTest.t.sol`
  - `test/fuzz/HealthFactorFuzzTest.t.sol`
- `test/unit/PriceOracleTest.t.sol` calls methods not present in `src/mocks/MockPriceFeed.sol`.

### D. Dev tooling drift
- `makefile` references scripts that do not exist:
  - `_scripts/testing/run_all_tests.sh`
  - `_scripts/monitoring/balance_dashboard.sh`
  - `_scripts/debugging/emergency_tools.sh`
- Debug scripts source `../../.vault_env`, which is not in the repo.

## 2) Priority Roadmap

## Phase 0: Unblock Build (Day 1)

Goal: get deterministic `forge build` passing.

1. Verify dependency bootstrap for clean environments:
   - `forge install foundry-rs/forge-std --no-commit`
   - `forge install OpenZeppelin/openzeppelin-contracts@v4.8.3 --no-commit`
   - `forge install smartcontractkit/chainlink-brownie-contracts@0.6.1 --no-commit`
2. Add/update `remappings.txt` (if needed) and standardize imports.
3. Fix compile blockers in:
   - `src/VaultEngine.sol`
   - `src/libraries/VaultMath.sol`
   - `src/interfaces/IVaultEngine.sol`
   - `src/VaultStablecoin.sol`
4. Exit criteria:
   - `forge build` succeeds locally and in CI.

## Phase 1: Rebuild Test Foundation (Days 2-4)

Goal: reliable baseline tests for protocol correctness.

1. Unit tests (must-have):
   - collateral deposit/redeem accounting
   - health factor boundaries
   - mint/burn permissions and amount checks
   - oracle stale/invalid data behavior
2. Integration tests:
   - happy path: deposit -> mint -> burn -> redeem
   - liquidation path with price drop and partial liquidation
3. Fuzz tests:
   - user collateral/debt invariants
   - health factor must stay above threshold for valid operations
4. Fix mock/test API alignment:
   - either update `MockPriceFeed` API or test calls to match existing methods.
5. Coverage target:
   - `forge coverage` >= 85% on core contracts.

## Phase 2: Deployment Hardening (Days 5-6)

Goal: reproducible and safe deployment flow.

1. Split deployment profiles:
   - local (`anvil`)
   - sepolia
2. Add pre-deploy validation:
   - env var checks
   - chain ID verification
   - non-zero addresses for feeds/tokens
3. Add post-deploy verification:
   - contract ownership checks
   - critical config checks
   - optional Etherscan verification summary
4. Replace broken Make targets or add missing scripts so all `make` targets run.

## Phase 3: Source Quality and Safety (Days 7-10)

Goal: cleaner protocol architecture and safer behavior.

1. Standardize custom errors (replace string `require` where appropriate).
2. Normalize decimal handling for WETH (18) and WBTC (8).
3. Add explicit guardrails:
   - max collateral tokens limit enforcement
   - sanity checks on constructor inputs
4. Improve observability:
   - richer events for risk-critical state changes
5. Add invariants to CI.

## 3) CI/CD Target State

Use this CI sequence in GitHub Actions:

1. `forge fmt --check`
2. `forge build --sizes`
3. `forge test -vvv`
4. `forge coverage --report summary`
5. optional: static checks (Slither) and gas snapshot diff

Deployment pipeline (manual dispatch):

1. validate env + chain
2. deploy script
3. verify contracts
4. upload deployment artifact (addresses + commit SHA + chain ID)

## 4) Recommended Weekly Execution Plan

Week 1:
1. Fix dependencies and compile blockers.
2. Restore minimal unit/integration test suite.
3. Make CI green on PR.

Week 2:
1. Add liquidation and invariant fuzz coverage.
2. Harden deployment scripts and make targets.
3. Produce first release candidate.

Week 3:
1. Security-focused pass (edge cases, failure paths).
2. Gas/efficiency improvements after correctness is stable.

## 5) Practical Definition of Done

Project is "ready for public testnet iteration" when all are true:

1. `forge build` passes from clean clone.
2. `forge test` passes with deterministic results.
3. At least one end-to-end local journey test passes automatically.
4. Sepolia deploy + verify works via one documented command.
5. CI blocks merges on formatting/build/test failures.
