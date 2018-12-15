import os
import sys
import traceback
import json
import aergo.herapy as herapy
import time

AERGO_TARGET = "localhost:7845"
AERGO_PRIVATE_KEY = "6huq98qotz8rj3uEx99JxYrpQesLN7P1dA14NtcR1NLvD7BdumN"
AERGO_ACCOUNT_PASSWORD = "coolguy"
AERGO_WAITING_TIME = 3

if 'AERGO_TARGET' in os.environ:
    AERGO_TARGET = os.environ['AERGO_TARGET']

if 'AERGO_PRIVATE_KEY' in os.environ:
    AERGO_PRIVATE_KEY = os.environ['AERGO_PRIVATE_KEY']

if 'AERGO_ACCOUNT_PASSWORD' in os.environ:
    AERGO_ACCOUNT_PASSWORD = os.environ['AERGO_ACCOUNT_PASSWORD']

if 'AERGO_WAITING_TIME' in os.environ:
    AERGO_WAITING_TIME = os.environ['AERGO_WAITING_TIME']

HSC_META = 'hsc_meta.lua'
HSC_MAIN = 'hsc_main.lua'
HSC_DB = 'hsc_db.lua'
HSC_CMD = 'hsc_cmd.lua'
HSC_RESULT = 'hsc_result.lua'
HSC_CONFIG = 'hsc_config.lua'

HSC_SRC_LIST = [
    HSC_META,
    HSC_MAIN,
    HSC_DB,
    HSC_CMD,
    HSC_RESULT,
    HSC_CONFIG,
]

HSC_PAYLOAD_DATA = "./hsc.payload.dat"


def exit(error=True):
    if aergo is not None:
        aergo.disconnect()

    """
    if error:
        try:
            os.remove(HSC_PAYLOAD_DATA)
        except FileNotFoundError:
            pass
        sys.exit(1)
    """

    sys.exit(0)


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


def read_payload_info():
    # read previous information
    if os.path.isfile(HSC_PAYLOAD_DATA):
        with open(HSC_PAYLOAD_DATA) as f:
            payload_info = json.load(f)
            f.close()
    else:
        payload_info = {}
    return payload_info


def write_payload_info(payload_info):
    # store deploy json
    with open(HSC_PAYLOAD_DATA, "w") as f:
        f.write(json.dumps(payload_info, indent=2))
        f.close()


def check_aergo_conn_info(target, private_key, password):
    aergo = herapy.Aergo()
    aergo.connect(target)
    aergo.new_account(password=password, private_key=private_key)
    return aergo


def deploy_sc(aergo, payload, args=None):
    # send TX
    tx, result = aergo.deploy_sc(payload=payload, args=args)
    if result.status != herapy.CommitStatus.TX_OK:
        eprint("ERROR[{0}]: {1}".format(result.status, result.detail))
        aergo.disconnect()
        exit()

    time.sleep(int(AERGO_WAITING_TIME))

    # check TX
    result = aergo.get_tx_result(tx.tx_hash)
    if result.status != herapy.SmartcontractStatus.CREATED:
        eprint("ERROR[{0}]:{1}: {2}".format(result.contract_address, result.status, result.detail))
        aergo.disconnect()
        exit()

    return result.contract_address


def call_sc(aergo, hsc_address, func_name, args=None):
    # send TX
    tx, result = aergo.call_sc(hsc_address, func_name, args=args)
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


def try_to_deploy(aergo, key, payload_info, args=None, force=False):
    if key not in payload_info:
        return False

    if not force:
        if payload_info[key]['deployed'] and not payload_info[key]['changed']:
            return False

    address = deploy_sc(aergo, payload_info[key]['payload'], args)
    payload_info[key]['address'] = address

    return True


def hsc_deploy(aergo, payload_info):
    print("Compiling Horde Smart Contract (HSC)")

    # at first always check HSC_META
    if try_to_deploy(aergo, HSC_META, payload_info):
        need_to_change_all = True
        print("  > deployed ...", HSC_META)
    else:
        need_to_change_all = False
        print("  > ............", HSC_META)
    payload_info[HSC_META]['changed'] = False
    payload_info[HSC_META]['deployed'] = True

    hsc_address = payload_info[HSC_META]['address']

    # check other sources
    for key in HSC_SRC_LIST:
        if key == HSC_META:
            continue

        if try_to_deploy(aergo, key, payload_info, hsc_address, need_to_change_all):
            print("  > deployed ...", key)
            payload_info[key]['changed'] = False
            payload_info[key]['deployed'] = True
        else:
            if key not in payload_info:
                print("  > ERROR ......", key)
                continue
            else:
                print("  > ............", key)
                payload_info[key]['changed'] = False
                payload_info[key]['deployed'] = True

    print()
    print("Horde Smart Contract Address =", hsc_address)

    payload_info['hsc_address'] = hsc_address

    print("Prepared Horde Smart Contract")
    return hsc_address


if __name__ == '__main__':
    try:
        aergo = check_aergo_conn_info(AERGO_TARGET, AERGO_PRIVATE_KEY, AERGO_ACCOUNT_PASSWORD)

        # read payload info.
        payload_info = read_payload_info()

        hsc_address = hsc_deploy(aergo, payload_info)

        # save payload info.
        write_payload_info(payload_info)

        # create Horde tables
        call_sc(aergo, hsc_address, "createHordeTables")

        exit(False)
    except Exception:
        traceback.print_exception(*sys.exc_info())
        exit()
