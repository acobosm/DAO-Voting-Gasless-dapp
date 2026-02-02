import DAOVotingABI from './abi/DAOVoting.json';
import MinimalForwarderABI from './abi/MinimalForwarder.json';

// Addresses from the provided file content comments
export const DAO_VOTING_ADDRESS = '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512';
export const MINIMAL_FORWARDER_ADDRESS = '0x5FbDB2315678afecb367f032d93F642f64180aa3';

// Anvil Chain ID
export const ANVIL_CHAIN_ID = 31337;

export const DAO_VOTING_CONFIG = {
  address: DAO_VOTING_ADDRESS as `0x${string}`,
  abi: DAOVotingABI.abi, // Assuming the JSON has an 'abi' field, usually true for Hardhat/Foundry outputs
};

export const FORWARDER_CONFIG = {
  address: MINIMAL_FORWARDER_ADDRESS as `0x${string}`,
  abi: MinimalForwarderABI.abi,
};