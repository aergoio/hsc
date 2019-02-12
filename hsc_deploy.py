import os
import sys
import click
import traceback
import json
import aergo.herapy as herapy
import time

AERGO_TESTNET = "testnet.aergo.io:7845"

#AERGO_TARGET = "localhost:7845"
AERGO_TARGET = AERGO_TESTNET
AERGO_PRIVATE_KEY = "6huq98qotz8rj3uEx99JxYrpQesLN7P1dA14NtcR1NLvD7BdumN"
AERGO_WAITING_TIME = 3

if 'AERGO_TARGET' in os.environ:
    AERGO_TARGET = os.environ['AERGO_TARGET']

if 'AERGO_WAITING_TIME' in os.environ:
    AERGO_WAITING_TIME = os.environ['AERGO_WAITING_TIME']

HSC_COMPILED_PAYLOAD_DATA_FILE = "./hsc.compiled.payload.dat"
HSC_DEPLOYED_PAYLOAD_DATA_FILE = "./hsc.deployed.payload.dat"

_MANIFEST = '_manifest.lua'
QUIET_MODE = False


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


def out_print(*args, **kwargs):
    if not QUIET_MODE:
        print(*args, **kwargs)


def err_print(*args, **kwargs):
    if not QUIET_MODE:
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
        out_print("Account:")
        out_print("  Private Key: " + str(aergo.account.private_key))
        out_print("  Address: " + str(aergo.account.address))

    return aergo


def deploy_sc(aergo, payload, args=None):
    # send TX
    tx, result = aergo.deploy_sc(payload=payload, args=args)
    if result.status != herapy.CommitStatus.TX_OK:
        raise RuntimeError("[{0}]: {1}".format(result.status, result.detail))

    time.sleep(int(AERGO_WAITING_TIME))

    # check TX
    result = aergo.get_tx_result(tx.tx_hash)
    if result.status != herapy.SmartcontractStatus.CREATED:
        raise RuntimeError("[{0}]:{1}: {2}".format(result.contract_address, result.status, result.detail))

    return result.contract_address


def call_sc(aergo, hsc_address, func_name, args=None):
    # send TX
    tx, result = aergo.call_sc(hsc_address, func_name, args=args)
    if result.status != herapy.CommitStatus.TX_OK:
        raise RuntimeError("[{0}]: {1}".format(result.status, result.detail))

    time.sleep(int(AERGO_WAITING_TIME))

    # check TX
    result = aergo.get_tx_result(tx.tx_hash)
    if result.status != herapy.SmartcontractStatus.SUCCESS:
        err_print(result)
        raise RuntimeError("[{0}]:{1}: {2}".format(result.contract_address, result.status, result.detail))

    return result


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
    # read compiled payload info.
    compiled_info = read_payload_info(compiled_payload_file_path)

    # read deployed payload info.
    deployed_info = read_payload_info(deployed_payload_file_path)
    copy_deployed_info = deployed_info.copy()
    for k in copy_deployed_info:
        if 'hsc_address' == k:
            continue
        if k not in compiled_info:
            deployed_info.pop(k)

    # at first check whether HSC is deployed or not
    version_is_same = False
    try:
        if compiled_info['hsc_version'] != deployed_info['hsc_version']:
            need_to_change_all = True
        else:
            hsc_address = deployed_info['hsc_address']

            # read the version of deployed HSC
            version = query_sc(aergo, hsc_address, "getVersion")
            version = version.decode('utf-8')

            if compiled_info['hsc_version'] in version:
                out_print("HSC is already deployed (Version: {})".format(version))
                need_to_change_all = False
                version_is_same = True
            else:
                out_print("Version is different: (expect) \"{0}\" != (deployed) {1}".format(compiled_info['hsc_version'],
                                                                                        version))
                need_to_change_all = True
    except:
        need_to_change_all = True

    deployed_info['hsc_version'] = compiled_info['hsc_version']

    out_print("Deploying Manifest")

    # at first always check _MANIFEST
    for k, v in compiled_info.items():
        if k == _MANIFEST:
            if try_to_deploy(aergo=aergo, key=k, payload=v['payload'],
                             deployed_info=deployed_info,
                             force=need_to_change_all):
                need_to_change_all = True
                out_print("  > deployed ...", k)
            else:
                need_to_change_all = False
                out_print("  > ............", k)
            break

    hsc_address = deployed_info[_MANIFEST]['address']

    # check other manifest modules
    for k, v in compiled_info.items():
        if k == 'hsc_version' or k == _MANIFEST:
            continue

        if v['is_manifest']:
            if try_to_deploy(aergo=aergo, key=k, payload=v['payload'],
                             deployed_info=deployed_info,
                             args=hsc_address,
                             force=need_to_change_all):
                need_to_change_all = True
                out_print("  > deployed ...", k)
            else:
                need_to_change_all = False
                out_print("  > ............", k)

    out_print('')
    out_print("Deploying Horde Smart Contract (HSC)")

    # check other sources
    for k, v in compiled_info.items():
        if k == 'hsc_version' or v['is_manifest']:
            continue

        if try_to_deploy(aergo=aergo, key=k, payload=v['payload'],
                         deployed_info=deployed_info,
                         args=hsc_address,
                         force=need_to_change_all):
            out_print("  > deployed ...", k)
        else:
            out_print("  > ............", k)

    # set HSC version
    if not version_is_same:
        call_sc(aergo, hsc_address, "setVersion", [deployed_info['hsc_version']])

    out_print()
    out_print("Horde Smart Contract Address =", hsc_address)

    deployed_info['hsc_address'] = hsc_address

    # save payload info.
    write_payload_info(payload_info=deployed_info, payload_path=deployed_payload_file_path)

    out_print("Prepared Horde Smart Contract")
    return hsc_address


@click.group(invoke_without_command=True)
@click.option('--target', default=AERGO_TARGET, help='target AERGO for Horde configuration')
@click.option('--private-key', help='the private key to create Horde Smart Contract. If not set, it will be random')
@click.option('--waiting-time', default=AERGO_WAITING_TIME, help='the private key to create Horde Smart Contract')
def main(target, private_key, waiting_time):
    global AERGO_WAITING_TIME
    AERGO_WAITING_TIME = waiting_time

    aergo = None
    try:
        aergo = check_aergo_conn_info(target, private_key)
        aergo.get_account()
        out_print("  > Account Info")
        out_print('    - Nonce:        %s' % aergo.account.nonce)
        out_print('    - balance:      %s' % aergo.account.balance.aergo)

        if target == AERGO_TESTNET and int(aergo.account.balance) == 0:
            out_print("Not enough balance.\n")
            out_print("You need to request AERGO tokens on\n\n  https://faucet.aergoscan.io/\n")
            out_print("with the address:")
            out_print("\n  %s\n" % aergo.account.address)
            out_print("And deploy again with the private key:")
            out_print("\n  python {0} --private-key {1}\n".format(sys.argv[0], aergo.account.private_key))
            exit(False)

        hsc_address = hsc_deploy(aergo=aergo,
                                 compiled_payload_file_path=HSC_COMPILED_PAYLOAD_DATA_FILE,
                                 deployed_payload_file_path=HSC_DEPLOYED_PAYLOAD_DATA_FILE)
        out_print("Deployed HSC Address: {}".format(hsc_address))

        exit(False)
    except Exception as e:
        err_print(e)
        if not QUIET_MODE:
            traceback.print_exception(*sys.exc_info())
        exit()
    finally:
        if aergo is not None:
            aergo.disconnect()


if __name__ == '__main__':
    main(obj={})
