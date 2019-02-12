# horde-smart-contract
Smart Contract to control and manage Horde including Communication Protocol, etc.

# Version
* 0.1.3 Simple access control by Computing Group (Horde) Onwer/Blockchain (Pond) Creator

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

Compiling Manifest
  > compiled ... _manifest.lua
  > compiled ... _manifest_db.lua

Compiling Horde Smart Contract (HSC)
  > compiled ... hsc_command.lua
  > compiled ... hsc_space_computing.lua
  > compiled ... hsc_space_blockchain.lua

```

If you want to compile HSC, you should have the Aergo Lua Compiler([aergoluac](https://docs.aergo.io/en/latest/smart-contracts/lua/guide.html#tools))

Without it, you will face the error
```bash
$ python hsc_compile.py
Searching AERGO Path ...
  > AERGO_PATH:  /Users/yp/work/yp/go/src/github.com/aergoio/aergo
ERROR: Cannot find AERGO_PATH for finding AERGO Lua Compiler (aergoluac)
```

You can set the AERGO path manually
```bash
export AERGO_PATH=/Users/yp/work/blocko/go/src/github.com/aergoio/aergo/bin
python hsc_compile.py
```

## Cache
If you don't modify any Lua code under 'sc' directory, it will not compile.
```bash
$ python hsc_compile.py
Searching AERGO Path ...                                           
  > AERGO_PATH:  /Users/yp/work/blocko/go/src/github.com/aergoio/aergo/bin                                                             
  > 'aergoluac':  /Users/yp/work/blocko/go/src/github.com/aergoio/aergo/bin/aergoluac                                                  

Compiling Manifest                                                 
  > ............ _manifest.lua                                     
  > ............ _manifest_db.lua                                  

Compiling Horde Smart Contract (HSC)                               
  > ............ hsc_command.lua                                   
  > ............ hsc_space_computing.lua                           
  > ............ hsc_space_blockchain.lua
  
```
All cached data is stored in the 'hsc.compiled.payload.dat' file.

# Deploy
To deploy, you need to designate a target, private key. If not, the default target would be [testnet](https://testnet.aergoscan.io/) of Aergo, and a private key will generate automatically.
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
  Private Key: 6imerQYecKf8BqHNRQVqGuSoDS9BqDC3EtFtCXM5MPEZQySACEY
  Address: AmLwYmhkFCh53fBSPJ25TCuezSFpBTu4M8uPWoP8j7LjupXeUYvW
  > Account Info
    - Nonce:        0
    - balance:      0 aergo
Not enough balance.

You need to request AERGO tokens on

  https://faucet.aergoscan.io/

with the address:

  AmLwYmhkFCh53fBSPJ25TCuezSFpBTu4M8uPWoP8j7LjupXeUYvW

And deploy again with the private key:

  python hsc_deploy.py --private-key 6imerQYecKf8BqHNRQVqGuSoDS9BqDC3EtFtCXM5MPEZQySACEY

```

After deploying successfully, (in this example, I used locally installed and independent Aergo node)
```bash
$ python hsc_deploy.py --target localhost:7845                     
Account:
  Private Key: 6jDmfXvispppzyTcBLWa2Bgj97kU8fo5633YLdd9EAv9E235ieJ
  Address: AmQGyUNZ9C9hEYCaxRTam34ssgAM95yF5eZvRJNmBnwe4Af87ajw
  > Account Info
    - Nonce:        0
    - balance:      10 aergo
Deploying Manifest
  > deployed ... _manifest.lua
  > deployed ... _manifest_db.lua

Deploying Horde Smart Contract (HSC)
  > deployed ... hsc_command.lua
  > deployed ... hsc_space_computing.lua
  > deployed ... hsc_space_blockchain.lua

Horde Smart Contract Address = Amhs3AYJiuVzZoG3YyiMGSMkLSb2o6earj5udcAW15JiNfia4jvJ
Prepared Horde Smart Contract
Deployed HSC Address: Amhs3AYJiuVzZoG3YyiMGSMkLSb2o6earj5udcAW15JiNfia4jvJ
```

You will get the Horde Smart Contract address.

You need to remember 
* the private key of the account (ie. "6jDmfXvispppzyTcBLWa2Bgj97kU8fo5633YLdd9EAv9E235ieJ")
* and HSC address (ie. "Amhs3AYJiuVzZoG3YyiMGSMkLSb2o6earj5udcAW15JiNfia4jvJ")

## Cache
If you don't modify or add any Lua code under 'sc' directory, it will not compile and will not deploy.
```bash
$ python hsc_deploy.py --target localhost:7845 --private-key 6jDmfXvispppzyTcBLWa2Bgj97kU8fo5633YLdd9EAv9E235ieJ
  > Account Info
    - Nonce:        6
    - balance:      10 aergo
HSC is already deployed (Version: "v0.1.2")
Deploying Manifest
  > ............ _manifest.lua
  > ............ _manifest_db.lua

Deploying Horde Smart Contract (HSC)
  > ............ hsc_command.lua
  > ............ hsc_space_computing.lua
  > ............ hsc_space_blockchain.lua

Horde Smart Contract Address = Amhs3AYJiuVzZoG3YyiMGSMkLSb2o6earj5udcAW15JiNfia4jvJ
Prepared Horde Smart Contract
Deployed HSC Address: Amhs3AYJiuVzZoG3YyiMGSMkLSb2o6earj5udcAW15JiNfia4jvJ
```
All cached data is stored in the 'hsc.deployed.payload.dat' file.

# Check HSC address
You can check the deployed HSC address again.
```bash
$ tail -n -2 hsc.deployed.payload.dat 
  "hsc_address": "Amhs3AYJiuVzZoG3YyiMGSMkLSb2o6earj5udcAW15JiNfia4jvJ"
```
The Horde Smart Contract address is above, in the example it is "Amhs3AYJiuVzZoG3YyiMGSMkLSb2o6earj5udcAW15JiNfia4jvJ".

However, if you lost the private key, you could not upgrade the HSC anymore. It means you need to migrate all data every time upgrade HSC.

# Check HSC version
You can check the version the deployed HSC using [HeraPy](https://github.com/aergoio/herapy) via Python.
```bash
$ python
Python 3.7.1 (default, Nov 28 2018, 11:51:47) 
[Clang 10.0.0 (clang-1000.11.45.5)] on darwin
Type "help", "copyright", "credits" or "license" for more information.
>>> import aergo.herapy as herapy
>>> aergo = herapy.Aergo()
>>> aergo.new_account()
<aergo.herapy.account.Account object at 0x10e67a588>
>>> aergo.connect('localhost:7845')
>>> aergo.query_sc('Amhs3AYJiuVzZoG3YyiMGSMkLSb2o6earj5udcAW15JiNfia4jvJ', 'getVersion')
b'"v0.1.2"'
>>> exit()
```
