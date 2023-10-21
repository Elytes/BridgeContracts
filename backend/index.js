import { ethers } from "ethers";
import express from "express";

const chains = {
    "622277": "http://127.0.0.1:8545",
    "80001": "https://rpc-mumbai.maticvigil.com",
}

let providers = {};

const events = [
    "event ActionCreated(bytes32 indexed id, uint256 indexed nonce, uint256 actionType, address receiver, uint256 amount)",
    "event ActionRequested(bytes32 indexed id);",
    "function authorizeAction(bytes32 action) public returns (bool success)"
];

const bridges = {
    "0x7af79c9A3266A927cdF06Ea18ff2A31e0B9DEfeD": {
        "chains": ["622277", "80001"],
        "coin": "RTH",
    }
}

console.log("Connecting to providers...")
for(let chainId in chains) {
    providers[chainId] = new ethers.JsonRpcProvider(chains[chainId]);
}

console.log("Initializing contracts...")
let contracts = {}
for(let bridge in bridges) {
    for(let chainId of bridges[bridge].chains) {
        contracts[chainId] = new ethers.Contract(bridge, events, providers[chainId]);
    }
}

for(let contract in contracts) {
    contract.on(contract.filters.ActionCreated, (id, nonce, actionType, receiver, amount, event) => {
        onActionCreated(id, nonce, actionType, receiver, amount, contract);
    })
    contract.on(contract.filters.ActionRequested, (id, event) => {
        onActionRequested(id, contract);
    })
}

function onActionCreated(id, nonce, actionType, receiver, amount, contract) {
    console.log({
        "id": id,
        "nonce": nonce,
        "actionType": actionType,
        "receiver": receiver,
        "amount": amount,
    })
}

function onActionRequested(id, contract) {
    console.log({
        "id": id,
    })
    contract.authorizeAction(id);
}

const server = express();
server.listen(3000, () => {
    console.log(`Listening at http://localhost:${port}`)
})

server.post("/api/proof-of-burn", async (request, response) => {
    const { id, blockNumber } = request.body;

    if (typeof id !== "string") {
        response.status(400).json({
            success: false,
            message: "id must be a string"
        })
        return;
    }

    if (typeof blockNumber !== "number") {
        response.status(400).send({
            success: false,
            message: "blocknumber must be a number"
        });
        return;
    }

    const event = await contract.queryFilter(contract.filters.ActionCreated, blockNumber, blockNumber);
    if (event.length === 0) {
        response.status(400).send({
            success: false,
            message: "invalid proof of burn"
        });
        return;
    }

    const success = await contract.authorizeAction(id);

    if(!success) {
        response.status(400).send({
            success: false,
            message: "invalid proof of burn"
        });
        return;
    }

    response.status(200).send({
        success: true,
        message: "action authorized"
    });
})

server.get("/api/bridges", async (request, response) => {

})
