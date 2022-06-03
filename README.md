# FWB Liquidity Provisioning

This repository contains the Llama escrow contract between FWB and Gamma Strategies.
The goal is to improve the the liquidity pool of the FWB token by launching an active liquidity management program using Gamma.

## Installation

It requires [Foundry](https://github.com/gakonst/foundry) installed to run. You can find instructions here [Foundry installation](https://github.com/gakonst/foundry#installation).

### Manual installation

Clone the repository and install dependencies:

```sh
$ git clone https://github.com/llama-community/fwb-liquidity-provisioning.git
$ cd fwb-liquidity-provisioning
$ npm install
$ forge install
```

## Setup

- Duplicate `.env.example` and rename to `.env`.
  - Add a valid mainnet URL for an Ethereum JSON-RPC client for the `RPC_URL` variable.
  - Add the latest mainnet block number for the `BLOCK_NUMBER` variable.
  - Add a valid Etherscan API Key for the `ETHERSCAN_API_KEY` variable.

### Commands

- `make build` - build the project
- `make test [optional](V={1,2,3,4,5})` - run tests (with different debug levels if provided)
- `make match MATCH=<TEST_FUNCTION_NAME> [optional](V=<{1,2,3,4,5}>)` - run matched tests (with different debug levels if provided)

### Deploy and Verify

- `Mainnet`: When you're ready to deploy and verify, run `./scripts/deploy_verify_mainnet.sh` and follow the prompts.
- `Testnet`: When you're ready to deploy and verify, run `./scripts/deploy_verify_testnet.sh` and follow the prompts.

To confirm the deploy was successful, re-run your test suite but use the newly created contract address.
