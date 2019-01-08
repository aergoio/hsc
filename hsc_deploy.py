import os
import sys
import click
import traceback
import json
import aergo.herapy as herapy
import time

HSC_VERSION="v0.1.1"

AERGO_TARGET = "testnet.aergo.io:7845"
AERGO_PRIVATE_KEY = "6huq98qotz8rj3uEx99JxYrpQesLN7P1dA14NtcR1NLvD7BdumN"
AERGO_WAITING_TIME = 3

if 'AERGO_TARGET' in os.environ:
    AERGO_TARGET = os.environ['AERGO_TARGET']

if 'AERGO_WAITING_TIME' in os.environ:
    AERGO_WAITING_TIME = os.environ['AERGO_WAITING_TIME']

HSC_META = 'hsc_meta.lua'
HSC_DB = 'hsc_db.lua'
HSC_CMD = 'hsc_cmd.lua'
HSC_RESULT = 'hsc_result.lua'
HSC_CONFIG = 'hsc_config.lua'
HSC_POND = 'hsc_pond.lua'

HSC_SRC_LIST = [
    HSC_META,
    HSC_DB,
    HSC_CMD,
    HSC_RESULT,
    HSC_CONFIG,
    HSC_POND,
]

HSC_PAYLOAD_DATA = "./hsc.payload.dat"


def exit(error=True):
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


def check_aergo_conn_info(target, private_key):
    aergo = herapy.Aergo()
    aergo.connect(target)
    aergo.new_account(private_key=private_key)

    if private_key is None:
        print("Account:")
        print("  Private Key: " + str(aergo.account.private_key))
        print("  Address: " + str(aergo.account.address))

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


def query_sc(aergo, hsc_address, func_name, args=None):
    # send TX
    result = aergo.query_sc(hsc_address, func_name, args=args)
    return result


def try_to_deploy(aergo, key, payload_info, args=None, force=False):
    if key not in payload_info:
        return False

    if not force:
        if payload_info[key]['deployed'] and not payload_info[key]['compiled']:
            return False

    address = deploy_sc(aergo, payload_info[key]['payload'], args)
    payload_info[key]['address'] = address

    return True


def hsc_deploy(aergo, payload_info):
    print("Deploying Horde Smart Contract (HSC)")

    if payload_info is None or 'hsc_address' not in payload_info:
        hsc_address = None
    else:
        hsc_address = payload_info['hsc_address']

    # at first check whether HSC is deployed or not
    try:
        version = query_sc(aergo, hsc_address, "getVersion")
        version = version.decode('utf-8')
        if HSC_VERSION in version:
            print("HSC is already deployed (Version: {})".format(version))
            need_to_change_all = False
        else:
            print("Version is different: (expect) \"{0}\" != (deployed) {1}".format(HSC_VERSION, version))
            need_to_change_all = True
    except:
        need_to_change_all = True

    # always check HSC_META
    if need_to_change_all:
        try_to_deploy(aergo, HSC_META, payload_info, force=need_to_change_all)
        print("  > deployed ...", HSC_META)
    else:
        if try_to_deploy(aergo, HSC_META, payload_info):
            need_to_change_all = True
            print("  > deployed ...", HSC_META)
        else:
            need_to_change_all = False
            print("  > ............", HSC_META)
    payload_info[HSC_META]['compiled'] = False
    payload_info[HSC_META]['deployed'] = True

    hsc_address = payload_info[HSC_META]['address']

    # always check HSC_DB
    if need_to_change_all:
        try_to_deploy(aergo, HSC_DB, payload_info, hsc_address, force=need_to_change_all)
        print("  > deployed ...", HSC_DB)
    else:
        if try_to_deploy(aergo, HSC_DB, payload_info, hsc_address):
            need_to_change_all = True
            print("  > deployed ...", HSC_DB)
        else:
            need_to_change_all = False
            print("  > ............", HSC_DB)
    payload_info[HSC_DB]['compiled'] = False
    payload_info[HSC_DB]['deployed'] = True

    # check other sources
    for key in HSC_SRC_LIST:
        if key == HSC_META or key == HSC_DB:
            continue

        if try_to_deploy(aergo, key, payload_info, hsc_address, force=need_to_change_all):
            print("  > deployed ...", key)
            payload_info[key]['compiled'] = False
            payload_info[key]['deployed'] = True
        else:
            if key not in payload_info:
                print("  > ERROR ......", key)
                continue
            else:
                print("  > ............", key)
                payload_info[key]['compiled'] = False
                payload_info[key]['deployed'] = True

    # set HSC version
    call_sc(aergo, hsc_address, "setVersion", [HSC_VERSION])

    # creating Horde tables
    call_sc(aergo, hsc_address, "createHordeTables")

    print()
    print("Horde Smart Contract Address =", hsc_address)

    payload_info['hsc_address'] = hsc_address

    print("Prepared Horde Smart Contract")
    return hsc_address


@click.group(invoke_without_command=True)
@click.option('--target', default=AERGO_TARGET, help='target AERGO for Horde configuration')
@click.option('--private-key', help='the private key to create Horde Smart Contract. If not set, it will be random')
@click.option('--waiting-time', default=AERGO_WAITING_TIME, help='the private key to create Horde Smart Contract')
def main(target, private_key, waiting_time):
    global AERGO_WAITING_TIME
    AERGO_WAITING_TIME = waiting_time

    try:
        aergo = check_aergo_conn_info(target, private_key)
        aergo.get_account()
        print("  > Account Info")
        print('    - Nonce:        %s' % aergo.account.nonce)
        print('    - balance:      %s' % aergo.account.balance.aergo)

        if target == AERGO_TARGET and int(aergo.account.balance) == 0:
            print("Not enough balance.\n")
            print("You need to request AERGO tokens on\n\n  https://faucet.aergoscan.io/\n")
            print("with the address:")
            print("\n  %s\n" % aergo.account.address)
            print("And deploy again with the private key:")
            print("\n  python {0} --private-key {1}\n".format(sys.argv[0], aergo.account.private_key))
            exit()

        # read payload info.
        payload_info = read_payload_info()

        hsc_address = hsc_deploy(aergo, payload_info)

        # save payload info.
        write_payload_info(payload_info)

        exit(False)
    except Exception:
        traceback.print_exception(*sys.exc_info())
        exit()


if __name__ == '__main__':
    main(obj={})
