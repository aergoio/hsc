import os
import sys
import click
import traceback
import json
import aergo.herapy as herapy
import time

AERGO_TARGET = "localhost:7845"
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

HSC_COMPILED_PAYLOAD_DATA_FILE = "./hsc.compiled.payload.dat"
HSC_DEPLOYED_PAYLOAD_DATA_FILE = "./hsc.deployed.payload.dat"


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


def read_payload_info(payload_path):
    # read previous information
    if os.path.isfile(payload_path):
        with open(payload_path) as f:
            payload_info = json.load(f)
            f.close()
    else:
        payload_info = {}
    return payload_info


def write_payload_info(payload_info, payload_path):
    # store deploy json
    with open(payload_path, "w") as f:
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


def try_to_deploy(aergo, key, payload, deployed_info, args=None, force=False):
    if key not in deployed_info:
        deployed_info[key] = {}

    if 'payload' in deployed_info[key] and not force:
        if payload == deployed_info[key]['payload']:
            # don't need to deploy
            return False

    address = deploy_sc(aergo, payload, args)
    deployed_info[key]['address'] = address

    deployed_info[key]['payload'] = payload

    return True


def hsc_deploy(aergo, compiled_payload_file_path, deployed_payload_file_path):
    print("Deploying Horde Smart Contract (HSC)")

    # read compiled payload info.
    compiled_info = read_payload_info(compiled_payload_file_path)

    # read deployed payload info.
    deployed_info = read_payload_info(deployed_payload_file_path)

    # at first check whether HSC is deployed or not
    try:
        if compiled_info['hsc_version'] != deployed_info['hsc_version']:
            need_to_change_all = True
        else:
            hsc_address = deployed_info['hsc_address']

            # read the version of deployed HSC
            version = query_sc(aergo, hsc_address, "getVersion")
            version = version.decode('utf-8')

            if compiled_info['hsc_version'] in version:
                print("HSC is already deployed (Version: {})".format(version))
                need_to_change_all = False
            else:
                print("Version is different: (expect) \"{0}\" != (deployed) {1}".format(compiled_info['hsc_version'],
                                                                                        version))
                need_to_change_all = True
    except:
        need_to_change_all = True

    deployed_info['hsc_version'] = compiled_info['hsc_version']

    # always check HSC_META
    if try_to_deploy(aergo=aergo, key=HSC_META,
                     payload=compiled_info[HSC_META]['payload'],
                     deployed_info=deployed_info,
                     force=need_to_change_all):
        need_to_change_all = True
        print("  > deployed ...", HSC_META)
    else:
        need_to_change_all = False
        print("  > ............", HSC_META)

    hsc_address = deployed_info[HSC_META]['address']

    # always check HSC_DB
    if try_to_deploy(aergo=aergo, key=HSC_DB,
                     payload=compiled_info[HSC_DB]['payload'],
                     deployed_info=deployed_info,
                     args=hsc_address,
                     force=need_to_change_all):
        need_to_change_all = True
        print("  > deployed ...", HSC_DB)
    else:
        need_to_change_all = False
        print("  > ............", HSC_DB)

    # check other sources
    for key in HSC_SRC_LIST:
        if key == HSC_META or key == HSC_DB:
            continue

        if try_to_deploy(aergo=aergo, key=key,
                         payload=compiled_info[key]['payload'],
                         deployed_info=deployed_info,
                         args=hsc_address,
                         force=need_to_change_all):
            need_to_change_all = True
            print("  > deployed ...", key)
        else:
            need_to_change_all = False
            print("  > ............", key)

    # set HSC version
    call_sc(aergo, hsc_address, "setVersion", [deployed_info['hsc_version']])

    print()
    print("Horde Smart Contract Address =", hsc_address)

    deployed_info['hsc_address'] = hsc_address

    # save payload info.
    write_payload_info(payload_info=deployed_info, payload_path=deployed_payload_file_path)

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

        hsc_address = hsc_deploy(aergo=aergo,
                                 compiled_payload_file_path=HSC_COMPILED_PAYLOAD_DATA_FILE,
                                 deployed_payload_file_path=HSC_DEPLOYED_PAYLOAD_DATA_FILE)
        print("Deployed HSC Address: {}".format(hsc_address))

        exit(False)
    except Exception:
        traceback.print_exception(*sys.exc_info())
        exit()


if __name__ == '__main__':
    main(obj={})
