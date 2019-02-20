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
    hsc_compile.QUIET_MODE = False
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
    metadata_raw = json.dumps(metadata)
    response = call_function('createPond', ['wonderland1', 'wonderland', True, metadata_raw])
    return_value = json.loads(response.detail)
    print("Return of 'createPond':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getPond', ['wonderland1'])
    return_value = json.loads(response)
    print("Return of 'getPond':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code
    assert metadata['name'] == return_value['pond_metadata']['name']
    assert metadata['who create it?'] == return_value['pond_metadata']['who create it?']
    assert metadata['what for?'] == return_value['pond_metadata']['what for?']


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
    metadata_raw = json.dumps(metadata)
    response = call_function('updatePond', ['wonderland1', 'wonderland', True, metadata_raw])
    return_value = json.loads(response.detail)
    print("Return of 'updatePond':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getPond', ['wonderland1'])
    return_value = json.loads(response)
    print("Return of 'getPond':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code
    assert metadata['I will make bnodes below'][0] == return_value['pond_metadata']['I will make bnodes below'][0]
    assert metadata['I will make bnodes below'][1] == return_value['pond_metadata']['I will make bnodes below'][1]
    assert metadata['I will make bnodes below'][2] == return_value['pond_metadata']['I will make bnodes below'][2]
    assert metadata['I will make bnodes below'][3] == return_value['pond_metadata']['I will make bnodes below'][3]
    assert metadata['I will make bnodes below'][4] == return_value['pond_metadata']['I will make bnodes below'][4]
    assert metadata['I will make bnodes below'][5] == return_value['pond_metadata']['I will make bnodes below'][5]
    assert metadata['I will make bnodes below'][6] == return_value['pond_metadata']['I will make bnodes below'][6]
    assert metadata['I will make bnodes below'][7] == return_value['pond_metadata']['I will make bnodes below'][7]


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
    bnode1_metadata_raw = json.dumps(bnode1_metadata)
    response = call_function('createBNode', ['wonderland1', 'bnode1', 'red-queen', bnode1_metadata_raw])
    return_value = json.loads(response.detail)
    print("Return of 'createBNode':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getBNode', ['wonderland1', 'bnode1'])
    return_value = json.loads(response)
    print("Return of 'getBNode':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code
    assert bnode1_metadata['id'] == return_value['bnode_list'][0]['bnode_metadata']['id']
    assert bnode1_metadata['name'] == return_value['bnode_list'][0]['bnode_metadata']['name']
    assert bnode1_metadata['ip'] == return_value['bnode_list'][0]['bnode_metadata']['ip']
    assert bnode1_metadata['port']['rpc'] == return_value['bnode_list'][0]['bnode_metadata']['port']['rpc']
    assert bnode1_metadata['port']['p2p'] == return_value['bnode_list'][0]['bnode_metadata']['port']['p2p']
    assert bnode1_metadata['port']['rest'] == return_value['bnode_list'][0]['bnode_metadata']['port']['rest']
    assert bnode1_metadata['port']['profile'] == return_value['bnode_list'][0]['bnode_metadata']['port']['profile']

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
    bnode2_metadata_raw = json.dumps(bnode2_metadata)
    response = call_function('createBNode', ['wonderland1', 'bnode2', 'chashire-cat', bnode2_metadata_raw])
    return_value = json.loads(response.detail)
    print("Return of 'createBNode':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getBNode', ['wonderland1', 'bnode2'])
    return_value = json.loads(response)
    print("Return of 'getBNode':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code
    assert bnode2_metadata['id'] == return_value['bnode_list'][0]['bnode_metadata']['id']
    assert bnode2_metadata['name'] == return_value['bnode_list'][0]['bnode_metadata']['name']
    assert bnode2_metadata['ip'] == return_value['bnode_list'][0]['bnode_metadata']['ip']
    assert bnode2_metadata['port']['rpc'] == return_value['bnode_list'][0]['bnode_metadata']['port']['rpc']
    assert bnode2_metadata['port']['p2p'] == return_value['bnode_list'][0]['bnode_metadata']['port']['p2p']
    assert bnode2_metadata['port']['rest'] == return_value['bnode_list'][0]['bnode_metadata']['port']['rest']
    assert bnode2_metadata['port']['profile'] == return_value['bnode_list'][0]['bnode_metadata']['port']['profile']

    response = query_function('getAllBNodes', ['wonderland1'])
    return_value = json.loads(response)
    print("Return of 'getAllBNodes':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code
    assert bnode1_metadata['id'] == return_value['bnode_list'][0]['bnode_metadata']['id']
    assert bnode1_metadata['name'] == return_value['bnode_list'][0]['bnode_metadata']['name']
    assert bnode1_metadata['ip'] == return_value['bnode_list'][0]['bnode_metadata']['ip']
    assert bnode1_metadata['port']['rpc'] == return_value['bnode_list'][0]['bnode_metadata']['port']['rpc']
    assert bnode1_metadata['port']['p2p'] == return_value['bnode_list'][0]['bnode_metadata']['port']['p2p']
    assert bnode1_metadata['port']['rest'] == return_value['bnode_list'][0]['bnode_metadata']['port']['rest']
    assert bnode1_metadata['port']['profile'] == return_value['bnode_list'][0]['bnode_metadata']['port']['profile']
    assert bnode2_metadata['id'] == return_value['bnode_list'][1]['bnode_metadata']['id']
    assert bnode2_metadata['name'] == return_value['bnode_list'][1]['bnode_metadata']['name']
    assert bnode2_metadata['ip'] == return_value['bnode_list'][1]['bnode_metadata']['ip']
    assert bnode2_metadata['port']['rpc'] == return_value['bnode_list'][1]['bnode_metadata']['port']['rpc']
    assert bnode2_metadata['port']['p2p'] == return_value['bnode_list'][1]['bnode_metadata']['port']['p2p']
    assert bnode2_metadata['port']['rest'] == return_value['bnode_list'][1]['bnode_metadata']['port']['rest']
    assert bnode2_metadata['port']['profile'] == return_value['bnode_list'][1]['bnode_metadata']['port']['profile']


def test_delete_bnode(setup):
    print("test_delete_bnode:", hsc_address)

    response = call_function('deleteBNode', ['wonderland1', 'bnode1'])
    return_value = json.loads(response.detail)
    print("Return of 'deleteBNode':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getBNode', ['wonderland1', 'bnode1'])
    return_value = json.loads(response)
    print("Return of 'getBNode':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 404 == status_code

    response = query_function('getAllBNodes', ['wonderland1'])
    return_value = json.loads(response)
    print("Return of 'getAllBNodes':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code

    bnode2_metadata = {
        "id": "bnode2",
        "name": "chashire-cat",
        "ip": "localhost",
        "port": {
            "rpc": 7845,
            "p2p": 7846,
            "rest": 8080,
            "profile": 6060,
        },
    }
    response = call_function('updateBNode', ['wonderland1', 'bnode2', None, json.dumps(bnode2_metadata)])
    return_value = json.loads(response.detail)
    print("Return of 'updateBNode':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getBNode', ['wonderland1', 'bnode2'])
    return_value = json.loads(response)
    print("Return of 'getBNode':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code

    response = query_function('getAllBNodes', ['wonderland1'])
    return_value = json.loads(response)
    print("Return of 'getAllBNodes':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code
    assert bnode2_metadata['id'] == return_value['bnode_list'][0]['bnode_metadata']['id']
    assert bnode2_metadata['name'] == return_value['bnode_list'][0]['bnode_metadata']['name']
    assert bnode2_metadata['ip'] == return_value['bnode_list'][0]['bnode_metadata']['ip']
    assert bnode2_metadata['port']['rpc'] == return_value['bnode_list'][0]['bnode_metadata']['port']['rpc']
    assert bnode2_metadata['port']['p2p'] == return_value['bnode_list'][0]['bnode_metadata']['port']['p2p']
    assert bnode2_metadata['port']['rest'] == return_value['bnode_list'][0]['bnode_metadata']['port']['rest']
    assert bnode2_metadata['port']['profile'] == return_value['bnode_list'][0]['bnode_metadata']['port']['profile']


def test_delete_pond(setup):
    print("test_delete_pond:", hsc_address)

    response = call_function('deletePond', ['civil_war_#1'])
    return_value = json.loads(response.detail)
    print("Return of 'deletePond':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = call_function('deletePond', ['wonderland1'])
    return_value = json.loads(response.detail)
    print("Return of 'deletePond':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getPond', ['wonderland1'])
    return_value = json.loads(response)
    print("Return of 'getPond':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 404 == status_code

    response = query_function('getBNode', ['wonderland1', 'bnode2'])
    return_value = json.loads(response)
    print("Return of 'getBNode':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 404 == status_code

    response = query_function('getAllBNodes', ['wonderland1'])
    return_value = json.loads(response)
    print("Return of 'getBNode':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 404 == status_code


def test_create_pond_from_tribe(setup):
    print("test_create_pond_from_tribe:", hsc_address)

    pond_name = "Civil War"
    pond_id = "civil_war_#1"
    bp_cnt = 2
    balance_list = [
        {
            "address": "Tony Stark's account address",
            "balance": "500000000000000000000000000"
        },
        {
            "address": "Peter Parker's account address",
            "balance": "50000000"
        },
        {
            "address": "Natasha Romanoff's account address",
            "balance": "50000000000000000000"
        },
        {
            "address": "Bucky Barns's account address",
            "balance": "50000000000000000000"
        },
        {
            "address": "T'Challa's account address",
            "balance": "50000000000000000000000"
        },
    ]
    pond_metadata = {
        "consensus_alg": "dpos",
        "bp_cnt": bp_cnt,
        "balance_list": balance_list,
        "created_bnode_list": [
            {
                "bnode_id": "captain_1",
                "bnode_name": "Steve Rogers",
                "bnode_metadata": {
                    "type": "team_captain",
                    "is_bp": True,
                    "server_id": "team_captain_steve_as_captain_1",
                }
            }
        ],
    }
    metadata_raw = json.dumps(pond_metadata)
    response = call_function('createPond', [pond_id, pond_name, True, metadata_raw])
    return_value = json.loads(response.detail)
    print("Return of 'createPond':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getAllBNodes', [pond_id])
    return_value = json.loads(response)
    print("Return of 'getAllBNodes':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code
    assert pond_metadata['bp_cnt'] == return_value['pond_metadata']['bp_cnt']
    assert pond_metadata['consensus_alg'] == return_value['pond_metadata']['consensus_alg']
    assert 'created_bnode_list' not in return_value['pond_metadata']
    assert 'genesis_json' not in return_value['pond_metadata']

    pond_metadata = {
        "consensus_alg": "dpos",
        "bp_cnt": bp_cnt,
        "balance_list": balance_list,
        "created_bnode_list": [
            {
                "bnode_id": "iron_1",
                "bnode_name": "Spider New York Kid",
                "bnode_metadata": {
                    "type": "team_iron",
                    "is_bp": True,
                    "server_id": "team_iron_spiderman_as_iron_1",
                }
            },
            {
                "bnode_id": "iron_2",
                "bnode_name": "Vision",
                "bnode_metadata": {
                    "type": "team_iron",
                    "is_bp": True,
                    "server_id": "team_iron_vision_as_iron_2",
                }
            },
        ],
    }
    metadata_raw = json.dumps(pond_metadata)
    response = call_function('createPond', [pond_id, pond_name, True, metadata_raw])
    return_value = json.loads(response.detail)
    print("Return of 'createPond':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getAllBNodes', [pond_id])
    return_value = json.loads(response)
    print("Return of 'getAllBNodes':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code
    assert pond_metadata['bp_cnt'] == return_value['pond_metadata']['bp_cnt']
    assert pond_metadata['consensus_alg'] == return_value['pond_metadata']['consensus_alg']
    assert 'created_bnode_list' not in return_value['pond_metadata']
    assert 'genesis_json' in return_value['pond_metadata']
    assert bp_cnt == len(return_value['pond_metadata']['genesis_json']['bps'])

