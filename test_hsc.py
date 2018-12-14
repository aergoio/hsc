import os
import traceback
import sys
import json
import time
import aergo.herapy as herapy

AERGO_TARGET = "localhost:7845"
AERGO_PRIVATE_KEY = "6huq98qotz8rj3uEx99JxYrpQesLN7P1dA14NtcR1NLvD7BdumN"
AERGO_ACCOUNT_PASSWORD = "coolguy"
AERGO_WAITING_TIME = 3
aergo = None

HSC_META = 'hsc_meta.lua'
HSC_ADDRESS = ""

DEPLOY_HSC_JSON = '../hsc.payload.dat'


def exit(error=True):
    if aergo is not None:
        aergo.disconnect()

    if error:
        """
        try:
            os.remove(DEPLOY_HSC_JSON)
        except FileNotFoundError:
            pass
        """
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


def query_sc(func_name, args=None):
    # send TX
    result = aergo.query_sc(HSC_ADDRESS, func_name, args=args)
    print(result)
    return result


def main():
    if 'AERGO_TARGET' in os.environ:
        global AERGO_TARGET
        AERGO_TARGET = os.environ['AERGO_TARGET']

    if 'AERGO_PRIVATE_KEY' in os.environ:
        global AERGO_PRIVATE_KEY
        AERGO_PRIVATE_KEY = os.environ['AERGO_PRIVATE_KEY']

    if 'AERGO_ACCOUNT_PASSWORD' in os.environ:
        global AERGO_ACCOUNT_PASSWORD
        AERGO_ACCOUNT_PASSWORD = os.environ['AERGO_ACCOUNT_PASSWORD']

    if 'AERGO_WAITING_TIME' in os.environ:
        global AERGO_WAITING_TIME
        AERGO_WAITING_TIME = os.environ['AERGO_WAITING_TIME']

    global aergo
    aergo = herapy.Aergo()
    aergo.connect(AERGO_TARGET)
    aergo.new_account(password=AERGO_ACCOUNT_PASSWORD, private_key=AERGO_PRIVATE_KEY)

    # read deploy json
    if os.path.isfile(DEPLOY_HSC_JSON):
        with open(DEPLOY_HSC_JSON) as f:
            deployed_info = json.load(f)
            f.close()
    else:
        eprint("Cannot find HSC Address, deploy first.")
        exit()

    global HSC_ADDRESS
    HSC_ADDRESS = deployed_info[HSC_META]['address']

    command = "cmd-" + str(time.time())

    # test: insert command
    call_sc("insertCommand", [command,
                              "AmLaSifmhjHnys8baftuWRiXi8HEJTbthQRPxYrcXEVeZuXviZug",
                              "AmQNRjb6rtqc6Jc5tsaTupQPAHXaD2EvDcBehyysw8Wbhp1oW1a9",
                              "AmNLs16rGYdA1gimmHnCpzFKXYNt7rbGSQNiKzM3zLs1MPNQaft9",
                              "AmN8ckriiPqiU2kcrqfgLKS74gvuczkpLLVoPSyLHnu5SQEmRHse",
                              "AmLqJz4XpdHWePnDkqNfJ5aTMNbT6cPA2qHakFGQVHEz6BxswLsj",
                              "AmLnzr5unZhbDwfBbr8eCbkRme7hBQzU4bENcPcagBTL7GG3Qwgx",
                              "AmN8uVenDp4dzAuSYLArw7uKTjNhpBsztNmZQFiBQ6DFaQD7f1HC",
                              ])

    # test: query all command
    print("1")
    query_sc("queryCommand", ["AmLaSifmhjHnys8baftuWRiXi8HEJTbthQRPxYrcXEVeZuXviZug", True, True])
    print("2")
    query_sc("queryCommand", ["AmQNRjb6rtqc6Jc5tsaTupQPAHXaD2EvDcBehyysw8Wbhp1oW1a9", True, True])
    print("3")
    query_sc("queryCommand", ["AmNLs16rGYdA1gimmHnCpzFKXYNt7rbGSQNiKzM3zLs1MPNQaft9", True, True])
    print("4")
    query_sc("queryCommand", ["AmN8ckriiPqiU2kcrqfgLKS74gvuczkpLLVoPSyLHnu5SQEmRHse", True, True])
    print("5")
    query_sc("queryCommand", ["AmLqJz4XpdHWePnDkqNfJ5aTMNbT6cPA2qHakFGQVHEz6BxswLsj", True, False])
    print("6")
    query_sc("queryCommand", ["AmLnzr5unZhbDwfBbr8eCbkRme7hBQzU4bENcPcagBTL7GG3Qwgx", True, True])
    print("7")
    result = query_sc("queryCommand", ["AmN8uVenDp4dzAuSYLArw7uKTjNhpBsztNmZQFiBQ6DFaQD7f1HC", False, False])

    result = json.loads(result)
    cmd_id = result['cmd_list'][0]['cmd_id']
    print("Command ID =", cmd_id)

    # test: insert result
    hmc_id_list = [
        "AmLaSifmhjHnys8baftuWRiXi8HEJTbthQRPxYrcXEVeZuXviZug",
        "AmQNRjb6rtqc6Jc5tsaTupQPAHXaD2EvDcBehyysw8Wbhp1oW1a9",
        "AmNLs16rGYdA1gimmHnCpzFKXYNt7rbGSQNiKzM3zLs1MPNQaft9",
        "AmN8ckriiPqiU2kcrqfgLKS74gvuczkpLLVoPSyLHnu5SQEmRHse",
        "AmLqJz4XpdHWePnDkqNfJ5aTMNbT6cPA2qHakFGQVHEz6BxswLsj",
        "AmLnzr5unZhbDwfBbr8eCbkRme7hBQzU4bENcPcagBTL7GG3Qwgx",
        "AmN8uVenDp4dzAuSYLArw7uKTjNhpBsztNmZQFiBQ6DFaQD7f1HC",
    ]
    for hmc_id in hmc_id_list:
        call_sc("insertResult", [cmd_id, hmc_id, "result~~~!!!@_@;;" + hmc_id])

    # test: query result
    result = query_sc("queryResult", cmd_id)
    result = json.loads(result)
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    try:
        main()
        exit(False)
    except Exception:
        traceback.print_exception(*sys.exc_info())
        exit()
