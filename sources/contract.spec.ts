import { toNano } from "@ton/core";
import { Blockchain } from "@ton/sandbox";
import "@ton/test-utils";
import { NftFixpriceSaleV1 } from "./output/example_NftFixpriceSaleV1";
import { findErrorCodeByMessage } from './utils/error';

describe("contract", () => {
    it("should deploy correctly", async () => {
        // Create Sandbox and deploy contract
        let system = await Blockchain.create();
        let owner = await system.treasury("owner");
        let nonOwner = await system.treasury("non-owner");
        let contract = system.openContract(await NftFixpriceSaleV1.fromInit());
        const deployResult = await contract.send(owner.getSender(), { value: toNano(1) }, { $$type: "Deploy", queryId: 0n });
        expect(deployResult.transactions).toHaveTransaction({
            from: owner.address,
            to: contract.address,
            deploy: true,
            success: true,
        });
    });
});
