import { expect, use } from 'chai';
import { Contract, utils } from 'ethers';
import {
    deployContract,
    MockProvider,
    solidity
} from 'ethereum-waffle';

import fs from 'fs';
const ID = JSON.parse(fs.readFileSync('./build/ID.json'));

use(solidity);

const message = `fizz buzz test one two...

-------

Royalty Rate
10.00%

Royalty Owner
0x4133c79E575591b6c380c233FFFB47a13348DE86

Token Metadata
ipfs://QmYHFEo1n7oc685SA24kDFXzqXNtuMjVBrevQiUhGT2THB`;

const x = {
    "messageMemo": "fizz buzz test one two...",
    "messageRoyaltyRateInteger": "10",
    "messageRoyaltyRateDecimal": "00",
    "messageRoyaltyOwner": "0x4133c79E575591b6c380c233FFFB47a13348DE86",
    "messageTokenURI": "ipfs://QmYHFEo1n7oc685SA24kDFXzqXNtuMjVBrevQiUhGT2THB",
    "messageSignature": "0x9910f0ec44c958e64ac95df0fae759e89563dd361074b03cfe95f9d8ea5dfaf76d344ac02f499727d55f90119b4c71a436939725d3569ab63c5f5df9f770fb141b"
};

describe('ID', () => {
    const [creator, ...accounts] = new MockProvider().getWallets();
    let id = null;
    const nullAddr = '0x0000000000000000000000000000000000000000';

    it('deploys', async () => {
        id = await deployContract(creator, ID, [ ]);
    });
    it('mints from signature - external', async () => {
        const txn = await id.mintFromSignature(
            x.messageMemo,
            x.messageRoyaltyRateInteger,
            x.messageRoyaltyRateDecimal,
            x.messageRoyaltyOwner,
            x.messageTokenURI,
            x.messageSignature
        );
        const b = await id.balanceOf('0x4133c79e575591b6c380c233fffb47a13348de86');
        expect(b.toNumber()).to.equal(1);
    });

    it('mints from signature - internal', async () => {
        const creatorSignature = await creator.signMessage(message);
        const txn = await id.mintFromSignature(
            x.messageMemo,
            x.messageRoyaltyRateInteger,
            x.messageRoyaltyRateDecimal,
            x.messageRoyaltyOwner,
            x.messageTokenURI,
            creatorSignature
        );
        const b = await id.balanceOf(creator.address);
        expect(b.toNumber()).to.equal(1);
    });

    it('burns', async () => {
        const tokenID = await id.tokenOfOwnerByIndex(creator.address, 0);
        await id.burn(tokenID);
        const b = await id.balanceOf(creator.address);
        expect(b.toNumber()).to.equal(0);
    });

    it('prevents remint from signature', async () => {
        const creatorSignature = await creator.signMessage(message);
        await expect(id.mintFromSignature(
            x.messageMemo,
            x.messageRoyaltyRateInteger,
            x.messageRoyaltyRateDecimal,
            x.messageRoyaltyOwner,
            x.messageTokenURI,
            creatorSignature
        )).to.be.reverted;
        const b = await id.balanceOf(creator.address);
        expect(b.toNumber()).to.equal(0);
    });

    it('prevents remint directly', async () => {
        await expect(id.mint(
            x.messageRoyaltyRateInteger,
            x.messageRoyaltyRateDecimal,
            x.messageRoyaltyOwner,
            x.messageTokenURI
        )).to.be.reverted;
        const b = await id.balanceOf(creator.address);
        expect(b.toNumber()).to.equal(0);
    });
});