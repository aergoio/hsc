import os
import traceback
import sys
import json
import time
import aergo.herapy as herapy

AERGO_TARGET = "localhost:7845"
AERGO_PRIVATE_KEY = "6huq98qotz8rj3uEx99JxYrpQesLN7P1dA14NtcR1NLvD7BdumN"
AERGO_WAITING_TIME = 3
aergo = None

HSC_META = 'hsc_meta.lua'
HSC_ADDRESS = "AmgJbPveoVC1usCZEXyM9tQ1WsFPx6bixmfbeedBAZM8P2LhQyxh"

DEPLOY_HSC_JSON = 'hsc.payload.dat'


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


def query_sc(func_name, args=None, hsc_address=HSC_ADDRESS):
    # send TX
    result = aergo.query_sc(hsc_address, func_name, args=args)
    print(result)
    return result


def insert_cmd_create_pond():
    # read deploy json
    if os.path.isfile(DEPLOY_HSC_JSON):
        with open(DEPLOY_HSC_JSON) as f:
            deployed_info = json.load(f)
            f.close()
    else:
        eprint("Cannot find HSC Address, deploy first.")
        exit()

    hsc_address = deployed_info[HSC_META]['address']
    if hsc_address != HSC_ADDRESS:
        eprint("HSC Address is changed:", hsc_address)
        eprint("Find out why!!!!!!!!!!")
        exit()

    command = "cmd-" + str(time.time())

    """
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
    """

    # test: register Horde
    info = {
        "hm_id": "AmLaSifmhjHnys8baftuWRiXi8HEJTbthQRPxYrcXEVeZuXviZug",
        "cnode_list": [
            {
                "cnode_id": "AmLaSif_cnode_A",
                "container_list": []
            },
            {
                "cnode_id": "AmLaSif_cnode_B",
            },
        ]
    }
    info = json.dumps(info)
    call_sc("registerHordeMaster", ["AmLaSifmhjHnys8baftuWRiXi8HEJTbthQRPxYrcXEVeZuXviZug", info])

    # test: query all Horde info
    result = query_sc("queryAllHordeMaster")
    result = json.loads(result)
    print("\n-----------------------")
    print("All Info for '{}' Hordes".format(len(result)))
    print("------------------------")
    print(json.dumps(result, indent=2))

    return

    """
    info = {
        "hm_id": "AmLaSifmhjHnys8baftuWRiXi8HEJTbthQRPxYrcXEVeZuXviZug",
        "cnode_list": [
            {
                "cnode_id": "AmLa_cnode_1",
                "container_list": [
                    {"container_id": "AmLa_cnode_1_container_1"},
                    {"container_id": "AmLa_cnode_1_container_2"},
                    {"container_id": "AmLa_cnode_1_container_3"},
                ]
            },
            {
                "cnode_id": "AmLa_cnode_2",
                "container_list": [
                    {"container_id": "AmLa_cnode_2_container_1"},
                    {"container_id": "AmLa_cnode_2_container_2"},
                    {"container_id": "AmLa_cnode_2_container_3"},
                ]
            },
            {
                "cnode_id": "AmLa_cnode_3",
                "container_list": [
                    {"container_id": "AmLa_cnode_3_container_1"},
                    {"container_id": "AmLa_cnode_3_container_2"},
                    {"container_id": "AmLa_cnode_3_container_3"},
                ]
            },
        ]
    }
    """
    info = {
        "hm_id": "AmLaSifmhjHnys8baftuWRiXi8HEJTbthQRPxYrcXEVeZuXviZug",
        "cnode_list": [
            {
                "cnode_id": "AmLa_cnode_1",
                "container_list": [
                    {"container_id": "AmLa_cnode_1_container_a"},
                    {"container_id": "AmLa_cnode_1_container_b"},
                    {"container_id": "AmLa_cnode_1_container_c"},
                ]
            },
            {
                "cnode_id": "AmLa_cnode_2",
                "container_list": [
                    {"container_id": "AmLa_cnode_2_container_a"},
                    {"container_id": "AmLa_cnode_2_container_b"},
                    {"container_id": "AmLa_cnode_2_container_c"},
                ]
            },
            {
                "cnode_id": "AmLa_cnode_3",
                "container_list": [
                    {"container_id": "AmLa_cnode_3_container_a"},
                    {"container_id": "AmLa_cnode_3_container_b"},
                    {"container_id": "AmLa_cnode_3_container_c"},
                ]
            },
        ]
    }
    info = json.dumps(info)
    call_sc("registerHordeMaster", ["AmLaSifmhjHnys8baftuWRiXi8HEJTbthQRPxYrcXEVeZuXviZug", info])
    # >> fail: "ERROR: cannot register Horde with a different ID." on aergo log
    call_sc("registerHordeMaster", ["AmQNRjb6rtqc6Jc5tsaTupQPAHXaD2EvDcBehyysw8Wbhp1oW1a9", info])

    info = {
        "hm_id": "AmQNRjb6rtqc6Jc5tsaTupQPAHXaD2EvDcBehyysw8Wbhp1oW1a9",
        "cnode_list": [
            {
                "cnode_id": "AmQN_cnode_1",
                "container_list": [
                    {"container_id": "AmQN_cnode_1_container_1"},
                    {"container_id": "AmQN_cnode_1_container_2"},
                    {"container_id": "AmQN_cnode_1_container_3"},
                ]
            },
            {
                "cnode_id": "AmQN_cnode_2",
                "container_list": [
                    {"container_id": "AmQN_cnode_2_container_1"},
                    {"container_id": "AmQN_cnode_2_container_2"},
                    {"container_id": "AmQN_cnode_2_container_3"},
                ]
            },
            {
                "cnode_id": "AmQN_cnode_3",
                "container_list": [
                    {"container_id": "AmQN_cnode_3_container_1"},
                    {"container_id": "AmQN_cnode_3_container_2"},
                    {"container_id": "AmQN_cnode_3_container_3"},
                ]
            },
        ]
    }
    info = json.dumps(info)
    call_sc("registerHordeMaster", ["AmQNRjb6rtqc6Jc5tsaTupQPAHXaD2EvDcBehyysw8Wbhp1oW1a9", info])

    # test: query Horde info
    result = query_sc("queryHordeMaster", "AmLaSifmhjHnys8baftuWRiXi8HEJTbthQRPxYrcXEVeZuXviZug")
    result = json.loads(result)
    print("\n--------------------------------")
    print("'{0}' CNodes Info for Horde: \n{1}".format(len(result['cnode_list']), result['hm_id']))
    print("--------------------------------")
    print(json.dumps(result, indent=2))

    # test: query Horde info
    result = query_sc("queryHordeMaster", "AmQNRjb6rtqc6Jc5tsaTupQPAHXaD2EvDcBehyysw8Wbhp1oW1a9")
    result = json.loads(result)
    print("\n--------------------------------")
    print("'{0}' CNodes Info for Horde: \n{1}".format(len(result['cnode_list']), result['hm_id']))
    print("--------------------------------")
    print(json.dumps(result, indent=2))

    # test: query all Horde info
    result = query_sc("queryAllHordeMaster")
    result = json.loads(result)
    print("\n-----------------------")
    print("All Info for '{}' Hordes".format(len(result)))
    print("------------------------")
    print(json.dumps(result, indent=2))


def insert_pond():
    rand_str = str(time.time())
    pond_id = "pond_id #" + rand_str

    print("Sender =", str(aergo.account.address))

    metadata = {
        "pond_name": "test pond name: {}".format(rand_str),
        "field #1": "AAAA",
    }
    metadata = json.dumps(metadata)
    call_sc("insertPond", [pond_id, "cmd_id #1", metadata])

    result = query_sc("queryPonds", [str(aergo.account.address), pond_id])
    result = json.loads(result)
    print("\n--------------------------------")
    print("'{0}' Pond Info:".format(pond_id))
    print(json.dumps(result, indent=2))
    print("--------------------------------")

    result = query_sc("queryPonds", [str(aergo.account.address)])
    result = json.loads(result)
    print("\n--------------------------------")
    print("All Ponds:")
    print(json.dumps(result, indent=2))
    print("--------------------------------")


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

    #insert_cmd_create_pond()
    insert_pond()


if __name__ == '__main__':
    try:
        main()
        exit(False)
    except Exception:
        traceback.print_exception(*sys.exc_info())
        exit()

