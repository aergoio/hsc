--
-- Horde Smart Contract (HSC): Blockchain space
--

MODULE_NAME = "__HSC_SPACE_BLOCKCHAIN__"

MODULE_NAME_DB = "__MANIFEST_DB__"

state.var {
  -- contant variables
  _MANIFEST_ADDRESS = state.value(),
}

local function __init__(manifestAddress)
  _MANIFEST_ADDRESS:set(manifestAddress)
  local scAddress = system.getContractID()
  system.print(MODULE_NAME .. "__init__: sc_address=" .. scAddress)
  contract.call(_MANIFEST_ADDRESS:get(), "__init_module__", MODULE_NAME, scAddress)
end

local function __callFunction(module_name, func_name, ...)
  system.print(MODULE_NAME .. "__callFucntion: module_name=" .. module_name .. ", func_name=" .. func_name)
  return contract.call(_MANIFEST_ADDRESS:get(), "__call_module_function__", module_name, func_name, ...)
end

--[[ ============================================================================================================== ]]--

function constructor(manifestAddress)
  __init__(manifestAddress)
  system.print(MODULE_NAME .. "constructor: manifestAddress=" .. manifestAddress)

  -- create Pond metadata table
  --    * is_public = [1=public, 0=permissioned]
  --    * metadata  = [genesis info,]
  __callFunction(MODULE_NAME_DB, "createTable", [[CREATE TABLE IF NOT EXISTS horde_ponds(
    creator         TEXT NOT NULL,
    pond_name       TEXT,
    pond_id         TEXT NOT NULL,
    is_public       INTEGER DEFAULT 0,
    pond_block_no   INTEGER DEFAULT NULL,
    metadata        TEXT,
    PRIMARY KEY (pond_id)
  )]])

  -- create BNode metadata table
  --    * metadata = [cnode_info,]
  __callFunction(MODULE_NAME_DB, "createTable", [[CREATE TABLE IF NOT EXISTS horde_bnodes(
    pond_id         TEXT NOT NULL,
    creator         TEXT NOT NULL,
    bnode_name      TEXT,
    bnode_id        TEXT NOT NULL,
    bnode_block_no  INTEGER DEFAULT NULL,
    metadata        TEXT,
    PRIMARY KEY (pond_id, bnode_id),
    FOREIGN KEY (pond_id) REFERENCES horde_ponds(pond_id)
      ON DELETE CASCADE ON UPDATE NO ACTION
  )]])

  -- create Pond access control table
  --    * ac_detail = [TODO: categorize all object and then designate (CREATE/READ/WRITE/DELETE)]
  __callFunction(MODULE_NAME_DB, "createTable", [[CREATE TABLE IF NOT EXISTS horde_ponds_ac_list(
    pond_id         TEXT NOT NULL,
    account_address TEXT NOT NULL,
    ac_detail       TEXT,
    PRIMARY KEY (pond_id, account_address)
    FOREIGN KEY (pond_id) REFERENCES horde_ponds(pond_id)
      ON DELETE CASCADE ON UPDATE NO ACTION
  )]])
end

local function isEmpty(v)
  return nil == v or 0 == string.len(v)
end

local function generateDposGenesisJson(pond_info)
  system.print(MODULE_NAME .. "generateDposGenesisJson: pond_info=" .. json:encode(pond_info))

  local pond_metadata = pond_info['pond_metadata']
  if nil ~= pond_metadata and nil ~= pond_metadata['genesis_json'] then
    if pond_metadata['bp_cnt'] == table.getn(pond_metadata['genesis_json']['bps']) then
      return pond_metadata['genesis_json']
    end
  end

  local bnode_list = pond_info['bnode_list']
  local bp_list = {}
  for _, bnode in pairs(bnode_list) do
    local bnode_metadata = bnode['bnode_metadata']
    if bnode_metadata['is_bp'] then
      table.insert(bp_list, bnode)
    end
  end

  if pond_metadata['bp_cnt'] <= table.getn(bp_list) then
    local genesis = {
      chain_id = {
        version = pond_metadata['pond_version'],
        magic = pond_info['pond_id'],
        public = pond_info['is_public'],
        mainnet = false,
        consensus = 'dpos',
        coinbasefee = pond_metadata['coinbase_fee']
      },
      balance = {},
      bps = {}
    }

    -- generate balance list
    for _, b in pairs(pond_metadata['balance_list']) do
      local address = b['address']
      local balance = b['balance']

      genesis['balance'][address] = balance
    end

    -- generate BP list
    for i = 1, pond_metadata['bp_cnt'] do
      table.insert(genesis['bps'], bp_list[i]['bnode_metadata']['server_id'])
    end

    return genesis
  else
    return nil
  end
