import { Address, contractAddress} from "@ton/core";
import { TonClient4 } from "@ton/ton";
import { NftFixpriceSaleV1 } from "./output/example_NftFixpriceSaleV1";

(async () => {
    const client = new TonClient4({
        endpoint: "https://sandbox-v4.tonhubapi.com", // 🔴 Test-net API endpoint
    });

    // Parameters
    let owner = Address.parse("");
    let init = await NftFixpriceSaleV1.init(owner));
    let contract_address = contractAddress(0, init);

    // Prepareing
    console.log("Reading Contract Info...");
    console.log(contract_address);

    // Input the contract address
    let contract = await NftFixpriceSaleV1.fromAddress(contract_address);
    let contract_open = await client.open(contract);
    console.log("Counter Value: " + (await contract_open.getCounter()));
})();
