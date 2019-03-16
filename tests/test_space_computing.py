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


def test_add_horde(setup):
    print("test_add_horde:", hsc_address)
    metadata = {
        "name": "Ogrima",
        "who create it?": "YP",
        "what for?": "just for HSC test",
    }
    response = call_function('addCluster', ['ogrima1', 'Ogrima', True, json.dumps(metadata)])
    return_value = json.loads(response.detail)
    print("Return of 'addCluster':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getCluster', ['ogrima1'])
    return_value = json.loads(response)
    print("Return of 'getCluster':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code
    assert metadata['name'] == return_value['cluster_metadata']['name']
    assert metadata['who create it?'] == return_value['cluster_metadata']['who create it?']
    assert metadata['what for?'] == return_value['cluster_metadata']['what for?']


def test_update_horde(setup):
    print("test_update_horde:", hsc_address)
    metadata = {
        "I will register Machines below": [
            "bbabam",
            "zzazan",
        ],
    }
    metadata_raw = json.dumps(metadata)
    response = call_function('updateCluster', ['ogrima1', 'Thunder Bluff', True, metadata_raw])
    return_value = json.loads(response.detail)
    print("Return of 'updateCluster':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getCluster', ['ogrima1'])
    return_value = json.loads(response)
    print("Return of 'getCluster':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code
    assert metadata['I will register Machines below'][0] == return_value['cluster_metadata']['I will register Machines below'][0]
    assert metadata['I will register Machines below'][1] == return_value['cluster_metadata']['I will register Machines below'][1]


def test_create_machine(setup):
    print("test_create_machine:", hsc_address)

    machine1_metadata = {
        "id": "machine1",
        "name": "bbabam",
        "ip": "localhost",
        "port": {
            "rpc": 7845,
            "p2p": 7846,
            "rest": 8080,
            "profile": 6060,
        },
    }
    machine1_metadata_raw = json.dumps(machine1_metadata)
    response = call_function('addMachine', ['ogrima1', 'machine1', 'bbabam', machine1_metadata_raw])
    return_value = json.loads(response.detail)
    print("Return of 'addMachine':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getMachine', ['ogrima1', 'machine1'])
    return_value = json.loads(response)
    print("Return of 'getMachine':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code
    assert machine1_metadata['id'] == return_value['machine_list'][0]['machine_metadata']['id']
    assert machine1_metadata['name'] == return_value['machine_list'][0]['machine_metadata']['name']
    assert machine1_metadata['ip'] == return_value['machine_list'][0]['machine_metadata']['ip']
    assert machine1_metadata['port']['rpc'] == return_value['machine_list'][0]['machine_metadata']['port']['rpc']
    assert machine1_metadata['port']['p2p'] == return_value['machine_list'][0]['machine_metadata']['port']['p2p']
    assert machine1_metadata['port']['rest'] == return_value['machine_list'][0]['machine_metadata']['port']['rest']
    assert machine1_metadata['port']['profile'] == return_value['machine_list'][0]['machine_metadata']['port']['profile']

    machine2_metadata = {
        "id": "machine2",
        "name": "zzazan",
        "ip": "127.0.0.1",
        "port": {
            "rpc": 7845,
            "p2p": 7846,
            "rest": 8080,
            "profile": 6060,
        },
    }
    machine2_metadata_raw = json.dumps(machine2_metadata)
    response = call_function('addMachine', ['ogrima1', 'machine2', 'zzazan', machine2_metadata_raw])
    return_value = json.loads(response.detail)
    print("Return of 'addMachine':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getMachine', ['ogrima1', 'machine2'])
    return_value = json.loads(response)
    print("Return of 'getMachine':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code
    assert machine2_metadata['id'] == return_value['machine_list'][0]['machine_metadata']['id']
    assert machine2_metadata['name'] == return_value['machine_list'][0]['machine_metadata']['name']
    assert machine2_metadata['ip'] == return_value['machine_list'][0]['machine_metadata']['ip']
    assert machine2_metadata['port']['rpc'] == return_value['machine_list'][0]['machine_metadata']['port']['rpc']
    assert machine2_metadata['port']['p2p'] == return_value['machine_list'][0]['machine_metadata']['port']['p2p']
    assert machine2_metadata['port']['rest'] == return_value['machine_list'][0]['machine_metadata']['port']['rest']
    assert machine2_metadata['port']['profile'] == return_value['machine_list'][0]['machine_metadata']['port']['profile']

    response = query_function('getAllMachines', ['ogrima1'])
    return_value = json.loads(response)
    print("Return of 'getAllMachines':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code
    assert machine1_metadata['id'] == return_value['machine_list'][0]['machine_metadata']['id']
    assert machine1_metadata['name'] == return_value['machine_list'][0]['machine_metadata']['name']
    assert machine1_metadata['ip'] == return_value['machine_list'][0]['machine_metadata']['ip']
    assert machine1_metadata['port']['rpc'] == return_value['machine_list'][0]['machine_metadata']['port']['rpc']
    assert machine1_metadata['port']['p2p'] == return_value['machine_list'][0]['machine_metadata']['port']['p2p']
    assert machine1_metadata['port']['rest'] == return_value['machine_list'][0]['machine_metadata']['port']['rest']
    assert machine1_metadata['port']['profile'] == return_value['machine_list'][0]['machine_metadata']['port']['profile']
    assert machine2_metadata['id'] == return_value['machine_list'][1]['machine_metadata']['id']
    assert machine2_metadata['name'] == return_value['machine_list'][1]['machine_metadata']['name']
    assert machine2_metadata['ip'] == return_value['machine_list'][1]['machine_metadata']['ip']
    assert machine2_metadata['port']['rpc'] == return_value['machine_list'][1]['machine_metadata']['port']['rpc']
    assert machine2_metadata['port']['p2p'] == return_value['machine_list'][1]['machine_metadata']['port']['p2p']
    assert machine2_metadata['port']['rest'] == return_value['machine_list'][1]['machine_metadata']['port']['rest']
    assert machine2_metadata['port']['profile'] == return_value['machine_list'][1]['machine_metadata']['port']['profile']


def test_drop_machine(setup):
    print("test_drop_machine:", hsc_address)

    response = call_function('dropMachine', ['ogrima1', 'machine1'])
    return_value = json.loads(response.detail)
    print("Return of 'dropMachine':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getMachine', ['ogrima1', 'machine1'])
    return_value = json.loads(response)
    print("Return of 'getMachine':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 404 == status_code

    response = query_function('getAllMachines', ['ogrima1'])
    return_value = json.loads(response)
    print("Return of 'getAllMachines':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code

    machine2_metadata = {
        "id": "machine2",
        "name": "no-zzazan",
        "ip": "localhost",
        "port": {
            "rpc": 7845,
            "p2p": 7846,
            "rest": 8080,
            "profile": 6060,
        },
    }
    response = call_function('updateMachine', ['ogrima1', 'machine2', None, json.dumps(machine2_metadata)])
    return_value = json.loads(response.detail)
    print("Return of 'updateMachine':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getMachine', ['ogrima1', 'machine2'])
    return_value = json.loads(response)
    print("Return of 'getMachine':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code

    response = query_function('getAllMachines', ['ogrima1'])
    return_value = json.loads(response)
    print("Return of 'getAllMachines':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 200 == status_code
    assert machine2_metadata['id'] == return_value['machine_list'][0]['machine_metadata']['id']
    assert machine2_metadata['name'] == return_value['machine_list'][0]['machine_metadata']['name']
    assert machine2_metadata['ip'] == return_value['machine_list'][0]['machine_metadata']['ip']
    assert machine2_metadata['port']['rpc'] == return_value['machine_list'][0]['machine_metadata']['port']['rpc']
    assert machine2_metadata['port']['p2p'] == return_value['machine_list'][0]['machine_metadata']['port']['p2p']
    assert machine2_metadata['port']['rest'] == return_value['machine_list'][0]['machine_metadata']['port']['rest']
    assert machine2_metadata['port']['profile'] == return_value['machine_list'][0]['machine_metadata']['port']['profile']


def test_drop_horde(setup):
    print("test_drop_pond:", hsc_address)

    response = call_function('dropCluster', ['ogrima1'])
    return_value = json.loads(response.detail)
    print("Return of 'dropCluster':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 201 == status_code

    response = query_function('getCluster', ['ogrima1'])
    return_value = json.loads(response)
    print("Return of 'getCluster':\n{}".format(json.dumps(return_value, indent=2)))
    status_code = int(return_value["__status_code"])
    assert 404 == status_code