end

function createPond(pond_id, pond_name, is_public, metadata)
  if type(metadata) == 'string' then
    metadata = json:decode(metadata)
  end
  local metadata_raw = json:encode(metadata)
  system.print(MODULE_NAME .. "createPond: pond_id=" .. tostring(pond_id)
          .. ", pond_name=" .. tostring(pond_name)
          .. ", is_public=" .. tostring(is_public)
          .. ", metadata=" .. metadata_raw)

  local creator = system.getSender()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "createPond: creator=" .. creator .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(pond_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "createPond",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = creator,
      pond_id = pond_id
    }
  end

  -- read created Pond
  local res = getPond(pond_id)
  system.print(MODULE_NAME .. "createPond: res=" .. json:encode(res))

  local created_bnode_list = metadata['created_bnode_list']
  if nil == created_bnode_list then
    created_bnode_list = {}
  else
    metadata["created_bnode_list"] = nil
    metadata_raw = json:encode(metadata)
  end
  system.print(MODULE_NAME .. "createPond: created_bnode_list=" .. json:encode(created_bnode_list))

  if "404" == res["__status_code"] then
    -- check whether Pond is public
    local is_public_value = 0
    if is_public then
      is_public_value = 1
    else
      is_public_value = 0
    end

    __callFunction(MODULE_NAME_DB, "insert",
      "INSERT INTO horde_ponds(creator, pond_name, pond_id, is_public, pond_block_no, metadata) VALUES (?, ?, ?, ?, ?, ?)",
      creator, pond_name, pond_id, is_public_value, block_no, metadata_raw)
  end

  -- check the created BNode info from Horde
  for _, bnode in pairs(created_bnode_list) do
    local bnode_id = bnode['bnode_id']
    local bnode_name = bnode['bnode_name']
    local bnode_metadata = bnode['bnode_metadata']

    createBNode(pond_id, bnode_id, bnode_name, bnode_metadata)
  end

  -- read created all BNodes of Pond
  local res = getAllBNodes(pond_id)
  system.print(MODULE_NAME .. "createPond: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] and "404" ~= res["__status_code"] then
    return res
  end

  local pond_metadata = res['pond_metadata']

  local consensus_alg = pond_metadata['consensus_alg']
  if consensus_alg ~= nil then
    if 'dpos' == consensus_alg then
      pond_metadata['genesis_json'] = generateDposGenesisJson(res)
    elseif 'raft' == consensus_alg then
    elseif 'poa' == consensus_alg then
    elseif 'pow' == consensus_alg then
    end

    updatePond(pond_id, pond_name, is_public, pond_metadata)
  end

  -- TODO: save this activity

  -- success to write (201 Created)
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "createPond",
    __status_code = "201",
    __status_sub_code = "",
    pond_creator = res['pond_creator'],
    pond_id = res['pond_id'],
    pond_name = res['pond_name'],
    pond_metadata = pond_metadata,
    pond_block_no = res['pond_block_no'],
    is_public = res['is_public'],
    bnode_list = res['bnode_list'],
  }
end

