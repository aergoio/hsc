--
-- Horde Smart Contract (HSC): Computing space
--

MODULE_NAME = "__HSC_SPACE_COMPUTING__"

MODULE_NAME_DB = "__MANIFEST_DB__"

state.var {
  -- contant variables
  _MANIFEST_ADDRESS = state.value(),
}

local function __init__(manifestAddress)
  _MANIFEST_ADDRESS:set(manifestAddress)
  local scAddress = system.getContractID()
  system.print(MODULE_NAME .. "__init__: sc_address=" .. scAddress)
  contract.call(_MANIFEST_ADDRESS:get(),
    "__init_module__", MODULE_NAME, scAddress)
end

local function __callFunction(module_name, func_name, ...)
  system.print(MODULE_NAME .. "__callFucntion: module_name=" .. module_name
          .. ", func_name=" .. func_name)
  return contract.call(_MANIFEST_ADDRESS:get(),
    "__call_module_function__", module_name, func_name, ...)
end

local function __getSender()
  return contract.call(_MANIFEST_ADDRESS:get(), "__get_sender__")
end

--[[ ============================================================================================================== ]]--

function constructor(manifestAddress)
  __init__(manifestAddress)
  system.print(MODULE_NAME .. "constructor: manifestAddress=" .. manifestAddress)

  -- create Horde master metadata table for CNodes
  __callFunction(MODULE_NAME_DB, "createTable",
    [[CREATE TABLE IF NOT EXISTS hordes(
            horde_owner     TEXT NOT NULL,
            horde_name      TEXT,
            horde_id        TEXT NOT NULL,
            is_public       INTEGER DEFAULT 0,
            horde_block_no  INTEGER DEFAULT NULL,
            metadata        TEXT,
            PRIMARY KEY (horde_id)
  )]])

  -- create Horde CNode metadata table
  __callFunction(MODULE_NAME_DB, "createTable",
    [[CREATE TABLE IF NOT EXISTS horde_cnodes(
            horde_id        TEXT NOT NULL,
            cnode_owner     TEXT NOT NULL,
            cnode_name      TEXT,
            cnode_id        TEXT NOT NULL,
            cnode_block_no  INTEGER DEFAULT NULL,
            metadata        TEXT,
            PRIMARY KEY(horde_id, cnode_id),
            FOREIGN KEY(horde_id) REFERENCES hordes(horde_id)
              ON DELETE CASCADE ON UPDATE NO ACTION
  )]])

  -- create Horde access control table
  --    * ac_detail = [TODO: categorize all object and then designate (CREATE/READ/WRITE/DELETE)]
  __callFunction(MODULE_NAME_DB, "createTable",
    [[CREATE TABLE IF NOT EXISTS hordes_ac_list(
            horde_id        TEXT NOT NULL,
            account_address TEXT NOT NULL,
            ac_detail       TEXT,
            PRIMARY KEY (horde_id, account_address)
            FOREIGN KEY (horde_id) REFERENCES hordes(horde_id)
              ON DELETE CASCADE ON UPDATE NO ACTION
  )]])
end

local function isEmpty(v)
  return nil == v or 0 == string.len(v)
end

function addHorde(horde_id, horde_name, is_public, metadata)
  if type(metadata) == 'string' then
    metadata = json:decode(metadata)
  end
  local metadata_raw = json:encode(metadata)
  system.print(MODULE_NAME .. "addHorde: horde_id=" .. tostring(horde_id)
          .. ", horde_name=" .. tostring(horde_name)
          .. ", is_public=" .. tostring(is_public)
          .. ", metadata=" .. metadata_raw)

  local sender = __getSender()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "addHorde: sender=" .. sender
          .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(horde_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "addHorde",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      horde_id = horde_id
    }
  end

  -- read registered Horde
  local res = getHorde(horde_id)
  system.print(MODULE_NAME .. "addHorde: res=" .. json:encode(res))

  if "404" == res["__status_code"] then
    -- check whether Horde is public
    local is_public_value = 0
    if is_public then
      is_public_value = 1
    else
      is_public_value = 0
    end

    __callFunction(MODULE_NAME_DB, "insert",
      [[INSERT INTO hordes(horde_owner,
                           horde_name,
                           horde_id,
                           is_public,
                           horde_block_no,
                           metadata)
               VALUES (?, ?, ?, ?, ?, ?)]],
      sender, horde_name, horde_id, is_public, block_no, metadata_raw)
  end

  -- check the CNode info from Horde
  for _, cnode in pairs(metadata['cnode_list']) do
    local cnode_id = cnode['cnode_id']
    local cnode_name = cnode['cnode_name']
    local cnode_metadata = cnode['cnode_metadata']

    addCNode(horde_id, cnode_id, cnode_name, cnode_metadata)
  end

  -- read registerd all CNodes of Horde
  local res = getAllCNodes(horde_id)
  system.print(MODULE_NAME .. "addHorde: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] and "404" ~= res["__status_code"] then
    return res
  end

  -- TODO: save this activity

  -- success to write (201 Created)
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "addHorde",
    __status_code = "201",
    __status_sub_code = "",
    horde_owner = res['horde_owner'],
    horde_id = res['horde_id'],
    horde_name = res['horde_name'],
    horde_metadata = res['horde_metadata'],
    horde_block_no = res['horde_block_no'],
    is_public = res['is_public'],
    cnode_list = res['cnode_list'],
  }
