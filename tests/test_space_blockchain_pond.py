import pytest

import json

import hsc_compile
import hsc_deploy

aergo = None
hsc_address = None

def call_function(func_name, args):
    return hsc_deploy.call_sc(aergo, hsc_address, 'callFunction',
                              ['__HSC_SPACE_BLOCKCHAIN__', func_name] + args)

def query_function(func_name, args):
    return hsc_deploy.query_sc(aergo, hsc_address, 'callFunction',
                               ['__HSC_SPACE_BLOCKCHAIN__', func_name] + args)

@pytest.fixture(scope='session')
def setup():
    hsc_compile.QUIET_MODE = True
    hsc_compile.hsc_compile()

    hsc_deploy.QUIET_MODE = False
    global aergo
    aergo = hsc_deploy.check_aergo_conn_info(target=hsc_deploy.AERGO_TARGET,
                                             private_key=hsc_deploy.AERGO_PRIVATE_KEY)
    global hsc_address
    hsc_address = hsc_deploy.hsc_deploy(aergo=aergo,
                                        compiled_payload_file_path=hsc_deploy.HSC_COMPILED_PAYLOAD_DATA_FILE,
                                        deployed_payload_file_path=hsc_deploy.HSC_DEPLOYED_PAYLOAD_DATA_FILE)
    print('HSC Address:', hsc_address)


def test_create_pond(setup):
    print("test_create_pond:", hsc_address)
    metadata = {
        "name": "wonderland",
        "who create it?": "YP",
        "what for?": "just for HSC test",
    }
    response = call_function('createPond', ['wonderland1', 'wonderland', True, json.dumps(metadata)])
    return_value = json.loads(response.detail)
    print("Return of 'createPond':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 2 == int(status_code / 100)

    response = query_function('getPond', ['wonderland1'])
    return_value = json.loads(response)
    print("Return of 'getPond':\n{}".format(json.dumps(return_value, indent=2)))


def test_update_pond(setup):
    print("test_update_pond:", hsc_address)
    metadata = {
        "I will make bnodes below": [
            "red-queen",
            "cheshire-cat",
            "caterpillar",
            "tweedledee",
            "alice",
            "mad-hatter",
            "tweedledum",
            "white-rabbit",
        ],
    }
    response = call_function('updatePond', ['wonderland1', 'wonderland', True, json.dumps(metadata)])
    return_value = json.loads(response.detail)
    print("Return of 'updatePond':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 2 == int(status_code / 100)

    response = query_function('getPond', ['wonderland1'])
    return_value = json.loads(response)
    print("Return of 'getPond':\n{}".format(json.dumps(return_value, indent=2)))


def test_create_bnode(setup):
    print("test_create_bnode:", hsc_address)

    bnode1_metadata = {
        "id": "bnode1",
        "name": "red-queen",
        "ip": "localhost",
        "port": {
            "rpc": 7845,
            "p2p": 7846,
            "rest": 8080,
            "profile": 6060,
        },
    }
    response = call_function('createBNode', ['wonderland1', 'bnode1', 'red-queen', json.dumps(bnode1_metadata)])
    return_value = json.loads(response.detail)
    print("Return of 'createBNode':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 2 == int(status_code / 100)

    response = query_function('getBNode', ['wonderland1', 'bnode1'])
    return_value = json.loads(response)
    print("Return of 'getBNode':\n{}".format(json.dumps(return_value, indent=2)))

    bnode2_metadata = {
        "id": "bnode2",
        "name": "chashire-cat",
        "ip": "127.0.0.1",
        "port": {
            "rpc": 17845,
            "p2p": 17846,
            "rest": 18080,
            "profile": 16060,
        },
    }
    response = call_function('createBNode', ['wonderland1', 'bnode2', 'chashire-cat', json.dumps(bnode2_metadata)])
    return_value = json.loads(response.detail)
    print("Return of 'createBNode':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 2 == int(status_code / 100)

    response = query_function('getBNode', ['wonderland1', 'bnode2'])
    return_value = json.loads(response)
    print("Return of 'getBNode':\n{}".format(json.dumps(return_value, indent=2)))

    response = query_function('getAllBNodes', ['wonderland1'])
    return_value = json.loads(response)
    print("Return of 'getAllBNodes':\n{}".format(json.dumps(return_value, indent=2)))


def test_delete_pond(setup):
    print("test_delete_pond:", hsc_address)

    response = call_function('deletePond', ['wonderland1'])
    return_value = json.loads(response.detail)
    print("Return of 'deletePond':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 2 == int(status_code / 100)

    response = query_function('getPond', ['wonderland1'])
    return_value = json.loads(response)
    print("Return of 'getPond':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 404 == status_code

    response = query_function('getAllBNodes', ['wonderland1'])
    return_value = json.loads(response)
    print("Return of 'getBNode':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 404 == status_code