function getPond(pond_id)
  system.print(MODULE_NAME .. "getPond: pond_id=" .. tostring(pond_id))

  local sender = system.getSender()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "getPond: sender=" .. sender .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(pond_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "addCommand",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      pond_id = pond_id,
    }
  end

  -- check inserted data
  local rows = __callFunction(MODULE_NAME_DB, "select",
    "SELECT creator, pond_name, is_public, metadata, pond_block_no FROM horde_ponds WHERE pond_id = ? ORDER BY pond_block_no", pond_id)
  local creator
  local pond_name
  local is_public
  local metadata
  local pond_block_no

  local exist = false
  for _, v in pairs(rows) do
    creator = v[1]
    pond_name = v[2]

    if 1 == v[3] then
      is_public = true
    else
      is_public = false
    end

    metadata = json:decode(v[4])
    pond_block_no = v[5]

    exist = true
  end

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getPond",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find the blockchain (" .. pond_id .. ")",
      sender = sender,
      pond_id = pond_id
    }
  end

  -- check permissions (403.2 Read access forbidden)
  if sender ~= creator then
    if not is_public then
      -- TODO: check sender's reading permission of pond
      return {
        __module = MODULE_NAME,
        __block_no = block_no,
        __func_name = "getPond",
        __status_code = "403",
        __status_sub_code = "2",
        __err_msg = "Sender (" .. sender .. ") doesn't allow to read the blockchain (" .. pond_id .. ")",
        sender = sender,
        pond_id = pond_id
      }
    end
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "getPond",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    pond_creator = creator,
    pond_id = pond_id,
    pond_name = pond_name,
    pond_metadata = metadata,
    pond_block_no = pond_block_no,
    is_public = is_public
  }
end

function deletePond(pond_id)
  system.print(MODULE_NAME .. "deletePond: pond_id=" .. tostring(pond_id))

  local sender = system.getSender()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "deletePond: sender=" .. sender .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(pond_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "addCommand",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      pond_id = pond_id,
    }
  end

  -- read created Pond
  local res = getPond(pond_id)
  if "200" ~= res["__status_code"] then
    return res
  end
  system.print(MODULE_NAME .. "deletePond: res=" .. json:encode(res))

  local creator = res["pond_creator"]

  -- check permissions (403.1 Execute access forbidden)
  if sender ~= creator then
    -- TODO: check sender's delete permission of pond
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "deletePond",
      __status_code = "403",
      __status_sub_code = "1",
      __err_msg = "Sender (" .. sender .. ") doesn't allow to delete the blockchain (" .. pond_id .. ")",
      sender = sender,
      pond_id = pond_id
    }
  end

  -- delete Pond
  __callFunction(MODULE_NAME_DB, "delete", "DELETE FROM horde_ponds WHERE pond_id = ?", pond_id)

  -- TODO: save this activity

  -- 201 Created
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "deletePond",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    pond_creator = creator,
    pond_id = pond_id,
    pond_name = res['pond_name'],
    pond_metadata = res['pond_metadata'],
    pond_block_no = res['pond_block_no'],
    is_public = res['is_public']
  }
end

function updatePond(pond_id, pond_name, is_public, metadata)
  if type(metadata) == 'string' then
    metadata = json:decode(metadata)
  end
  local metadata_raw = json:encode(metadata)
  system.print(MODULE_NAME .. "updatePond: pond_id=" .. tostring(pond_id)
          .. ", pond_name=" .. tostring(pond_name)
          .. ", is_public=" .. tostring(is_public)
          .. ", metadata=" .. metadata_raw)

  local sender = system.getSender()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "updatePond: sender=" .. sender .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(pond_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "addCommand",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      pond_id = pond_id,
    }
  end

  -- read created Pond
  local res = getPond(pond_id)
  if "200" ~= res["__status_code"] then
    return res
  end
  system.print(MODULE_NAME .. "updatePond: res=" .. json:encode(res))

  local creator = res["pond_creator"]

  -- check permissions (403.3 Write access forbidden)
  if sender ~= creator then
    -- TODO: check sender's update permission of pond
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "updatePond",
      __status_code = "403",
      __status_sub_code = "3",
      __err_msg = "Sender (" .. sender .. ") doesn't allow to update the blockchain (" .. pond_id .. ") info",
      sender = sender,
      pond_id = pond_id
    }
  end

  -- check arguments
  if isEmpty(pond_name) then
    pond_name = res["pond_name"]
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
    metadata = res["pond_metadata"]
    metadata_raw = json:encode(metadata)
  end

  __callFunction(MODULE_NAME_DB, "update",
    "UPDATE horde_ponds SET pond_name = ?, is_public = ?, metadata = ? WHERE pond_id = ?",
    pond_name, is_public_value, metadata_raw, pond_id)

  -- TODO: save this activity

  -- 201 Created
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "updatePond",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    pond_creator = creator,
    pond_id = pond_id,
    pond_name = pond_name,
    pond_metadata = metadata,
    pond_block_no = res['pond_block_no'],
    is_public = is_public
  }
