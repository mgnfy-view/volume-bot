import fs from "fs";
import readline from "readline";

import dotenv from "dotenv";

import { config } from "./config.js";

dotenv.config();

function getConfig() {
    const environment = process.env.ENVIRONMENT;
    const localRpcUrl = process.env.LOCAL_RPC_URL;
    const mainnetRpcUrl = process.env.RPC_URL;
    const privateKeys = process.env.PRIVATE_KEYS.split(" ");

    // Perform sanity checks on environment variables
    if (!environment || !localRpcUrl || !mainnetRpcUrl || !privateKeys)
        throw new Error("Missing environment variables");
    if (environment !== "dev" && environment !== "production") throw new Error("Invalid environment");
    if (privateKeys.length == 0) throw new Error("No private keys provided");

    const globalConfig = {
        environment,
        rpcUrl: environment === "dev" ? localRpcUrl : mainnetRpcUrl,
        privateKeys,
        botConfig: config,
    };

    return globalConfig;
}

// Get the abi of a contract from it's build path
function getAbi(buildPath) {
    const jsonBuild = fs.readFileSync(buildPath);
    const jsonBuildParsed = JSON.parse(jsonBuild);

    return jsonBuildParsed.abi;
}

function query(query) {
    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout,
    });

    return new Promise((resolve) =>
        rl.question(query, (ans) => {
            rl.close();
            resolve(ans);
        })
    );
}

export { getConfig, getAbi, query };
