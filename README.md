# EventTicketVerify — Dashboard and Blockchain History

This package contains the dashboard, event-history interface, shared read connection, wallet connection helper, and styling for the EventTicketVerify frontend.

## Stack

- Vite
- Vanilla JavaScript
- ethers.js v6
- Ganache local blockchain
- MetaMask

## Run locally

```bash
cd frontend
npm install
npm run dev
```

## Connect a deployed contract

Before live data can load, provide the compiled contract ABI and the actual Ganache deployment details.

### 1. ABI

Replace the contents of `artifacts/EventTicketVerification.abi.json` with the ABI array exported from the compiled Solidity contract in Remix. Do not paste the full compiler artifact; use the ABI array.

### 2. Deployment configuration

Update `frontend/src/config/deployment.json` using verified values from the current Ganache deployment:

```json
{
  "network": {
    "name": "Ganache Local",
    "chainId": 1337,
    "rpcUrl": "http://127.0.0.1:7545"
  },
  "contract": {
    "name": "EventTicketVerification",
    "address": "0xYOUR_DEPLOYED_CONTRACT_ADDRESS",
    "deployerAddress": "0xYOUR_DEPLOYER_ADDRESS",
    "deploymentBlock": 1,
    "deploymentTxHash": "0xYOUR_DEPLOYMENT_TRANSACTION_HASH"
  }
}
```

Use the actual Chain ID, RPC URL, contract address, deployment block, and transaction hash. The values above are examples of the configuration shape, not deployment credentials.

## Dashboard data rules

The dashboard reads contract event logs from the configured deployment block. It recognizes ticket-purchase, ticket-use/check-in, ticket-cancellation, and event-creation event names from the contract ABI.

- Total issued is counted from recognized ticket-purchase events.
- Used and cancelled counts are counted from their corresponding recognized lifecycle events.
- Valid is calculated as total minus used minus cancelled.
- Event-wise counts are grouped when the event log includes an `eventId` argument.

These derived figures are accurate only when the deployed contract emits the corresponding events for every relevant state change. Confirm the actual event names and argument fields in the deployed ABI. If the contract does not emit lifecycle events, use its authoritative getters instead of treating event-derived totals as complete.

## Transaction history

The history view queries actual contract event logs from the configured deployment block to the latest block. It displays the event name, available event/ticket identifiers, actor address when present, block number, timestamp read from the mined block, and transaction hash. It includes search, page navigation, and transaction-hash copying.

## Important deployment notes

- Keep Ganache running while using the app.
- Connect MetaMask to the same Ganache chain configured in `deployment.json`.
- If Ganache is reset or the contract is redeployed, update the ABI and all deployment fields.
- Never use a stale contract address or deployment block.
- No ticket counts or transaction rows are fabricated by this dashboard.
