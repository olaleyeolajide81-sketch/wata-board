# Wata-Board Integration Testing

This project uses **Playwright** for end-to-end and integration testing. Tests cover the complete payment flow, wallet interactions, and scheduled payments.

## Running Tests

From the `wata-board-frontend` directory:

```bash
# Run all tests
npm run test

# Run tests in UI mode
npx playwright test --ui

# Debug a specific test
npx playwright test tests/integration/payment.spec.ts --debug
```

## Test Suites

- `tests/integration/payment.spec.ts`: Tests the core payment flow, including Freighter wallet connection, fee estimation, and transaction submission. Uses extensive mocking to simulate the Stellar network and wallet-bridge.
- `tests/integration/scheduling.spec.ts`: Tests the recurring payment scheduling feature.
- `tests/crash.spec.ts`: Smoke test to ensure the app renders without crashing.

## Infrastructure

To handle environmental differences and lack of a real wallet in CI, we use several techniques:
1. **Wallet Injection**: Mock objects are injected into `window.freighter` and `window.freighterApi` via `page.addInitScript`.
2. **Network Interception**: Playwright's `page.route` intercepts calls to Stellar Horizon (**/horizon/**) to provide consistent account and ledger data.
3. **Transaction Mocking**: To bypass internal SDK validation issues in Playwright, the app supports `window.__MOCK_STELLAR_TRANSACTION__` which allows tests to provide a stubbed transaction object.

## Troubleshooting

- **"Cannot read properties of undefined (reading 'type')"**: This often occurs when the Stellar SDK `TransactionBuilder` or `Operation` receives malformed data. Check the mocks in use and ensure all required properties (id, sequenceNumber, etc.) are present.
- **Timeouts**: The app performs async operations like fee estimation. Tests are configured with 15s timeouts to accommodate these.
