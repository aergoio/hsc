import os
import sys
import traceback
import subprocess
import json

HSC_META = 'hsc_meta.lua'
HSC_DB = 'hsc_db.lua'
HSC_CMD = 'hsc_cmd.lua'
HSC_RESULT = 'hsc_result.lua'
HSC_CONFIG = 'hsc_config.lua'
HSC_POND = 'hsc_pond.lua'

HSC_SRC_DIR = "./sc/"
HSC_SRC_LIST = [
    HSC_META,
    HSC_DB,
    HSC_CMD,
    HSC_RESULT,
    HSC_CONFIG,
    HSC_POND,
]

HSC_PAYLOAD_DATA = "./hsc.payload.dat"

g_aergo_path = ""
g_aergo_luac_path = ""


def exit(error=True):
    if error:
        try:
            os.remove(HSC_PAYLOAD_DATA)
        except FileNotFoundError:
            pass
        sys.exit(1)

    sys.exit(0)


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


def check_aergo_path():
    global g_aergo_path

    print("Searching AERGO Path ...")

    if 'AERGO_PATH' in os.environ:
        g_aergo_path = str(os.environ['AERGO_PATH'])
    elif 'GOPATH' in os.environ:
        g_aergo_path = (os.environ['GOPATH'])
    else:
        eprint("ERROR: Cannot find AERGO_PATH")
        exit()

    print("  > AERGO_PATH: ", g_aergo_path)


def search_file(dir):
    global g_aergo_luac_path

    try:
        files = os.listdir(dir)
        for file in files:
            full = os.path.join(dir, file)
            if os.path.isdir(full):
                search_file(full)
            else:
                if file == "aergoluac":
                    g_aergo_luac_path = full
                    return
    except PermissionError:
        pass


def check_aergo_luac_path():
    try:
        search_file(g_aergo_path)
    except FileNotFoundError:
        eprint("ERROR: Cannot find AERGO_PATH for finding AERGO Lua Compiler (aergoluac)")
        exit()

    if g_aergo_luac_path is None or 0 == len(g_aergo_luac_path):
        eprint("ERROR: Cannot find AERGO Lua Compiler (aergoluac)")
        exit()

    print("  > 'aergoluac': ", g_aergo_luac_path)


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


def compile_src(src):
    # execute aergoluac
    process = subprocess.Popen([g_aergo_luac_path, "--payload", src],
                               stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE)
    out, err = process.communicate()
    if err is not None and len(err) != 0:
        eprint("ERROR: Fail to run 'aergoluac': {}".format(err))
        exit()

    # get payload
    return out.decode('utf-8').strip()


def check_src_payload(key, payload_info, force=False):
    src = os.path.join(HSC_SRC_DIR, key)
    src = os.path.abspath(src)
    if not os.path.isfile(src):
        eprint("ERROR: Cannot find the source file: {}".format(src))
        return True

    payload = compile_src(src)

    if key not in payload_info:
        payload_info[key] = {
            'src': src,
            'payload': payload,
            'compiled': True,
            'deployed': False
        }
        return True

    payload_info[key]['src'] = src

    if force:
        payload_info[key]['payload'] = payload
        payload_info[key]['compiled'] = True
        payload_info[key]['deployed'] = False
    else:
        if payload_info[key]['payload'] == payload:
            payload_info[key]['compiled'] = False
        else:
            payload_info[key]['payload'] = payload
            payload_info[key]['compiled'] = True
            payload_info[key]['deployed'] = False

    return payload_info[key]['compiled']


def hsc_compile():
    check_aergo_path()
    check_aergo_luac_path()
    print()

    print("Compiling Horde Smart Contract (HSC)")
    payload_info = read_payload_info()

    # at first always check HSC_META
    if check_src_payload(HSC_META, payload_info):
        need_to_change_all = True
        print("  > compiled ...", HSC_META)
    else:
        need_to_change_all = False
        print("  > ............", HSC_META)

    # check other sources
    for key in HSC_SRC_LIST:
        if key == HSC_META:
            continue

        if check_src_payload(key, payload_info, need_to_change_all):
            if key not in payload_info:
                print("  > ERROR ......", key)
                continue
            else:
                print("  > compiled ...", key)
        else:
            print("  > ............", key)

    # save payload info.
    write_payload_info(payload_info)


if __name__ == '__main__':
    try:
        hsc_compile()
        exit(False)
    except Exception:
        traceback.print_exception(*sys.exc_info())
        exit()
