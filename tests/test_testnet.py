import pytest

import json

import hsc_compile
import hsc_deploy


aergo = None

hsc_address = "AmgUPYeR2w8Hrh4pauwDRzykGUjvRTNEoH65S6xXawoy3CAZrEda"
pond_creator = "AmLaWMFr8jpJqLVwGrEnsX62mKEm62ztjSsAmB2APL3Z9qeGyk1s"


def call_function(func_name, args):
    return hsc_deploy.call_sc(aergo, hsc_address, 'callFunction',
                              ['__HSC_SPACE_BLOCKCHAIN__', func_name] + args)

def query_function(func_name, args):
    return hsc_deploy.query_sc(aergo, hsc_address, 'callFunction',
                               ['__HSC_SPACE_BLOCKCHAIN__', func_name] + args)

@pytest.fixture(scope='session')
def setup():
    global aergo
    aergo = hsc_deploy.check_aergo_conn_info(target=hsc_deploy.AERGO_TESTNET,
                                             private_key=hsc_deploy.AERGO_PRIVATE_KEY)
    print('HSC Address:', hsc_address)


def test_get_all_ponds(setup):
    print("sender:", str(aergo.account.address))
    print("test_get_all_ponds:", hsc_address)

    response = query_function('getAllPonds', [pond_creator])
    return_value = json.loads(response)
    print("Return of 'getAllPonds':\n{}".format(json.dumps(return_value, indent=2)))
