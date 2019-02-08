--
-- Horde Smart Contract (HSC): Pond (Deployed Blockchain)
--

MODULE_NAME = "__HSC_POND__"

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
  __callFunction(MODULE_NAME_DB, "createTable", [[CREATE TABLE IF NOT EXISTS pond_meta(
    sender TEXT,
    pond_id TEXT,
    cmd_id TEXT,
    metadata TEXT,
    PRIMARY KEY (sender, pond_id)
  )]])

  -- create BNode list of Pond table
  __callFunction(MODULE_NAME_DB, "createTable", [[CREATE TABLE IF NOT EXISTS pond_bnode_list(
    pond_id     TEXT NOT NULL,
    bnode_id    TEXT NOT NULL,
    horde_id    TEXT NOT NULL,
    cnode_id    TEXT NOT NULL,
    rpc_url     TEXT,
    p2p_url     TEXT,
    profile_url TEXT,
    rest_url    TEXT,
    create_time INTEGER DEFAULT NULL,
    start_time  INTEGER DEFAULT NULL,
    PRIMARY KEY (pond_id, bnode_id)
  )]])

  -- create Pond command history table
  __callFunction(MODULE_NAME_DB, "createTable", [[CREATE TABLE IF NOT EXISTS pond_history_cmd(
    sender TEXT,
    pond_id TEXT,
    cmd_id TEXT,
    prev_cmd_id TEXT,
    FOREIGN KEY (sender, pond_id) REFERENCES pond_meta(sender, pond_id)
      ON DELETE CASCADE ON UPDATE NO ACTION,
    FOREIGN KEY (cmd_id) REFERENCES command(cmd_id)
      ON DELETE CASCADE ON UPDATE NO ACTION
  )]])

  -- create Pond metadata history table
  __callFunction(MODULE_NAME_DB, "createTable", [[CREATE TABLE IF NOT EXISTS pond_history_metadata(
    sender TEXT,
    pond_id TEXT,
    metadata TEXT,
    timestamp TEXT,
    FOREIGN KEY (sender, pond_id) REFERENCES pond_meta(sender, pond_id)
      ON DELETE CASCADE ON UPDATE NO ACTION
  )]])
end

function insertPond(sender, pond_id, cmd_id, metadata)
  system.print(MODULE_NAME .. "insertPond: sender=" .. sender .. ", pond_id=" .. pond_id .. ", cmd_id=" .. cmd_id .. ", metadata=" .. json:encode(metadata))

  local rows = __callFunction(MODULE_NAME_DB, "select",
                              "SELECT cmd_id, metadata FROM pond_meta WHERE sender = ? AND pond_id = ?",
                              sender, pond_id)
  local total_meta = {}
  for _, v in pairs(rows) do
    local db_cmd_id = v[1]
    local db_metadata = v[2]

    if db_cmd_id ~= cmd_id then
      -- update command history
      __callFunction(MODULE_NAME_DB, "insert",
                     "INSERT INTO pond_history_cmd(sender, pond_id, cmd_id, prev_cmd_id) VALUES (?, ?, ?, ?)",
                     sender, pond_id, cmd_id, db_cmd_id)
    end

    if nil ~= db_metadata then
      total_meta = json:decode(db_metadata)
    end
  end

  if nil ~= metadata then
    -- update metadata
    for k, v in pairs(json:decode(metadata)) do
      total_meta[k] = v
    end
  end

  __callFunction(MODULE_NAME_DB, "insert",
                 "INSERT INTO pond_meta(sender, pond_id, cmd_id, metadata) VALUES (?, ?, ?, ?)",
                 sender, pond_id, cmd_id, json:encode(total_meta))

  if nil ~= metadata then
    -- update metadata history
    __callFunction(MODULE_NAME_DB, "insert",
                   "INSERT INTO pond_history_metadata(sender, pond_id, metadata, timestamp) VALUES (?, ?, ?, ?)",
                   sender, pond_id, metadata, system.getTimestamp())
  end
end