end

function getPublicHordes()
  system.print(MODULE_NAME .. "getPublicHordes")

  local horde_list = {}
  local exist = false

  -- check all public Hordes
  local rows = __callFunction(MODULE_NAME_DB, "select",
    [[SELECT horde_id, horde_owner, horde_name, metadata, horde_block_no
        FROM hordes
        WHERE is_public = 1
        ORDER BY horde_block_no]])

  for _, v in pairs(rows) do
    local horde_id = v[1]
    local cnode_list = {}

    local res = getAllCNodes(horde_id)
    system.print(MODULE_NAME .. "getPublicHordes: res=" .. json:encode(res))
    if "200" ~= res["__status_code"] and "404" ~= res["__status_code"] then
      return res
    elseif "200" == res["__status_code"] then
      cnode_list = res['cnode_list']
    end

    local horde = {
      horde_id = v[1],
      horde_owner = v[2],
      horde_name = v[3],
      horde_metadata = json:decode(v[4]),
      horde_block_no = v[5],
      is_public = true,
      cnode_list = cnode_list,
    }
    table.insert(horde_list, horde)

    exist = true
  end

  local sender = __getSender()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "getPublicHordes: sender=" .. tostring(sender)
          .. ", block_no=" .. tostring(block_no))

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getPublicHordes",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find any public computing group",
      sender = sender
    }
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "getPublicHordes",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    horde_list = horde_list
  }
end

function getAllHordes(owner)
  system.print(MODULE_NAME .. "getAllHordes: owner=" .. tostring(owner))

  -- check all public Hordes
  local res = getPublicHordes()
  system.print(MODULE_NAME .. "getAllHordes: res=" .. json:encode(res))
  if isEmpty(owner) then
    return res
  end

  local horde_list
  local exist = false
  if "404" == res["__status_code"] then
    horde_list = {}
  elseif "200" == res["__status_code"] then
    horde_list = res["horde_list"]
  else
    return res
  end

  local sender = __getSender()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "getAllHordes: sender=" .. tostring(sender)
          .. ", block_no=" .. tostring(block_no))

  -- check all owner's private Hordes
  local rows = __callFunction(MODULE_NAME_DB, "select",
    [[SELECT horde_id, horde_name, metadata, horde_block_no
        FROM hordes
        WHERE horde_owner = ? AND is_public = 0
        ORDER BY horde_block_no]],
    owner)

  for _, v in pairs(rows) do
    local horde_id = v[1]
    local cnode_list = {}

    -- read all CNodes of Horde
    local res = getAllCNodes(horde_id)
    system.print(MODULE_NAME .. "getAllHordes: res=" .. json:encode(res))
    if "200" ~= res["__status_code"] and "404" ~= res["__status_code"] then
      return res
    elseif "200" == res["__status_code"] then
      cnode_list = res['cnode_list']
    end

    local horde = {
      horde_id = horde_id,
      horde_owner = owner,
      horde_name = v[2],
      horde_metadata = json:decode(v[3]),
      horde_block_no = v[4],
      is_public = false,
      cnode_list = cnode_list,
    }
    table.insert(horde_list, horde)

    exist = true
  end

  -- check permissions (403.2 Read access forbidden)
  --[[ TODO: how to set the horde admin?
  local horde_admin = sender
  if sender ~= horde_admin then
    if not is_public then
      -- TODO: check sender's reading permission of horde
      return {
        __module = MODULE_NAME,
      __block_no = block_no,
        __func_name = "getHorde",
        __status_code = "403",
        __status_sub_code = "2",
        __err_msg = "Sender (" .. sender .. ") doesn't allow to read the computing group (" .. horde_id .. ")",
        sender = sender,
        horde_id = horde_id
      }
    end
  end]]--

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getAllHordes",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find any computing group",
      sender = sender,
      owner = owner,
    }
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "getAllHordes",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    horde_list = horde_list
  }