end

function createBNode(pond_id, bnode_id, bnode_name, metadata)
  if type(metadata) == 'string' then
    metadata = json:decode(metadata)
  end
  local metadata_raw = json:encode(metadata)
  system.print(MODULE_NAME .. "createBNode: pond_id=" .. tostring(pond_id)
          .. ", bnode_id=" .. tostring(bnode_id)
          .. ", bnode_name=" .. tostring(bnode_name)
          .. ", metadata=" .. metadata_raw)

  local sender = system.getSender()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "createBNode: sender=" .. sender .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(pond_id) or isEmpty(bnode_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "addCommand",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      pond_id = pond_id,
      bnode_id = bnode_id,
    }
  end

  -- read created Pond
  local res = getPond(pond_id)
  system.print(MODULE_NAME .. "createBNode: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local pond_creator = res["pond_creator"]
  local is_public = res["is_public"]

  -- check permissions (403.1 Execute access forbidden)
  if sender ~= pond_creator then
    if not is_public then
      -- TODO: check sender's create BNode permission of pond
      return {
        __module = MODULE_NAME,
        __block_no = block_no,
        __func_name = "createBNode",
        __status_code = "403",
        __status_sub_code = "1",
        __err_msg = "Sender (" .. sender .. ") doesn't allow to create a new blockchain node for the blockchain (" .. pond_id .. ")",
        sender = sender,
        pond_id = pond_id
      }
    end
  end

  __callFunction(MODULE_NAME_DB, "insert",
    "INSERT INTO horde_bnodes(pond_id, creator, bnode_name, bnode_id, bnode_block_no, metadata) VALUES (?, ?, ?, ?, ?, ?)",
    pond_id, sender, bnode_name, bnode_id, block_no, metadata_raw)

  -- TODO: save this activity

  -- success to write (201 Created)
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "createBNode",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    pond_creator = pond_creator,
    pond_id = pond_id,
    pond_name = res['pond_name'],
    pond_metadata = res['pond_metadata'],
    pond_block_no = res['pond_block_no'],
    is_public = is_public,
    bnode_list = {
      {
        bnode_creator = sender,
        bnode_name = bnode_name,
        bnode_id = bnode_id,
        bnode_metadata = metadata,
        bnode_block_no = block_no
      }
    }
  }
end

