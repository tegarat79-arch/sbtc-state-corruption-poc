# State Corruption Vulnerability Proof-of-Concept (H1) - sBTC Protocol

## Overview

This repository contains a Proof of Concept (PoC) demonstrating a **state corruption vulnerability** in the `stbtc-reserve` contract of the sBTC Protocol on the Stacks blockchain.

## Vulnerability Summary

- **Contract**: `SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.stbtc-reserve`
- **Vulnerable function**: `request-sbtc-for-withdrawal(uint requested-sbtc, principal receiver)`
- **Root cause**: `var-set` (state update) executes **BEFORE** the external token transfer (`try!` block)
- **Impact**: If the transfer fails (e.g., token paused, network error), the state change persists, leading to incorrect withdrawal pool accounting
- **Severity**: HIGH

## How the Vulnerability Works

The vulnerable code pattern is:

```clarity
(define-public (request-sbtc-for-withdrawal (requested-sbtc uint) (receiver principal))
  (begin
    (try! (contract-call? .dao check-is-protocol contract-caller))
    
    // THE BUG: state update BEFORE external call
    (var-set sbtc-for-withdrawals (- (var-get sbtc-for-withdrawals) requested-sbtc))
    
    // External transfer that could fail
    (try! (as-contract?
      ((with-ft 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token "sbtc-token" requested-sbtc))
      (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
                 transfer requested-sbtc tx-sender receiver none)))
    )
    
    (ok requested-sbtc)
  ))
```

When the `try!` block fails (e.g., transfer fails), the `var-set` has **already executed** and is **not rolled back**, causing state corruption.

## Project Structure

```
.
├── contracts/
│   ├── stbtc-reserve.clar    # Vulnerable contract
│   ├── mock-token.clar       # Mock sBTC token with pause functionality
│   └── mock-dao.clar         # Mock DAO (always authorizes)
├── tests/
│   └── h1-test.test.ts       # TypeScript test using @stacks/clarinet-sdk
├── settings/
│   ├── Devnet.toml           # Development network settings
│   ├── Mainnet.toml          # Mainnet settings
│   └── Testnet.toml          # Testnet settings
├── Clarinet.toml             # Project configuration
├── package.json              # Dependencies
├── tsconfig.json             # TypeScript config
├── vitest.config.ts          # Vitest + Clarinet SDK setup
└── README.md                 # This file
```

## Setup & Installation

### Prerequisites
- Node.js (v18+)
- npm
- Git

### Installation
```bash
# Clone this repository
git clone <repository-url>
cd sbtc-state-corruption-poc

# Install dependencies
npm install
```

## Running the Proof of Concept

### Running Tests
```bash
npm test
```

Expected output:
```
> sbtc-state-corruption-poc@1.0.0 test
> vitest run

  ✓ tests/h1-test.test.ts (1)
    ✓ should demonstrate state corruption when transfer fails (xx ms)

Test Files  1 passed
     Tests  1 passed
```

### Manual Verification via Clarinet Console
```bash
# Start Clarinet console
clarinet console

# In the console:
::load contracts/stbtc-reserve.clar
::load contracts/mock-token.clar
::load contracts/mock-dao.clar

# Initial state
(contract-call? .stbtc-reserve get-sbtc-for-withdrawals)
;; Should return (ok u200)

# Simulate pause token
(contract-call? .mock-token pause)

# Attempt withdrawal (will fail due to paused token)
(contract-call? .stbtc-reserve request-sbtc-for-withdrawal u50)

# Check state after failed transfer
(contract-call? .stbtc-reserve get-sbtc-for-withdrawals)
;; Returns (ok u150) - state decreased but transfer failed!
```

## Step-by-Step Reproduction

1. **Initial state**: Contract has `sbtc-for-withdrawals = 200` (uint)
2. **Pause token**: Call `mock-token.pause()` to simulate network issues or token maintenance
3. **Exploit call**: User calls `request-sbtc-for-withdrawal(50)`
   - `var-set` executes: `200 - 50 = 150` (state updated)
   - External transfer attempted → FAILS (token paused)
   - Function returns error, but state change **persists**
4. **Result**: 
   - `sbtc-for-withdrawals = 150` (incorrectly reduced)
   - Actual contract sBTC balance unchanged
   - User thinks only 150 sBTC available for withdrawal
   - User cannot withdraw the full amount they expect

## Impact Assessment

- **Exploitability**: Medium - requires ability to cause transfer failure (e.g., via token pause or network manipulation)
- **Damage**: High - users lose access to expected funds; protocol accounting becomes inconsistent
- **Fix**: Move the `var-set` **after** successful external transfer:
  ```clarity
  (try! (as-contract? ...))
  (var-set sbtc-for-withdrawals (- (var-get sbtc-for-withdrawals) requested-sbtc))
  (ok requested-sbtc)
  ```

## Files

- `contracts/stbtc-reserve.clar` - Minimal reproduction of vulnerable function
- `contracts/mock-token.clar` - Mock sBTC token with `pause()` for testing
- `contracts/mock-dao.clar` - Mock DAO that always authorizes (honest DAO)
- `tests/h1-test.test.ts` - TypeScript test demonstrating the vulnerability
- `Clarinet.toml` - Project configuration
- `package.json` - Dependencies (including @stacks/clarinet-sdk)
- `tsconfig.json` - TypeScript configuration
- `vitest.config.ts` - Vitest + Clarinet SDK setup

## License

MIT - see LICENSE file

---

**Security Note**: This PoC is for educational and security research purposes only. Do not deploy to production networks without proper authorization.