end

function getHorde(horde_id)
  system.print(MODULE_NAME .. "getHorde: horde_id=" .. tostring(horde_id))

  local sender = __getSender()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "getHorde: sender=" .. tostring(sender)
          .. ", block_no=" .. tostring(block_no))

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(horde_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "addHorde",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      horde_id = horde_id
    }
  end

  -- check registered Horde
  local rows = __callFunction(MODULE_NAME_DB, "select",
    [[SELECT horde_owner, horde_name, is_public, metadata, horde_block_no
        FROM hordes
        WHERE horde_id = ?
        ORDER BY horde_block_no]],
    horde_id)
  local horde_owner
  local horde_name
  local is_public
  local metadata
  local horde_block_no

  local exist = false
  for _, v in pairs(rows) do
    horde_owner = v[1]
    horde_name = v[2]

    if 1 == v[3] then
      is_public = true
    else
      is_public = false
    end

    metadata = json:decode(v[4])
    horde_block_no = v[5]

    exist = true
  end

  --[[ TODO: cannot check the sender of a query contract
  -- check permissions (403.2 Read access forbidden)
  if sender ~= horde_owner then
    if not is_public then
      -- TODO: check sender's reading permission of horde
      return {
        __module = MODULE_NAME,
        __block_no = block_no,
        __func_name = "getHorde",
        __status_code = "403",
        __status_sub_code = "2",
        __err_msg = "Sender (" .. sender .. ") doesn't allow to read the computing group (" .. horde_id .. ")",
        sender = sender,
        horde_id = horde_id
      }
    end
  end
  ]]--

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getHorde",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find the computing group (" .. horde_id .. ")",
      sender = sender,
      horde_id = horde_id
    }
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "getHorde",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    horde_owner = horde_owner,
    horde_id = horde_id,
    horde_name = horde_name,
    horde_metadata = metadata,
    horde_block_no = horde_block_no,
    is_public = is_public
  }
end

function dropHorde(horde_id)
  system.print(MODULE_NAME .. "dropHorde: horde_id=" .. tostring(horde_id))

  local sender = __getSender()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "dropHorde: sender=" .. sender
          .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(horde_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "addHorde",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      horde_id = horde_id
    }
  end

  -- read registered Horde
  local res = getHorde(horde_id)
  system.print(MODULE_NAME .. "dropHorde: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local horde_owner = res["horde_owner"]

  -- check permissions (403.1 Execute access forbidden)
  if sender ~= horde_owner then
    -- TODO: check sender's deregister (drop) permission of horde
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "dropHorde",
      __status_code = "403",
      __status_sub_code = "1",
      __err_msg = "Sender (" .. sender .. ") doesn't allow to deregister the computing group (" .. horde_id .. ")",
      sender = sender,
      horde_id = horde_id
    }
  end

  --
  __callFunction(MODULE_NAME_DB, "delete",
    "DELETE FROM hordes WHERE horde_id = ?", horde_id)

  -- TODO: save this activity

  -- 201 Created
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "dropHorde",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    horde_owner = horde_owner,
    horde_id = horde_id,
    horde_name = res['horde_name'],
    horde_metadata = res['horde_metadata'],
    horde_block_no = res['horde_block_no'],
    is_public = res['is_public']
  }
end