function getAllBNodes(pond_id)
  system.print(MODULE_NAME .. "getAllBNodes: pond_id=" .. tostring(pond_id))

  local sender = system.getSender()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "getAllBNodes: sender=" .. sender .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(pond_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "addCommand",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      pond_id = pond_id,
    }
  end

  -- read created Pond
  local res = getPond(pond_id)
  system.print(MODULE_NAME .. "getAllBNodes: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local pond_creator = res["pond_creator"]
  local pond_name = res["pond_name"]
  local is_public = res["is_public"]
  local pond_metadata = res["pond_metadata"]
  local pond_block_no = res["pond_block_no"]

  -- check inserted data
  local rows = __callFunction(MODULE_NAME_DB, "select",
    [[SELECT creator, bnode_id, bnode_name, metadata, bnode_block_no
        FROM horde_bnodes
        WHERE pond_id = ? ORDER BY bnode_block_no]],
    pond_id)

  local bnode_list = {}

  local exist = false
  for _, v in pairs(rows) do
    local bnode = {
      bnode_creator = v[1],
      bnode_id = v[2],
      bnode_name = v[3],
      bnode_metadata = json:decode(v[4]),
      bnode_block_no = v[5]
    }
    table.insert(bnode_list, bnode)

    exist = true
  end

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getAllBNodes",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find any blockchain (" .. pond_id .. ") node info",
      sender = sender,
      pond_creator = pond_creator,
      pond_id = pond_id,
      pond_name = pond_name,
      pond_metadata = pond_metadata,
      pond_block_no = pond_block_no,
      is_public = is_public
    }
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "getAllBNodes",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    pond_creator = pond_creator,
    pond_id = pond_id,
    pond_name = pond_name,
    pond_metadata = pond_metadata,
    pond_block_no = pond_block_no,
    is_public = is_public,
    bnode_list = bnode_list
  }
end

function getBNode(pond_id, bnode_id)
  system.print(MODULE_NAME .. "getBNode: pond_id=" .. tostring(pond_id)
          .. ", bnode_id=" .. tostring(bnode_id))

  local sender = system.getSender()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "getBNode: sender=" .. sender .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(pond_id) or isEmpty(bnode_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "addCommand",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      pond_id = pond_id,
      bnode_id = bnode_id,
    }
  end

  -- read created Pond
  local res = getPond(pond_id)
  system.print(MODULE_NAME .. "getBNode: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local pond_creator = res["pond_creator"]
  local pond_name = res["pond_name"]
  local is_public = res["is_public"]
  local pond_metadata = res["pond_metadata"]
  local pond_block_no = res["pond_block_no"]

  -- check inserted data
  local rows = __callFunction(MODULE_NAME_DB, "select",
    [[SELECT creator, bnode_name, metadata, bnode_block_no
        FROM horde_bnodes
        WHERE pond_id = ? AND bnode_id = ?
        ORDER BY bnode_block_no]],
    pond_id, bnode_id)

  local bnode_list = {}

  local exist = false
  for _, v in pairs(rows) do
    local bnode = {
      bnode_id = bnode_id,
      bnode_creator = v[1],
      bnode_name = v[2],
      bnode_metadata = json:decode(v[3]),
      bnode_block_no = v[4]
    }
    table.insert(bnode_list, bnode)

    exist = true
  end

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getBNode",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find the blockchain (" .. pond_id .. ") node (" .. bnode_id .. ") info",
      sender = sender,
      pond_creator = pond_creator,
      pond_id = pond_id,
      pond_name = pond_name,
      pond_metadata = pond_metadata,
      pond_block_no = pond_block_no,
      is_public = is_public,
      bnode_id = bnode_id
    }
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "getBNode",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    pond_creator = pond_creator,
    pond_id = pond_id,
    pond_name = pond_name,
    pond_metadata = pond_metadata,
    pond_block_no = pond_block_no,
    is_public = is_public,
    bnode_list = bnode_list
  }
end

