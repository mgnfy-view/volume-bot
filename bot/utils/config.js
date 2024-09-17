import { Range } from "./utilityClasses.js";

const config = {
    numberOfTimesToPerformVolumeIncreaseAction: new Range(1, 3),
    repeatVolumeIncreaseActionAfterInterval: new Range(1000, 2000), // In milliseconds
    flashLoanAmount: new Range(0.25, 0.5), // Eth amount to flash loan
    bufferToPayFees: 0.2, // Amount which will be used to pay the flash loan and swap fees
    residueAmountToKeepInWallet: 0.005, // While moving from one active wallet to another, some eth needs to be kept in the inactive wallet as residue
    targetToken: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", // Mainnet USDC address
    flashLoanerContract: "0xfaA7b3a4b5c3f54a934a2e33D34C7bC099f96CCE",
};

export { config };