function updateHorde(horde_id, horde_name, is_public, metadata)
  if type(metadata) == 'string' then
    metadata = json:decode(metadata)
  end
  local metadata_raw = json:encode(metadata)
  system.print(MODULE_NAME .. "updateHorde: horde_id=" .. tostring(horde_id)
          .. ", horde_name=" .. tostring(horde_name)
          .. ", is_public=" .. tostring(is_public)
          .. ", metadata=" .. metadata_raw)

  local sender = __getSender()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "updateHorde: sender=" .. sender
          .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(horde_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "addHorde",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      horde_id = horde_id
    }
  end

  -- read registered Horde
  local res = getHorde(horde_id)
  system.print(MODULE_NAME .. "updateHorde: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local horde_owner = res["horde_owner"]

  -- check permissions (403.3 Write access forbidden)
  if sender ~= horde_owner then
    -- TODO: check sender's update permission of Horde
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "updateHorde",
      __status_code = "403",
      __status_sub_code = "3",
      __err_msg = "Sender (" .. sender .. ") doesn't allow to update the computing group (" .. horde_id .. ") info",
      sender = sender,
      horde_id = horde_id
    }
  end

  -- check arguments
  if isEmpty(horde_name) then
    horde_name = res["horde_name"]
  end

  if nil == is_public then
    is_public = res["is_public"]
  end

  local is_public_value = 0
  if is_public then
    is_public_value = 1
  else
    is_public_value = 0
  end

  if nil == metadata or isEmpty(metadata_raw) then
    metadata = res["horde_metadata"]
    metadata_raw = json:encode(metadata)
  end

  __callFunction(MODULE_NAME_DB, "update",
    [[UPDATE hordes SET horde_name = ?, is_public = ?, metadata = ?
        WHERE horde_id = ?]],
    horde_name, is_public_value, metadata_raw, horde_id)

  -- TODO: save this activity

  -- 201 Created
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "updateHorde",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    horde_owner = horde_owner,
    horde_id = horde_id,
    horde_name = horde_name,
    horde_metadata = metadata,
    horde_block_no = res['horde_block_no'],
    is_public = is_public
  }
end

function addCNode(horde_id, cnode_id, cnode_name, metadata)
  if type(metadata) == 'string' then
    metadata = json:decode(metadata)
  end
  local metadata_raw = json:encode(metadata)
  system.print(MODULE_NAME .. "addCNode: horde_id=" .. tostring(horde_id)
          .. ", cnode_id=" .. tostring(cnode_id)
          .. ", cnode_name=" .. tostring(cnode_name)
          .. ", metadata=" .. metadata_raw)

  local sender = __getSender()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "addCNode: sender=" .. sender
          .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(horde_id) or isEmpty(cnode_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "addHorde",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      horde_id = horde_id,
      cnode_id = cnode_id,
    }
  end

  -- read registered Horde
  local res = getHorde(horde_id)
  system.print(MODULE_NAME .. "addCNode: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local horde_owner = res["horde_owner"]

  -- check permissions (403.1 Execute access forbidden)
  if sender ~= horde_owner then
    -- TODO: check sender's register CNode permission of horde
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "addCNode",
      __status_code = "403",
      __status_sub_code = "1",
      __err_msg = "Sender (" .. sender .. ") doesn't allow to add a new node for the computing group (" .. horde_id .. ")",
      sender = sender,
      horde_id = horde_id
    }
  end

  __callFunction(MODULE_NAME_DB, "insert",
    [[INSERT OR REPLACE INTO horde_cnodes(horde_id,
                                          cnode_owner,
                                          cnode_name,
                                          cnode_id,
                                          cnode_block_no,
                                          metadata)
             VALUES (?, ?, ?, ?, ?, ?)]],
    horde_id, sender, cnode_name, cnode_id, block_no, metadata_raw)

  -- TODO: save this activity

  -- success to write (201 Created)
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "addCNode",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    horde_owner = horde_owner,
    horde_id = horde_id,
    horde_name = res['horde_name'],
    horde_metadata = res['horde_metadata'],
    horde_block_no = res['horde_block_no'],
    is_public = res['is_public'],
    cnode_list = {
      {
        cnode_owner = sender,
        cnode_name = cnode_name,
        cnode_id = cnode_id,
        cnode_metadata = metadata,
        cnode_block_no = block_no
      }
    }
  }
end

