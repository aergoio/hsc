import pytest

import json

import hsc_compile
import hsc_deploy

aergo = None
hsc_address = None

def call_function(func_name, args):
    return hsc_deploy.call_sc(aergo, hsc_address, 'callFunction',
                              ['__HSC_SPACE_COMPUTING__', func_name] + args)

def query_function(func_name, args):
    return hsc_deploy.query_sc(aergo, hsc_address, 'callFunction',
                               ['__HSC_SPACE_COMPUTING__', func_name] + args)

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


def test_add_horde(setup):
    print("test_add_horde:", hsc_address)
    metadata = {
        "name": "Ogrima",
        "who create it?": "YP",
        "what for?": "just for HSC test",
    }
    response = call_function('addHorde', ['ogrima1', 'Ogrima', True, json.dumps(metadata)])
    return_value = json.loads(response.detail)
    print("Return of 'addHorde':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getHorde', ['ogrima1'])
    return_value = json.loads(response)
    print("Return of 'getHorde':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code
    assert metadata['name'] == return_value['horde_metadata']['name']
    assert metadata['who create it?'] == return_value['horde_metadata']['who create it?']
    assert metadata['what for?'] == return_value['horde_metadata']['what for?']


def test_update_horde(setup):
    print("test_update_horde:", hsc_address)
    metadata = {
        "I will register CNodes below": [
            "bbabam",
            "zzazan",
        ],
    }
    metadata_raw = json.dumps(metadata)
    response = call_function('updateHorde', ['ogrima1', 'Thunder Bluff', True, metadata_raw])
    return_value = json.loads(response.detail)
    print("Return of 'updateHorde':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getHorde', ['ogrima1'])
    return_value = json.loads(response)
    print("Return of 'getHorde':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code
    assert metadata['I will register CNodes below'][0] == return_value['horde_metadata']['I will register CNodes below'][0]
    assert metadata['I will register CNodes below'][1] == return_value['horde_metadata']['I will register CNodes below'][1]


def test_create_cnode(setup):
    print("test_create_cnode:", hsc_address)

    cnode1_metadata = {
        "id": "cnode1",
        "name": "bbabam",
        "ip": "localhost",
        "port": {
            "rpc": 7845,
            "p2p": 7846,
            "rest": 8080,
            "profile": 6060,
        },
    }
    cnode1_metadata_raw = json.dumps(cnode1_metadata)
    response = call_function('addCNode', ['ogrima1', 'cnode1', 'bbabam', cnode1_metadata_raw])
    return_value = json.loads(response.detail)
    print("Return of 'addCNode':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getCNode', ['ogrima1', 'cnode1'])
    return_value = json.loads(response)
    print("Return of 'getCNode':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code
    assert cnode1_metadata['id'] == return_value['cnode_list'][0]['cnode_metadata']['id']
    assert cnode1_metadata['name'] == return_value['cnode_list'][0]['cnode_metadata']['name']
    assert cnode1_metadata['ip'] == return_value['cnode_list'][0]['cnode_metadata']['ip']
    assert cnode1_metadata['port']['rpc'] == return_value['cnode_list'][0]['cnode_metadata']['port']['rpc']
    assert cnode1_metadata['port']['p2p'] == return_value['cnode_list'][0]['cnode_metadata']['port']['p2p']
    assert cnode1_metadata['port']['rest'] == return_value['cnode_list'][0]['cnode_metadata']['port']['rest']
    assert cnode1_metadata['port']['profile'] == return_value['cnode_list'][0]['cnode_metadata']['port']['profile']

    """
    cnode2_metadata = {
        "id": "cnode2",
        "name": "chashire-cat",
        "ip": "127.0.0.1",
        "port": {
            "rpc": 17845,
            "p2p": 17846,
            "rest": 18080,
            "profile": 16060,
        },
    }
    cnode2_metadata_raw = json.dumps(cnode2_metadata)
    response = call_function('createBNode', ['wonderland1', 'cnode2', 'chashire-cat', cnode2_metadata_raw])
    return_value = json.loads(response.detail)
    print("Return of 'createBNode':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getBNode', ['wonderland1', 'cnode2'])
    return_value = json.loads(response)
    print("Return of 'getBNode':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code
    assert cnode2_metadata['id'] == return_value['cnode_list'][0]['cnode_metadata']['id']
    assert cnode2_metadata['name'] == return_value['cnode_list'][0]['cnode_metadata']['name']
    assert cnode2_metadata['ip'] == return_value['cnode_list'][0]['cnode_metadata']['ip']
    assert cnode2_metadata['port']['rpc'] == return_value['cnode_list'][0]['cnode_metadata']['port']['rpc']
    assert cnode2_metadata['port']['p2p'] == return_value['cnode_list'][0]['cnode_metadata']['port']['p2p']
    assert cnode2_metadata['port']['rest'] == return_value['cnode_list'][0]['cnode_metadata']['port']['rest']
    assert cnode2_metadata['port']['profile'] == return_value['cnode_list'][0]['cnode_metadata']['port']['profile']

    response = query_function('getAllBNodes', ['wonderland1'])
    return_value = json.loads(response)
    print("Return of 'getAllBNodes':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code
    assert cnode1_metadata['id'] == return_value['cnode_list'][0]['cnode_metadata']['id']
    assert cnode1_metadata['name'] == return_value['cnode_list'][0]['cnode_metadata']['name']
    assert cnode1_metadata['ip'] == return_value['cnode_list'][0]['cnode_metadata']['ip']
    assert cnode1_metadata['port']['rpc'] == return_value['cnode_list'][0]['cnode_metadata']['port']['rpc']
    assert cnode1_metadata['port']['p2p'] == return_value['cnode_list'][0]['cnode_metadata']['port']['p2p']
    assert cnode1_metadata['port']['rest'] == return_value['cnode_list'][0]['cnode_metadata']['port']['rest']
    assert cnode1_metadata['port']['profile'] == return_value['cnode_list'][0]['cnode_metadata']['port']['profile']
    assert cnode2_metadata['id'] == return_value['cnode_list'][1]['cnode_metadata']['id']
    assert cnode2_metadata['name'] == return_value['cnode_list'][1]['cnode_metadata']['name']
    assert cnode2_metadata['ip'] == return_value['cnode_list'][1]['cnode_metadata']['ip']
    assert cnode2_metadata['port']['rpc'] == return_value['cnode_list'][1]['cnode_metadata']['port']['rpc']
    assert cnode2_metadata['port']['p2p'] == return_value['cnode_list'][1]['cnode_metadata']['port']['p2p']
    assert cnode2_metadata['port']['rest'] == return_value['cnode_list'][1]['cnode_metadata']['port']['rest']
    assert cnode2_metadata['port']['profile'] == return_value['cnode_list'][1]['cnode_metadata']['port']['profile']
    """


def test_drop_horde(setup):
    print("test_drop_pond:", hsc_address)

    response = call_function('dropHorde', ['ogrima1'])
    return_value = json.loads(response.detail)
    print("Return of 'dropHorde':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getHorde', ['ogrima1'])
    return_value = json.loads(response)
    print("Return of 'getHorde':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 404 == status_code
