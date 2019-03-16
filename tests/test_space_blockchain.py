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


def test_create_chain(setup):
    print("test_create_chain:", hsc_address)
    metadata = {
        "name": "wonderland",
        "who create it?": "YP",
        "what for?": "just for HSC test",
    }
    metadata_raw = json.dumps(metadata)
    response = call_function('createChain', ['wonderland1', 'wonderland', True, metadata_raw])
    return_value = json.loads(response.detail)
    print("Return of 'createChain':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getChain', ['wonderland1'])
    return_value = json.loads(response)
    print("Return of 'getChain':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code
    assert metadata['name'] == return_value['chain_metadata']['name']
    assert metadata['who create it?'] == return_value['chain_metadata']['who create it?']
    assert metadata['what for?'] == return_value['chain_metadata']['what for?']


def test_update_chain(setup):
    print("test_update_chain:", hsc_address)
    metadata = {
        "I will make nodes below": [
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
    response = call_function('updateChain', ['wonderland1', 'wonderland', True, metadata_raw])
    return_value = json.loads(response.detail)
    print("Return of 'updateChain':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getChain', ['wonderland1'])
    return_value = json.loads(response)
    print("Return of 'getChain':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code
    assert metadata['I will make nodes below'][0] == return_value['chain_metadata']['I will make nodes below'][0]
    assert metadata['I will make nodes below'][1] == return_value['chain_metadata']['I will make nodes below'][1]
    assert metadata['I will make nodes below'][2] == return_value['chain_metadata']['I will make nodes below'][2]
    assert metadata['I will make nodes below'][3] == return_value['chain_metadata']['I will make nodes below'][3]
    assert metadata['I will make nodes below'][4] == return_value['chain_metadata']['I will make nodes below'][4]
    assert metadata['I will make nodes below'][5] == return_value['chain_metadata']['I will make nodes below'][5]
    assert metadata['I will make nodes below'][6] == return_value['chain_metadata']['I will make nodes below'][6]
    assert metadata['I will make nodes below'][7] == return_value['chain_metadata']['I will make nodes below'][7]


def test_create_node(setup):
    print("test_create_node:", hsc_address)

    node1_metadata = {
        "id": "node1",
        "name": "red-queen",
        "ip": "localhost",
        "port": {
            "rpc": 7845,
            "p2p": 7846,
            "rest": 8080,
            "profile": 6060,
        },
    }
    node1_metadata_raw = json.dumps(node1_metadata)
    response = call_function('createNode', ['wonderland1', 'node1', 'red-queen', node1_metadata_raw])
    return_value = json.loads(response.detail)
    print("Return of 'createNode':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getNode', ['wonderland1', 'node1'])
    return_value = json.loads(response)
    print("Return of 'getNode':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code
    assert node1_metadata['id'] == return_value['node_list'][0]['node_metadata']['id']
    assert node1_metadata['name'] == return_value['node_list'][0]['node_metadata']['name']
    assert node1_metadata['ip'] == return_value['node_list'][0]['node_metadata']['ip']
    assert node1_metadata['port']['rpc'] == return_value['node_list'][0]['node_metadata']['port']['rpc']
    assert node1_metadata['port']['p2p'] == return_value['node_list'][0]['node_metadata']['port']['p2p']
    assert node1_metadata['port']['rest'] == return_value['node_list'][0]['node_metadata']['port']['rest']
    assert node1_metadata['port']['profile'] == return_value['node_list'][0]['node_metadata']['port']['profile']

    node2_metadata = {
        "id": "node2",
        "name": "chashire-cat",
        "ip": "127.0.0.1",
        "port": {
            "rpc": 17845,
            "p2p": 17846,
            "rest": 18080,
            "profile": 16060,
        },
    }
    node2_metadata_raw = json.dumps(node2_metadata)
    response = call_function('createNode', ['wonderland1', 'node2', 'chashire-cat', node2_metadata_raw])
    return_value = json.loads(response.detail)
    print("Return of 'createNode':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getNode', ['wonderland1', 'node2'])
    return_value = json.loads(response)
    print("Return of 'getNode':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code
    assert node2_metadata['id'] == return_value['node_list'][0]['node_metadata']['id']
    assert node2_metadata['name'] == return_value['node_list'][0]['node_metadata']['name']
    assert node2_metadata['ip'] == return_value['node_list'][0]['node_metadata']['ip']
    assert node2_metadata['port']['rpc'] == return_value['node_list'][0]['node_metadata']['port']['rpc']
    assert node2_metadata['port']['p2p'] == return_value['node_list'][0]['node_metadata']['port']['p2p']
    assert node2_metadata['port']['rest'] == return_value['node_list'][0]['node_metadata']['port']['rest']
    assert node2_metadata['port']['profile'] == return_value['node_list'][0]['node_metadata']['port']['profile']

    response = query_function('getAllNodes', ['wonderland1'])
    return_value = json.loads(response)
    print("Return of 'getAllNodes':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code
    assert node1_metadata['id'] == return_value['node_list'][0]['node_metadata']['id']
    assert node1_metadata['name'] == return_value['node_list'][0]['node_metadata']['name']
    assert node1_metadata['ip'] == return_value['node_list'][0]['node_metadata']['ip']
    assert node1_metadata['port']['rpc'] == return_value['node_list'][0]['node_metadata']['port']['rpc']
    assert node1_metadata['port']['p2p'] == return_value['node_list'][0]['node_metadata']['port']['p2p']
    assert node1_metadata['port']['rest'] == return_value['node_list'][0]['node_metadata']['port']['rest']
    assert node1_metadata['port']['profile'] == return_value['node_list'][0]['node_metadata']['port']['profile']
    assert node2_metadata['id'] == return_value['node_list'][1]['node_metadata']['id']
    assert node2_metadata['name'] == return_value['node_list'][1]['node_metadata']['name']
    assert node2_metadata['ip'] == return_value['node_list'][1]['node_metadata']['ip']
    assert node2_metadata['port']['rpc'] == return_value['node_list'][1]['node_metadata']['port']['rpc']
    assert node2_metadata['port']['p2p'] == return_value['node_list'][1]['node_metadata']['port']['p2p']
    assert node2_metadata['port']['rest'] == return_value['node_list'][1]['node_metadata']['port']['rest']
    assert node2_metadata['port']['profile'] == return_value['node_list'][1]['node_metadata']['port']['profile']


def test_delete_node(setup):
    print("test_delete_node:", hsc_address)

    response = call_function('deleteNode', ['wonderland1', 'node1'])
    return_value = json.loads(response.detail)
    print("Return of 'deleteNode':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getNode', ['wonderland1', 'node1'])
    return_value = json.loads(response)
    print("Return of 'getNode':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 404 == status_code

    response = query_function('getAllNodes', ['wonderland1'])
    return_value = json.loads(response)
    print("Return of 'getAllNodes':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code

    node2_metadata = {
        "id": "node2",
        "name": "chashire-cat",
        "ip": "localhost",
        "port": {
            "rpc": 7845,
            "p2p": 7846,
            "rest": 8080,
            "profile": 6060,
        },
    }
    response = call_function('updateNode', ['wonderland1', 'node2', None, json.dumps(node2_metadata)])
    return_value = json.loads(response.detail)
    print("Return of 'updateNode':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getNode', ['wonderland1', 'node2'])
    return_value = json.loads(response)
    print("Return of 'getNode':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code

    response = query_function('getAllNodes', ['wonderland1'])
    return_value = json.loads(response)
    print("Return of 'getAllNodes':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code
    assert node2_metadata['id'] == return_value['node_list'][0]['node_metadata']['id']
    assert node2_metadata['name'] == return_value['node_list'][0]['node_metadata']['name']
    assert node2_metadata['ip'] == return_value['node_list'][0]['node_metadata']['ip']
    assert node2_metadata['port']['rpc'] == return_value['node_list'][0]['node_metadata']['port']['rpc']
    assert node2_metadata['port']['p2p'] == return_value['node_list'][0]['node_metadata']['port']['p2p']
    assert node2_metadata['port']['rest'] == return_value['node_list'][0]['node_metadata']['port']['rest']
    assert node2_metadata['port']['profile'] == return_value['node_list'][0]['node_metadata']['port']['profile']


def test_delete_chain(setup):
    print("test_delete_chain:", hsc_address)

    response = call_function('deleteChain', ['civil_war_#1'])
    return_value = json.loads(response.detail)
    print("Return of 'deleteChain':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = call_function('deleteChain', ['wonderland1'])
    return_value = json.loads(response.detail)
    print("Return of 'deleteChain':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getChain', ['wonderland1'])
    return_value = json.loads(response)
    print("Return of 'getChain':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 404 == status_code

    response = query_function('getNode', ['wonderland1', 'node2'])
    return_value = json.loads(response)
    print("Return of 'getNode':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 404 == status_code

    response = query_function('getAllNodes', ['wonderland1'])
    return_value = json.loads(response)
    print("Return of 'getNode':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 404 == status_code


def test_create_chain_from_tribe(setup):
    print("test_create_chain_from_tribe:", hsc_address)

    chain_name = "Civil War"
    chain_id = "civil_war_#1"
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
    chain_metadata = {
        "consensus_alg": "dpos",
        "bp_cnt": bp_cnt,
        "balance_list": balance_list,
        "new_node_list": [
            {
                "node_id": "captain_1",
                "node_name": "Steve Rogers",
                "node_metadata": {
                    "type": "team_captain",
                    "is_bp": True,
                    "server_id": "team_captain_steve_as_captain_1",
                }
            }
        ],
    }
    metadata_raw = json.dumps(chain_metadata)
    response = call_function('createChain', [chain_id, chain_name, True, metadata_raw])
    return_value = json.loads(response.detail)
    print("Return of 'createChain':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getAllNodes', [chain_id])
    return_value = json.loads(response)
    print("Return of 'getAllNodes':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code
    assert chain_metadata['bp_cnt'] == return_value['chain_metadata']['bp_cnt']
    assert chain_metadata['consensus_alg'] == return_value['chain_metadata']['consensus_alg']
    assert 'new_node_list' not in return_value['chain_metadata']
    assert 'genesis_json' not in return_value['chain_metadata']

    chain_metadata = {
        "consensus_alg": "dpos",
        "bp_cnt": bp_cnt,
        "balance_list": balance_list,
        "new_node_list": [
            {
                "node_id": "iron_1",
                "node_name": "Spider New York Kid",
                "node_metadata": {
                    "type": "team_iron",
                    "is_bp": True,
                    "server_id": "team_iron_spiderman_as_iron_1",
                }
            },
            {
                "node_id": "iron_2",
                "node_name": "Vision",
                "node_metadata": {
                    "type": "team_iron",
                    "is_bp": True,
                    "server_id": "team_iron_vision_as_iron_2",
                }
            },
        ],
    }
    metadata_raw = json.dumps(chain_metadata)
    response = call_function('createChain', [chain_id, chain_name, True, metadata_raw])
    return_value = json.loads(response.detail)
    print("Return of 'createChain':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getAllNodes', [chain_id])
    return_value = json.loads(response)
    print("Return of 'getAllNodes':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code
    assert chain_metadata['bp_cnt'] == return_value['chain_metadata']['bp_cnt']
    assert chain_metadata['consensus_alg'] == return_value['chain_metadata']['consensus_alg']
    assert 'new_node_list' not in return_value['chain_metadata']
    assert 'genesis_json' in return_value['chain_metadata']
    assert bp_cnt == len(return_value['chain_metadata']['genesis_json']['bps'])