function queryPonds(sender, pond_id)
  system.print(MODULE_NAME .. "queryPonds: sender=" .. sender .. ", pond_id=" .. tostring(pond_id))

  local rows
  if nil == pond_id then
      rows = __callFunction(MODULE_NAME_DB, "select", "SELECT pond_id, cmd_id, metadata FROM pond_meta WHERE sender = ?", sender)
  else
      rows = __callFunction(MODULE_NAME_DB, "select", "SELECT pond_id, cmd_id, metadata FROM pond_meta WHERE sender = ? AND pond_id = ?", sender, pond_id)
  end

  local result = {
    sender=sender,
    pond_list={}
  }

  for _, v in pairs(rows) do
    local item = {
      pond_id = v[1],
      cmd_id = v[2],
      metadata = v[3],
    }
    table.insert(result.pond_list, item)
  end

  system.print("result=" .. json:encode(result))

  return result
end

function insertBNode(pond_id, bnode_id, horde_id, cnode_id, rpc_url, p2p_url, profile_url, rest_url, create_time)
  system.print(MODULE_NAME .. "insertBNode: pond_id=" .. pond_id .. ", bnode_id=" .. bnode_id .. ", horde_id=" .. horde_id .. ", cnode_id=" .. cnode_id .. ", rpc_url=" .. rpc_url .. ", p2p_url=" .. p2p_url .. ", profile_url=" .. profile_url .. ", rest_url=" .. rest_url .. ", create_time=" .. create_time)

  __callFunction(MODULE_NAME_DB, "insert",
                 [[INSERT INTO pond_bnode_list(
                      pond_id, 
                      bnode_id, 
                      horde_id, 
                      cnode_id, 
                      rpc_url, 
                      p2p_url, 
                      profile_url, 
                      rest_url,
                      create_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]],
                 pond_id, bnode_id, horde_id, cnode_id, rpc_url, p2p_url, profile_url, rest_url, create_time)
end

function updateBNode(pond_id, bnode_id, horde_id, cnode_id, rpc_url, p2p_url, profile_url, rest_url, start_time)
  system.print(MODULE_NAME .. "insertBNode: pond_id=" .. pond_id .. ", bnode_id=" .. bnode_id .. ", horde_id=" .. horde_id .. ", cnode_id=" .. cnode_id .. ", rpc_url=" .. rpc_url .. ", p2p_url=" .. p2p_url .. ", profile_url=" .. profile_url .. ", rest_url=" .. rest_url .. ", start_time=" .. start_time)

  __callFunction(MODULE_NAME_DB, "update",
                 [[UPDATE pond_bnode_list
                    SET horde_id = ?,
                      cnode_id = ?,
                      rpc_url = ?,
                      p2p_url = ?,
                      profile_url = ?,
                      rest_url = ?,
                      start_time = ?
                    WHERE pond_id = ? AND bnode_id = ?]],
                 horde_id, cnode_id, rpc_url, p2p_url, profile_url, rest_url, start_time, pond_id, bnode_id)
end

function queryBNodeList(pond_id)
  system.print(MODULE_NAME .. "queryBNodeList: pond_id=" .. pond_id)

  local rows = __callFunction(MODULE_NAME_DB, "select", 
                              [[SELECT 
                                    bnode_id,
                                    horde_id,
                                    cnode_id,
                                    rpc_url,
                                    p2p_url,
                                    profile_url,
                                    rest_url,
                                    create_time,
                                    start_time
                                  FROM pond_bnode_list WHERE pond_id = ?]],
                              pond_id)

  local bnode_list = {}

  for _, v in pairs(rows) do
    local item = {
      bnode_id = v[1],
      horde_id = v[2],
      cnode_id = v[3],
      rcp_url = v[4],
      p2p_url = v[5],
      profile_url = v[6],
      rest_url = v[7],
      create_time = v[8],
      start_time = v[9],
    }
    table.insert(bnode_list, item)
  end

  system.print("bnode_list=" .. json:encode(bnode_list))

  return {
    __module = MODULE_NAME,
    __func_name = "queryBNodeList",
    bnode_list = bnode_list
  }
end

abi.register(insertPond, queryPonds, insertBNode, queryBNodeList)