function deleteBNode(pond_id, bnode_id)
  system.print(MODULE_NAME .. "deleteBNode: pond_id=" .. tostring(pond_id)
          .. ", bnode_id=" .. tostring(bnode_id))

  local sender = system.getSender()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "deleteBNode: sender=" .. sender .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(pond_id) or isEmpty(bnode_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "addCommand",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      pond_id = pond_id,
      bnode_id = bnode_id,
    }
  end

  -- read created BNode
  local res = getBNode(pond_id, bnode_id)
  system.print(MODULE_NAME .. "deleteBNode: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local pond_creator = res["pond_creator"]
  local bnode_info = res["bnode_list"][1]
  local bnode_creator = bnode_info["bnode_creator"]

  -- check permissions (403.1 Execute access forbidden)
  if sender ~= pond_creator then
    if sender ~= bnode_creator then
      -- TODO: check sender's delete permission of pond
      return {
        __module = MODULE_NAME,
        __block_no = block_no,
        __func_name = "deleteBNode",
        __status_code = "403",
        __status_sub_code = "1",
        __err_msg = "Sender (" .. sender .. ") doesn't allow to delete the blockchain (" .. pond_id .. ") node",
        sender = sender,
        pond_id = pond_id,
        bnode_id = bnode_id
      }
    end
  end

  -- delete BNode
  __callFunction(MODULE_NAME_DB, "delete",
    "DELETE FROM horde_bnodes WHERE pond_id = ? AND bnode_id = ?", pond_id, bnode_id)

  -- TODO: save this activity

  -- 201 Created
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "deleteBNode",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    pond_creator = pond_creator,
    pond_id = pond_id,
    pond_name = res["pond_name"],
    pond_metadata = res["pond_metadata"],
    pond_block_no = res['pond_block_no'],
    is_public = res["is_public"],
    bnode_list = res["bnode_list"]
  }
end

function updateBNode(pond_id, bnode_id, bnode_name, metadata)
  if type(metadata) == 'string' then
    metadata = json:decode(metadata)
  end
  local metadata_raw = json:encode(metadata)
  system.print(MODULE_NAME .. "updateBNode: pond_id=" .. tostring(pond_id)
          .. ", bnode_id=" .. tostring(bnode_id)
          .. ", bnode_name=" .. tostring(bnode_name)
          .. ", metadata=" .. metadata_raw)

  local sender = system.getSender()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "updateBNode: sender=" .. sender .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(pond_id) or isEmpty(bnode_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "addCommand",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      pond_id = pond_id,
      bnode_id = bnode_id,
    }
  end

  -- read created BNode
  local res = getBNode(pond_id, bnode_id)
  system.print(MODULE_NAME .. "updateBNode: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local pond_creator = res["pond_creator"]
  local bnode_info = res["bnode_list"][1]
  local bnode_creator = bnode_info["bnode_creator"]

  -- check permissions (403.3 Write access forbidden)
  if sender ~= pond_creator then
    if sender ~= bnode_creator then
      -- TODO: check sender's update permission of pond
      return {
        __module = MODULE_NAME,
        __block_no = block_no,
        __func_name = "updateBNode",
        __status_code = "403",
        __status_sub_code = "3",
        __err_msg = "Sender (" .. sender .. ") doesn't allow to update the blockchain (" .. pond_id .. ") node info",
        sender = sender,
        pond_id = pond_id,
        bnode_id = bnode_id
      }
    end
  end

  -- check arguments
  if isEmpty(bnode_name) then
    bnode_name = bnode_info["bnode_name"]
  end
  if nil == metadata or isEmpty(metadata_raw) then
    metadata = bnode_info["bnode_metadata"]
    metadata_raw = json:encode(metadata)
  end

  __callFunction(MODULE_NAME_DB, "update",
    "UPDATE horde_bnodes SET bnode_name = ?, metadata = ? WHERE pond_id = ? AND bnode_id = ?",
    bnode_name, metadata_raw, pond_id, bnode_id)

  -- TODO: save this activity

  -- 201 Created
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "updateBNode",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    pond_creator = pond_creator,
    pond_id = pond_id,
    pond_name = res["pond_name"],
    pond_metadata = res["pond_metadata"],
    pond_block_no = res['pond_block_no'],
    is_public = res["is_public"],
    bnode_list = {
      {
        bnode_creator = bnode_creator,
        bnode_name = bnode_name,
        bnode_id = bnode_id,
        bnode_metadata = metadata,
        bnode_block_no = bnode_info['bnode_block_no']
      }
    }
  }
end

-- exposed functions
abi.register(createPond, getPond, deletePond, updatePond, createBNode, getAllBNodes, getBNode, deleteBNode, updateBNode)
