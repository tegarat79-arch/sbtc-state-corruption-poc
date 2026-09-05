/**
 * Test for State Corruption Vulnerability (H1)
 * 
 * This test demonstrates that the state variable `sbtc-for-withdrawals`
 * is decremented even when the external transfer fails.
 */

import { Simnet } from '@stacks/clarinet-sdk';
import { describe, expect, test, beforeAll, afterAll } from 'vitest';
import * as fs from 'fs';
import * as path from 'path';

describe('State Corruption Vulnerability PoC - H1', () => {
  let simnet: Simnet;

  beforeAll(async () => {
    simnet = new Simnet();
    await simnet.init();
  });

  afterAll(async () => {
    await simnet.dispose();
  });

  test('should demonstrate state corruption when transfer fails', async () => {
    // Get accounts from the simnet
    const accounts = simnet.getAccounts();
    const deployer = accounts.get('deployer');
    const receiver = accounts.get('wallet1');

    // Helper to read contract source
    const loadContract = (name: string) => {
      const filePath = path.join(process.cwd(), 'contracts', `${name}.clar`);
      return fs.readFileSync(filePath, 'utf8');
    };

    // Deploy contracts
    await simnet.deployContract(
      'stbtc-reserve',
      loadContract('stbtc-reserve')
    );
    await simnet.deployContract(
      'mock-token',
      loadContract('mock-token')
    );
    await simnet.deployContract(
      'mock-dao',
      loadContract('mock-dao')
    );

    // Pause the mock token to simulate transfer failure
    await simnet.callPublicFn(
      'mock-token',
      'pause',
      [],
      deployer.address
    );
    await simnet.mineBlock();

    // Initial state: sbtc-for-withdrawals should be 200
    const initialState = await simnet.callReadOnlyFn(
      'stbtc-reserve',
      'get-sbtc-for-withdrawals',
      [],
      deployer.address
    );
    expect(initialState.result).toBe(true);
    expect(initialState.value).toBe(200);

    // Call the vulnerable function: request-sbtc-for-withdrawal(50, receiver)
    const exploitTx = await simnet.callPublicFn(
      'stbtc-reserve',
      'request-sbtc-for-withdrawal',
      [BigInt(50), receiver.address],
      deployer.address
    );
    await simnet.mineBlock();

    // Read state after the call
    const afterState = await simnet.callReadOnlyFn(
      'stbtc-reserve',
      'get-sbtc-for-withdrawals',
      [],
      deployer.address
    );
    expect(afterState.result).toBe(true);
    expect(afterState.value).toBe(150); // 200 - 50 = 150

    // Verify that no tokens were transferred (total supply unchanged)
    const tokenSupply = await simnet.callReadOnlyFn(
      'mock-token',
      'get-total-supply',
      [],
      deployer.address
    );
    expect(tokenSupply.result).toBe(true);
    expect(tokenSupply.value).toBe(1000000); // unchanged
  });
});