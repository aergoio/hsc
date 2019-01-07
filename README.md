
horde-smart-contract
====================

Smart Contract to control and manage Horde. Including Communication Protocol, etc.
 
Downloading horde-smart-contract
--------------------------------
 
Download horde-smart-contract from this repository.
  
    git clone git@github.com:aergoio/hsc.git
    cd hsc

Installing Dependencies
-----------------------

We recommend to use a virtual environment below.

**Virtual Environment (Pipenv)** 

Using Pipenv, all dependencies will be installed automatically.

    pipenv shell

If you cleaned up and setup again,

    pipenv install

Compiling horde-smart-contract
------------------------------

We use aergoluac to compile horde-smart-contract.
So you need aergoluac in AERGO_PATH.

    python hsc-compile.py

Then you can check the payload in **hsc.payload.dat** file

Deploying horde-smart-contract
------------------------------

We use AERGO chain to deploy horde-smart-contract.
So you need to run the AERGO chain before you deploy horde-smart-contract.

    python hsc-deploy.py

