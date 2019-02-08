import os
import sys
import traceback
import subprocess
import json

HSC_VERSION="v0.1.2"

_MANIFEST = '_manifest.lua'
_MANIFEST_DB = '_manifest_db.lua'

HSC_COMPILED_PAYLOAD_DATA_FILE = "./hsc.compiled.payload.dat"

g_aergo_path = ""
g_aergo_luac_path = ""

QUIET_MODE = False


def out_print(*args, **kwargs):
    if not QUIET_MODE:
        print(*args, **kwargs)


def err_print(*args, **kwargs):
    if not QUIET_MODE:
        print(*args, file=sys.stderr, **kwargs)


def exit(error=True):
    if error:
        try:
            os.remove(HSC_COMPILED_PAYLOAD_DATA_FILE)
        except FileNotFoundError:
            pass
        sys.exit(1)

    sys.exit(0)


def get_all_lua_files(dir, files):
    for dirpath, dirnames, filenames in os.walk(dir):
        for fn in filenames:
            file_name, file_ext = os.path.splitext(fn)
            if file_ext == '.lua':
                files[fn] = os.path.join(dirpath, fn)
        for dn in dirnames:
            get_all_lua_files(os.path.join(dirpath, dn), files)


def check_aergo_path():
    global g_aergo_path

    out_print("Searching AERGO Path ...")

    if 'AERGO_PATH' in os.environ:
        g_aergo_path = str(os.environ['AERGO_PATH'])
    elif 'GOPATH' in os.environ:
        g_aergo_path = (os.environ['GOPATH'])
    else:
        raise FileNotFoundError("Cannot find AERGO_PATH")

    out_print("  > AERGO_PATH: ", g_aergo_path)


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
        raise FileNotFoundError("Cannot find AERGO_PATH for finding AERGO Lua Compiler (aergoluac)")

    if g_aergo_luac_path is None or 0 == len(g_aergo_luac_path):
        raise FileNotFoundError("Cannot find AERGO Lua Compiler (aergoluac)")

    out_print("  > 'aergoluac': ", g_aergo_luac_path)


def read_payload_info():
    # read previous information
    if os.path.isfile(HSC_COMPILED_PAYLOAD_DATA_FILE):
        with open(HSC_COMPILED_PAYLOAD_DATA_FILE) as f:
            payload_info = json.load(f)
            f.close()
    else:
        payload_info = {}
    return payload_info


def write_payload_info(payload_info):
    # store deploy json
    with open(HSC_COMPILED_PAYLOAD_DATA_FILE, "w") as f:
        f.write(json.dumps(payload_info, indent=2))
        f.close()


def compile_src(src):
    # execute aergoluac
    process = subprocess.Popen([g_aergo_luac_path, "--payload", src],
                               stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE)
    out, err = process.communicate()
    if err is not None and len(err) != 0:
        raise SyntaxError("Fail to run 'aergoluac': {}".format(err))

    # get payload
    return out.decode('utf-8').strip()


def check_src_payload(key, path, payload_info, is_manifest=False):
    src = os.path.abspath(path)
    payload = compile_src(src)

    if key not in payload_info:
        payload_info[key] = {
            'src': src,
            'payload': payload,
            'is_manifest': is_manifest,
        }
        return True
    else:
        if payload_info[key]['payload'] != payload:
            payload_info[key] = {
                'src': src,
                'payload': payload,
                'is_manifest': is_manifest,
            }
            return True

    return False


def hsc_compile():
    # check Aergo environment
    check_aergo_path()
    check_aergo_luac_path()
    out_print()

    # check lua files
    lua_dir = os.getenv('HSC_LUA_DIR', './sc')
    lua_files = {}
    get_all_lua_files(lua_dir, lua_files)

    found_manifest = False
    found_manifest_db = False

    hsc_src_list = {}
    for fn, fp in lua_files.items():
        if fn == _MANIFEST:
            found_manifest = True
        if fn == _MANIFEST_DB:
            found_manifest_db = True

        hsc_src_list[fn] = fp

    if not found_manifest:
        raise FileNotFoundError("Cannot find Manifest")
    if not found_manifest_db:
        raise FileNotFoundError("Cannot find Manifest DB")

    out_print("Compiling Manifest")

    payload_info = read_payload_info()
    payload_info["hsc_version"] = HSC_VERSION

    # at first always check _MANIFEST
    if check_src_payload(_MANIFEST, hsc_src_list[_MANIFEST], payload_info, is_manifest=True):
        out_print("  > compiled ...", _MANIFEST)
    else:
        out_print("  > ............", _MANIFEST)

    # check _MANIFEST_DB
    if check_src_payload(_MANIFEST_DB, hsc_src_list[_MANIFEST_DB], payload_info, is_manifest=True):
        out_print("  > compiled ...", _MANIFEST_DB)
    else:
        out_print("  > ............", _MANIFEST_DB)

    out_print('')
    out_print("Compiling Horde Smart Contract (HSC)")

    # check other sources
    for fn, fp in hsc_src_list.items():
        if fn == _MANIFEST or fn == _MANIFEST_DB:
            continue

        if check_src_payload(fn, fp, payload_info):
            if fn not in payload_info:
                out_print("  > ERROR ......", fn)
                continue
            else:
                out_print("  > compiled ...", fn)
        else:
            out_print("  > ............", fn)

    # save payload info.
    write_payload_info(payload_info)
    out_print('')


if __name__ == '__main__':
    try:
        hsc_compile()
        exit(False)
    except Exception as e:
        err_print(e)
        if not QUIET_MODE:
            traceback.print_exception(*sys.exc_info())
        exit(True)
