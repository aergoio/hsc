# horde-smart-contract
Smart Contract to control and manage Horde including Communication Protocol, etc.

# Installing Dependencies
We recommend to use a virtual environment below.
```bash
pipenv shell
pipenv install
```
Using Pipenv, all dependencies will be installed automatically.

# Compile
```bash
$ python hsc_compile.py
Searching AERGO Path ...
  > AERGO_PATH:  /Users/yp/work/blocko/go/src/github.com/aergoio/aergo
  > 'aergoluac':  /Users/yp/work/blocko/go/src/github.com/aergoio/aergo/bin/aergoluac

Compiling Horde Smart Contract (HSC)
  > compiled ... hsc_meta.lua
  > compiled ... hsc_main.lua
  > compiled ... hsc_db.lua
  > compiled ... hsc_cmd.lua
  > compiled ... hsc_result.lua
  > compiled ... hsc_config.lu
```

If you want to compile HSC, you should have the Aergo Lua Compiler([aergoluac](https://docs.aergo.io/en/latest/smart-contracts/lua/guide.html#tools))

Without it, you will face the error
```bash
$ python hsc_compile.py
Searching AERGO Path ...
  > AERGO_PATH:  /Users/yp/work/yp/go/src/github.com/aergoio/aergo
ERROR: Cannot find AERGO_PATH for finding AERGO Lua Compiler (aergoluac)
```

# Deploy
To deploy, you need to designate a target, private key. If not, the default target would be "testnet.aergo.io" currently, and a private key will generate automatically.
```bash
$ python hsc_deploy.py --help
Usage: hsc_deploy.py [OPTIONS] COMMAND [ARGS]...

Options:
  --target TEXT           target AERGO for Horde configuration
  --private-key TEXT      the private key to create Horde Smart Contract. If
                          not set, it will be random
  --waiting-time INTEGER  the private key to create Horde Smart Contract
  --help                  Show this message and exit.
```

The default target is the testnet of Aergo, so you cannot deploy with 0 token for fee. Follow the instruction to top up your tokens.
```bash
$ python hsc_deploy.py
Account:
  Private Key: 6iaB33zFSQ4jR2BZqHef9GkvjhQe6RSqk2fpndiczpjWgGhq3F6
  Address: AmMLjEPSx6QSqxPZF4aoQfihNVipzDTE6xcKuG1Uh5MaxGSNmq9g
--------- Get Account Info -----------
    - Nonce:        0
    - balance:      0 aergo
Not enough balance.

You need to request AERGO tokens on

  https://faucet.aergoscan.io/

with the address:

  AmMLjEPSx6QSqxPZF4aoQfihNVipzDTE6xcKuG1Uh5MaxGSNmq9g

And deploy again with the private key:

  python hsc_deploy.py --private-key 6iaB33zFSQ4jR2BZqHef9GkvjhQe6RSqk2fpndiczpjWgGhq3F6
```

After deploying successfully,
```bash
$ python hsc_deploy.py --target localhost:7845
Account:
  Private Key: 6iaJPeExEcxMpj5zTQAQjTLnnkzU1Rjp5EZWvpzuucXdRRHUiyd
  Address: AmMBrLuLdXs2rqPJ6pAE9rJDKTAPfDpxYeFEroMqBvLG6dE2kozr
--------- Get Account Info -----------
    - Nonce:        0
    - balance:      10 aergo
Compiling Horde Smart Contract (HSC)
  > deployed ... hsc_main.lua
  > deployed ... hsc_db.lua
  > deployed ... hsc_cmd.lua
  > deployed ... hsc_result.lua
  > deployed ... hsc_config.lua

Horde Smart Contract Address = AmhmYAtCEw2Q9ZXEaJRbXuBKRv8vPQn9R3Vf24YgG5cbQbTKg519
Prepared Horde Smart Contract
```

You will get the Horde Smart Contract address.

You need to remember 
* the private key of the account (ie. "6iaJPeExEcxMpj5zTQAQjTLnnkzU1Rjp5EZWvpzuucXdRRHUiyd")
* and HSC address (ie. "AmhmYAtCEw2Q9ZXEaJRbXuBKRv8vPQn9R3Vf24YgG5cbQbTKg519")

# Check HSC address
You can check the deployed HSC address again.
```bash
$ tail -n -2 hsc.payload.dat
  "hsc_address": "AmhU5GtxZgfjH8B1CbrKsLc1agumBGEEE47cNhKC3uYMQqgXPB1n"
```
The Horde Smart Contract address is above, in the example it is "AmhU5GtxZgfjH8B1CbrKsLc1agumBGEEE47cNhKC3uYMQqgXPB1n".

However, if you lost the private key, you could not upgrade the HSC anymore. It means you need to migrate all data every time upgrade HSC.
