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

- Rename `.env.example` to `.env`. Add a valid URL for an Ethereum JSON-RPC client for the `RPC_URL` variable

### Commands

- `make build` - build the project
- `make test [optional](V={1,2,3,4,5})` - run tests (with different debug levels if provided)
- `make match MATCH=<TEST_FUNCTION_NAME> [optional](V=<{1,2,3,4,5}>)` - run matched tests (with different debug levels if provided)
