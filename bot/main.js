import { ethers } from "ethers";
import randomInteger from "random-int";
import randomFloat from "random-float";

import { FLASH_LOANER_BUILD_PATH, IERC20_BUILD_PATH } from "./utils/constants.js";
import { getConfig, getAbi, query } from "./utils/utilityFunctions.js";

async function main() {
    // Set up required entities
    const globalConfig = getConfig();
    const provider = new ethers.JsonRpcProvider(globalConfig.rpcUrl);
    const flashLoanerContract = new ethers.Contract(
        globalConfig.botConfig.flashLoanerContract,
        getAbi(FLASH_LOANER_BUILD_PATH),
        provider
    );
    const targetTokenContract = new ethers.Contract(
        globalConfig.botConfig.targetToken,
        getAbi(IERC20_BUILD_PATH),
        provider
    );

    // Display network details
    const networkDetails = await provider.getNetwork();
    console.log(`Connected to network: ${networkDetails.name}`);
    console.log(`Network chainId: ${networkDetails.chainId.toString()}\n`);

    let currentRound = 1;
    let currentWalletNumber = 0;
    let currentSigner;

    console.log(`Round ${currentRound}`);

    while (true) {
        currentSigner = new ethers.Wallet(globalConfig.privateKeys[currentWalletNumber], provider);

        // Indent the wallet number by 4 spaces for better hierarchical display
        console.log(`    Wallet number ${currentWalletNumber + 1} (${currentSigner.address})`);

        const {
            min: minNumberOfTimesToPerformVolumeIncreaseAction,
            max: maxNumberOfTimesToPerformVolumeIncreaseAction,
        } = globalConfig.botConfig.numberOfTimesToPerformVolumeIncreaseAction;
        const numberOfTimesToPerformVolumeIncreaseAction = randomInteger(
            minNumberOfTimesToPerformVolumeIncreaseAction,
            maxNumberOfTimesToPerformVolumeIncreaseAction
        );

        await increaseVolumeOperation(
            globalConfig,
            provider,
            currentWalletNumber,
            currentSigner,
            flashLoanerContract,
            targetTokenContract,
            numberOfTimesToPerformVolumeIncreaseAction
        );

        currentWalletNumber++;
        // If all wallets have been looped through, wrap back to the first wallet
        // and move to the next round
        if (currentWalletNumber === globalConfig.privateKeys.length) {
            const reply = await query("Continue next round? [Y/N]: ");
            if (reply === "N" || reply === "n") {
                process.exit(0);
            }

            currentWalletNumber = 0;
            currentRound++;

            console.log(`Round ${currentRound}\n`);
        }
    }
}

async function increaseVolumeOperation(
    globalConfig,
    provider,
    currentWalletNumber,
    signer,
    flashLoanerContract,
    targetTokenContract,
    numberOfTimesToPerformVolumeIncreaseAction
) {
    // Store the target token's symbol and decimals for quciker access
    const targetTokenSymbol = await targetTokenContract.symbol();
    const targetTokenDecimals = +(await targetTokenContract.decimals()).toString();

    while (numberOfTimesToPerformVolumeIncreaseAction > 0) {
        let flashLoanerContractWithSigner = flashLoanerContract.connect(signer);
        const { min: minFlashLoanAmount, max: maxFlashLoanAmount } = globalConfig.botConfig.flashLoanAmount;
        const randomEthAmount = randomFloat(minFlashLoanAmount, maxFlashLoanAmount);
        const flashLoanAmountParsed = ethers.parseEther(`${randomEthAmount}`);
        const token = globalConfig.botConfig.targetToken;
        const minimumTokenAmountOut = ethers.parseUnits("0", targetTokenDecimals);
        const deadline = Math.floor(Date.now() / 1000) + 2 * 60; // 2 minutes deadline

        const tx = await flashLoanerContractWithSigner.initiateFlashLoan(
            flashLoanAmountParsed,
            token,
            minimumTokenAmountOut,
            deadline,
            {
                value: ethers.parseEther(globalConfig.botConfig.bufferToPayFees.toString()),
            }
        );
        await tx.wait();

        console.log(`\tCurrent wallet's Eth balance: ${ethers.formatEther(await provider.getBalance(signer.address))}`);
        console.log(`\tEth amount used for increasing volume: ${randomEthAmount}`);
        console.log(
            `\tCurrent wallet's ${targetTokenSymbol} balance: ${ethers.formatUnits(
                await targetTokenContract.balanceOf(signer.address),
                targetTokenDecimals
            )}`
        );

        const { min: minWaitTime, max: maxWaitTime } = globalConfig.botConfig.repeatVolumeIncreaseActionAfterInterval;
        const waitFor = randomInteger(minWaitTime, maxWaitTime);

        console.log(`\tWaiting for ${waitFor / 1000} seconds before starting the next volume increase action...\n`);

        // Wait before starting the next volume increase action
        await new Promise((resolve) => setTimeout(resolve, waitFor));

        numberOfTimesToPerformVolumeIncreaseAction--;
    }

    const ethBalanceToSend =
        +ethers.formatEther(await provider.getBalance(signer.address)) -
        globalConfig.botConfig.residueAmountToKeepInWallet;
    const nextWalletNumber = currentWalletNumber + 1 === globalConfig.privateKeys.length ? 0 : currentWalletNumber + 1;

    console.log(`\tSending ${ethBalanceToSend} Eth to the next wallet (wallet ${nextWalletNumber + 1})\n`);

    let tx = await signer.sendTransaction({
        to: new ethers.Wallet(globalConfig.privateKeys[nextWalletNumber], provider).address,
        value: ethers.parseEther(ethBalanceToSend.toString()),
    });
    await tx.wait();
}

// main().catch((error) => {
//     console.error(error.message);
// });

main();