function getAllCNodes(horde_id)
  system.print(MODULE_NAME .. "getAllCNodes: horde_id=" .. tostring(horde_id))

  local sender = __getSender()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "getAllCNodes: sender=" .. tostring(sender)
          .. ", block_no=" .. tostring(block_no))

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(horde_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getAllCNodes",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      horde_id = horde_id,
    }
  end

  -- read registered Horde
  local res = getHorde(horde_id)
  system.print(MODULE_NAME .. "getAllCNodes: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local horde_owner = res["horde_owner"]
  local horde_name = res["horde_name"]
  local is_public = res["is_public"]
  local horde_metadata = res["horde_metadata"]
  local horde_block_no = res["horde_block_no"]

  -- check inserted data
  local rows = __callFunction(MODULE_NAME_DB, "select",
    [[SELECT cnode_owner, cnode_id, cnode_name, metadata, cnode_block_no
        FROM horde_cnodes
        WHERE horde_id = ?
        ORDER BY cnode_block_no]],
    horde_id)

  local cnode_list = {}

  local exist = false
  for _, v in pairs(rows) do
    local cnode = {
      cnode_owner = v[1],
      cnode_id = v[2],
      cnode_name = v[3],
      cnode_metadata = json:decode(v[4]),
      cnode_block_no = v[5]
    }
    table.insert(cnode_list, cnode)

    exist = true
  end

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getAllCNodes",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find any computing node in the computing group (" .. horde_id .. ")",
      sender = sender,
      horde_owner = horde_owner,
      horde_id = horde_id,
      horde_name = horde_name,
      horde_metadata = horde_metadata,
      horde_block_no = horde_block_no,
      is_public = is_public
    }
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "getAllCNodes",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    horde_owner = horde_owner,
    horde_id = horde_id,
    horde_name = horde_name,
    horde_metadata = horde_metadata,
    horde_block_no = horde_block_no,
    is_public = is_public,
    cnode_list = cnode_list
  }
end

function getCNode(horde_id, cnode_id)
  system.print(MODULE_NAME .. "getCNode: horde_id=" .. tostring(horde_id)
          .. ", cnode_id=" .. tostring(cnode_id))

  local sender = __getSender()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "getCNode: sender=" .. tostring(sender)
          .. ", block_no=" .. tostring(block_no))

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(horde_id) or isEmpty(cnode_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getCNode",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      horde_id = horde_id,
      cnode_id = cnode_id,
    }
  end

  -- read registered Horde
  local res = getHorde(horde_id)
  system.print(MODULE_NAME .. "getCNode: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local horde_owner = res["horde_owner"]
  local horde_name = res["horde_name"]
  local is_public = res["is_public"]
  local horde_metadata = res["horde_metadata"]
  local horde_block_no = res["horde_block_no"]

  -- check inserted data
  local rows = __callFunction(MODULE_NAME_DB, "select",
    [[SELECT cnode_owner, cnode_name, metadata, cnode_block_no
        FROM horde_cnodes
        WHERE horde_id = ? AND cnode_id = ?
        ORDER BY cnode_block_no]],
    horde_id, cnode_id)

  local cnode_list = {}

  local exist = false
  for _, v in pairs(rows) do
    local cnode = {
      cnode_id = cnode_id,
      cnode_owner = v[1],
      cnode_name = v[2],
      cnode_metadata = json:decode(v[3]),
      cnode_block_no = v[4]
    }
    table.insert(cnode_list, cnode)

    exist = true
  end

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getCNode",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find the node (" .. cnode_id .. ") info in the computing group (" .. horde_id .. ")",
      sender = sender,
      horde_owner = horde_owner,
      horde_id = horde_id,
      horde_name = horde_name,
      horde_metadata = horde_metadata,
      horde_block_no = horde_block_no,
      is_public = is_public,
      cnode_id = cnode_id
    }
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "getCNode",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    horde_owner = horde_owner,
    horde_id = horde_id,
    horde_name = horde_name,
    horde_metadata = horde_metadata,
    horde_block_no = horde_block_no,
    is_public = is_public,
    cnode_list = cnode_list
  }
end

