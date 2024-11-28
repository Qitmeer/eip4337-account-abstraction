Implementation of contracts for [ERC-4337](https://eips.ethereum.org/EIPS/eip-4337) account abstraction via alternative mempool.

# Resources

[Vitalik's post on account abstraction without Ethereum protocol changes](https://medium.com/infinitism/erc-4337-account-abstraction-without-ethereum-protocol-changes-d75c9d94dc4a)

[Discord server](http://discord.gg/fbDyENb6Y9)

[Bundler reference implementation](https://github.com/eth-infinitism/bundler)

[Bundler specification test suite](https://github.com/eth-infinitism/bundler-spec-tests)

## Deploy

- `mv .env.example .env`
- set rpc and MNEMONIC_FILE
- node version 18
- `yarn install`
- `yarn deploy`

```bash
==entrypoint addr= 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
reusing "QngAccountFactory" at 0xb979a65B7168FC48284D9afF1A079436761A21EB
==QngAccountFactory addr= 0xb979a65B7168FC48284D9afF1A079436761A21EB
reusing "QngPaymaster" at 0xa9E0107cE8340D7E025885be51ce53F467dCebC1
==MeerChangePaymaster addr= 0xa9E0107cE8340D7E025885be51ce53F467dCebC1
```
