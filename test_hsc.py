import os
import traceback
import sys
import json
import time
import datetime
import aergo.herapy as herapy

AERGO_TARGET = "localhost:7845"
AERGO_PRIVATE_KEY = "6huq98qotz8rj3uEx99JxYrpQesLN7P1dA14NtcR1NLvD7BdumN"
AERGO_WAITING_TIME = 3
aergo = None

HSC_META = 'hsc_meta.lua'
HSC_ADDRESS = "AmgUPYeR2w8Hrh4pauwDRzykGUjvRTNEoH65S6xXawoy3CAZrEda"

DEPLOY_HSC_JSON = 'hsc.payload.dat'


def exit(error=True):
    if aergo is not None:
        aergo.disconnect()

    if error:
        sys.exit(1)

    sys.exit(0)


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


def call_sc(func_name, args=None):
    # send TX
    tx, result = aergo.call_sc(HSC_ADDRESS, func_name, args=args)
    if result.status != herapy.CommitStatus.TX_OK:
        eprint("ERROR[{0}]: {1}".format(result.status, result.detail))
        aergo.disconnect()
        exit()

    time.sleep(int(AERGO_WAITING_TIME))

    # check TX
    result = aergo.get_tx_result(tx.tx_hash)
    if result.status != herapy.SmartcontractStatus.SUCCESS:
        eprint("ERROR[{0}]:{1}: {2}".format(result.contract_address, result.status, result.detail))
        aergo.disconnect()
        exit()

    return tx


def query_sc(func_name, args=None, hsc_address=HSC_ADDRESS):
    # send TX
    result = aergo.query_sc(hsc_address, func_name, args=args)
    print(result)
    return result


def get_hsc_address():
    # read deploy json
    if os.path.isfile(DEPLOY_HSC_JSON):
        with open(DEPLOY_HSC_JSON) as f:
            deployed_info = json.load(f)
            f.close()
    else:
        eprint("Cannot find HSC Address, deploy first.")
        exit()

    """
    global HSC_ADDRESS
    HSC_ADDRESS = deployed_info[HSC_META]['address']
    """


def insert_cmd_create_pond():
    #rand_str = str(time.time())
    rand_str = datetime.datetime.now().strftime("%I:%M%p on %B %d, %Y")
    pond_id = "pond-" + rand_str
    cmd = {
        "cmd_name": "create_pond",
        "pond_id": pond_id,
        "pond_name": "pond-" + rand_str,
        "bnode_list": [
            {
                "bnode_name": "bnode-1-" + rand_str,
                "hmc_id": "AmNnfikH8tmJbD1GWjPKVqFSc7MfLStFxAteqUmHWppVUCUqJyAJ",
                "cnode_name": "minikube",
                "config": """
enabletestmode="True"
[rpc]
netserviceaddr="123.456.789.000"
netserviceport=7777
"""
            },
        ]
    }
    '''
    {
        "bnode_name": "bnode-2-" + rand_str,
        "hmc_id": "AmNnfikH8tmJbD1GWjPKVqFSc7MfLStFxAteqUmHWppVUCUqJyAJ",
        "cnode_name": "minikube",
        "config": """
[rpc]
netserviceport=7779
"""
    },
    {
        "bnode_name": "bnode-3-" + rand_str,
        "hmc_id": "AmNnfikH8tmJbD1GWjPKVqFSc7MfLStFxAteqUmHWppVUCUqJyAJ",
        "cnode_name": "minikube",
        "config": """
[rpc]
netserviceport=7779
"""
    },
    '''
    cmd = json.dumps(cmd)
    cmd_tx = call_sc("insertCommand", [cmd, "AmNnfikH8tmJbD1GWjPKVqFSc7MfLStFxAteqUmHWppVUCUqJyAJ"])
    cmd_id = str(cmd_tx.tx_hash)
    print("CMD TX = {}".format(cmd_tx))
    print("CMD ID = {}".format(cmd_id))

    print("\nQuery Command:")
    result = query_sc("queryCommand", "AmNnfikH8tmJbD1GWjPKVqFSc7MfLStFxAteqUmHWppVUCUqJyAJ")
    result = json.loads(result)
    print(json.dumps(result, indent=2))
    for cmd in result["cmd_list"]:
        print("CMD ID: {}".format(cmd["cmd_id"]))
        cmds = json.loads(cmd["cmd"])
        print(json.dumps(cmds, indent=2))

    time.sleep(10)

    # test: query result
    print("\nQuery Result:")
    result = query_sc("queryResult", cmd_id)
    result = json.loads(result)
    print(json.dumps(result, indent=2))
    for r in result["results"]:
        print("\nHMC ID: {}".format(r["hmc_id"]))
        detail = json.loads(r["result"])
        print(json.dumps(detail, indent=2))

    return pond_id


def insert_cmd_get_bnode_list(pond_id="pond-01:40PM on January 15, 2019"):
    cmd = {
        "cmd_name": "get_bnode_list",
        "pond_id": pond_id,
    }
    cmd = json.dumps(cmd)
    cmd_tx = call_sc("insertCommand", [cmd, "AmNnfikH8tmJbD1GWjPKVqFSc7MfLStFxAteqUmHWppVUCUqJyAJ"])
    cmd_id = str(cmd_tx.tx_hash)
    print("CMD TX = {}".format(cmd_tx))
    print("CMD ID = {}".format(cmd_id))

    print("\nQuery Command:")
    result = query_sc("queryCommand", "AmNnfikH8tmJbD1GWjPKVqFSc7MfLStFxAteqUmHWppVUCUqJyAJ")
    result = json.loads(result)
    print(json.dumps(result, indent=2))
    for cmd in result["cmd_list"]:
        print("CMD ID: {}".format(cmd["cmd_id"]))
        cmds = json.loads(cmd["cmd"])
        print(json.dumps(cmds, indent=2))

    time.sleep(10)

    # test: query result
    print("\nQuery Result:")
    result = query_sc("queryResult", cmd_id)
    result = json.loads(result)
    print(json.dumps(result, indent=2))
    for r in result["results"]:
        print("\nHMC ID: {}".format(r["hmc_id"]))
        detail = json.loads(r["result"])
        print(json.dumps(detail, indent=2))


def main():
    if 'AERGO_TARGET' in os.environ:
        global AERGO_TARGET
        AERGO_TARGET = os.environ['AERGO_TARGET']

    if 'AERGO_PRIVATE_KEY' in os.environ:
        global AERGO_PRIVATE_KEY
        AERGO_PRIVATE_KEY = os.environ['AERGO_PRIVATE_KEY']

    if 'AERGO_WAITING_TIME' in os.environ:
        global AERGO_WAITING_TIME
        AERGO_WAITING_TIME = os.environ['AERGO_WAITING_TIME']

    global aergo
    aergo = herapy.Aergo()
    aergo.connect(AERGO_TARGET)
    aergo.new_account(private_key=AERGO_PRIVATE_KEY)

    get_hsc_address()

    #insert_cmd_create_pond()
    insert_cmd_get_bnode_list()


if __name__ == '__main__':
    try:
        main()
        exit(False)
    except Exception:
        traceback.print_exception(*sys.exc_info())
        exit()

