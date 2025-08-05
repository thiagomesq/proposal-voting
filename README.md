# Proposal Voting System

This project implements a smart contract for a proposal creation and voting system on the blockchain. It allows users to create proposals, vote on them, and after a voting period, the proposals are automatically closed as "Approved" or "Rejected" based on the vote count. The system is designed to be integrated with Chainlink Automation for the automatic closing of proposals.

## Features

-   **Proposal Creation**: Any user can create a proposal with a title and a description.
-   **Voting**: Users can vote for or against a proposal. Each user can only vote once per proposal.
-   **Fixed Voting Period**: Each proposal has a 7-day voting period.
-   **Automatic Closing**: The contract is compatible with Chainlink Automation to check and close proposals whose voting period has expired.
-   **Security**: Uses `ReentrancyGuard` to prevent re-entrancy attacks.
-   **Interaction Scripts**: Foundry scripts to facilitate deployment and interaction with the contract.
-   **Makefile**: Simplified commands to compile, test, deploy, and interact with the project.

## Prerequisites

-   [Foundry](https://getfoundry.sh/)

## Getting Started

### 1. Installation

Clone the repository and install the necessary dependencies using the `Makefile`:

```bash
git clone <YOUR_REPOSITORY_URL>
cd <DIRECTORY_NAME>
make install
```

The `make install` command will download the required libraries, such as OpenZeppelin, Chainlink, and Foundry-Devops.

### 2. Environment Setup

Create a `.env` file in the root of the project to store your private keys and RPC URLs for test networks. Use the `.env.example` file as a template:

```
AMOY_RPC_URL=your_rpc_url
ACCOUNT=your_account_name
ETHERSCAN_API_KEY=your_etherscan_api_key
```

## Makefile Command Guide

The `Makefile` provides shortcuts for the most common operations.

### Create the Account

To create the account to be used to deploy the contract to a test network:

```bash
make createAccount
```

After the creation, add the name in your `.env` file.

### Compile the Contracts

To compile all smart contracts in the project:

```bash
make build
```

### Run the Tests

To run the complete test suite for the `ProposalVoting` contract:

```bash
make test
```

### Start a Local Node (Anvil)

To start a local Anvil instance for testing and development:

```bash
make anvil
```

### Deploy

The `deploy` command can be used to deploy the contract to a local network (Anvil) or a test network like Amoy.

**To deploy to the local network (Anvil):**

```bash
# Make sure Anvil is running in another terminal
make deploy
```

**To deploy to the Amoy test network:**

```bash
make deploy ARGS="--network amoy"
```

This command will deploy the contract, verify it on Etherscan, and broadcast the transaction using the account defined in your `.env` file.

### Interacting with the Contract

After deployment, you can use the interaction scripts to call the contract's functions.

**1. Create a Proposal**

This command calls the `CreateProposal` script to create a new proposal on the most recently deployed contract.

```bash
# For local network
make createProposal

# For the Amoy network
make createProposal ARGS="--network amoy"
```

**2. Vote on a Proposal**

This command calls the `VoteProposal` script. By default, it votes "for" (true) on the proposal with ID `0`. You can modify the [`script/Interactions.s.sol`](script/Interactions.s.sol) file to change the proposal ID or the vote.

```bash
# For local network
make voteProposal

# For the Amoy network
make voteProposal ARGS="--network amoy"
```

**3. Get Proposals**

This command calls the `GetProposals` script to retrieve and display the list of all proposals from the contract.

```bash
# For local network
make getProposals

# For the Amoy network
make getProposals ARGS="--network amoy"
```

**4. Check if an Address has Voted**

This command calls the `CheckVoted` script to verify if a specific address has already voted on a given proposal. You may need to configure the address and proposal ID in the [`script/Interactions.s.sol`](script/Interactions.s.sol) file.

```bash
# For local network
make checkVoted

# For the Amoy network
make checkVoted ARGS="--network amoy"
```

**5. Set the Automation Forwarder Address**

This command is used to configure the address of the contract that will have permission to call the `performUpkeep` function (usually a Chainlink Automation forwarder).

```bash
# For local network
make setAutomationForwarder

# For the Amoy network
make setAutomationForwarder ARGS="--network amoy"
```

## Project Structure

-   `src/`: Contains the main source code of the contract (`ProposalVoting.sol`).
-   `script/`: Contains Foundry scripts for deployment (`DeployProposalVoting.s.sol`), configuration (`HelperConfig.s.sol`), and interaction (`Interactions.s.sol`).
-   `test/`: Contains the tests for the contracts (`TestProposalVoting.t.sol`).
-   `Makefile`: File with shortcuts for Foundry commands.

## License

This project is licensed under the MIT License.