function dropCNode(horde_id, cnode_id)
  system.print(MODULE_NAME .. "dropCNode: horde_id=" .. tostring(horde_id)
          .. ", cnode_id=" .. tostring(cnode_id))

  local sender = __getSender()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "dropCNode: sender=" .. sender
          .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(horde_id) or isEmpty(cnode_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "dropCNode",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      horde_id = horde_id,
      cnode_id = cnode_id,
    }
  end

  -- read registered CNode
  local res = getCNode(horde_id, cnode_id)
  system.print(MODULE_NAME .. "dropCNode: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local horde_owner = res["horde_owner"]
  local cnode_info = res["cnode_list"][1]
  local cnode_owner = cnode_info["cnode_owner"]

  -- check permissions (403.1 Execute access forbidden)
  if sender ~= horde_owner then
    if sender ~= cnode_owner then
      -- TODO: check sender's deregister (drop) permission of horde CNode
      return {
        __module = MODULE_NAME,
        __block_no = block_no,
        __func_name = "dropCNode",
        __status_code = "403",
        __status_sub_code = "1",
        __err_msg = "Sender (" .. sender .. ") doesn't allow to deregister a node of the computing group (" .. horde_id .. ")",
        sender = sender,
        horde_id = horde_id,
        cnode_id = cnode_id
      }
    end
  end

  -- drop CNode
  __callFunction(MODULE_NAME_DB, "delete",
    "DELETE FROM horde_cnodes WHERE horde_id = ? AND cnode_id = ?",
    horde_id, cnode_id)

  -- TODO: save this activity

  -- 201 Created
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "dropCNode",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    horde_owner = horde_owner,
    horde_id = horde_id,
    horde_name = res["horde_name"],
    horde_metadata = res["horde_metadata"],
    horde_block_no = res["horde_block_no"],
    is_public = res["is_public"],
    cnode_list = res["cnode_list"]
  }
end

function updateCNode(horde_id, cnode_id, cnode_name, metadata)
  if type(metadata) == 'string' then
    metadata = json:decode(metadata)
  end
  local metadata_raw = json:encode(metadata)
  system.print(MODULE_NAME .. "updateCNode: horde_id=" .. tostring(horde_id)
          .. ", cnode_id=" .. tostring(cnode_id)
          .. ", cnode_name=" .. tostring(cnode_name)
          .. ", metadata=" .. metadata_raw)

  local sender = __getSender()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "updateCNode: sender=" .. sender .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(horde_id) or isEmpty(cnode_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "updateCNode",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      horde_id = horde_id,
      cnode_id = cnode_id,
    }
  end

  -- read registered CNode
  local res = getCNode(horde_id, cnode_id)
  system.print(MODULE_NAME .. "updateCNode: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local horde_owner = res["horde_owner"]
  local cnode_info = res["cnode_list"][1]
  local cnode_owner = cnode_info["cnode_owner"]

  -- check permissions (403.3 Write access forbidden)
  if sender ~= horde_owner then
    if sender ~= cnode_owner then
      -- TODO: check sender's update permission of Horde
      return {
        __module = MODULE_NAME,
        __block_no = block_no,
        __func_name = "updateCNode",
        __status_code = "403",
        __status_sub_code = "3",
        __err_msg = "Sender (" .. sender .. ") doesn't allow to update a node info of the computing group (" .. horde_id .. ")",
        sender = sender,
        horde_id = horde_id,
        cnode_id = cnode_id
      }
    end
  end

  -- check arguments
  if isEmpty(cnode_name) then
    cnode_name = cnode_info["cnode_name"]
  end
  if isEmpty(metadata_raw) then
    metadata = cnode_info["cnode_metadata"]
    metadata_raw = json:encode(metadata)
  end

  __callFunction(MODULE_NAME_DB, "update",
    [[UPDATE horde_cnodes SET cnode_name = ?, metadata = ?
        WHERE horde_id = ? AND cnode_id = ?]],
    cnode_name, metadata_raw, horde_id, cnode_id)

  -- TODO: save this activity

  -- 201 Created
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "updateCNode",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    horde_owner = horde_owner,
    horde_id = horde_id,
    horde_name = res["horde_name"],
    horde_metadata = res["horde_metadata"],
    horde_block_no = res["horde_block_no"],
    is_public = res["is_public"],
    cnode_list = {
      {
        cnode_owner = cnode_owner,
        cnode_name = cnode_name,
        cnode_id = cnode_id,
        cnode_metadata = metadata,
        cnode_block_no = cnode_info['cnode_block_no']
      }
    }
  }
end

abi.register(addHorde, getPublicHordes, getAllHordes, getHorde,
  dropHorde, updateHorde, addCNode, getAllCNodes,
  getCNode, dropCNode, updateCNode)
