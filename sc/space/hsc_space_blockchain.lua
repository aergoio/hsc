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
    creator     TEXT NOT NULL,
    pond_name   TEXT,
    pond_id     TEXT NOT NULL,
    is_public   INTEGER DEFAULT 0,
    metadata    TEXT,
    PRIMARY KEY (pond_id)
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

  -- create BNode metadata table
  --    * metadata = [cnode_info,]
  __callFunction(MODULE_NAME_DB, "createTable", [[CREATE TABLE IF NOT EXISTS horde_bnodes(
    pond_id       TEXT NOT NULL,
    creator       TEXT NOT NULL,
    bnode_name    TEXT,
    bnode_id      TEXT NOT NULL,
    metadata      TEXT,
    PRIMARY KEY (pond_id, bnode_id),
    FOREIGN KEY (pond_id) REFERENCES horde_ponds(pond_id)
      ON DELETE CASCADE ON UPDATE NO ACTION
  )]])
end

local function isEmpty(v)
  return nil == v or 0 == string.len(v)
end

function createPond(pond_id, pond_name, is_public, metadata)
  -- TODO: report JSON type argument is not accepted for delegate call
  metadata = json:decode(metadata)
  local metadataRaw = json:encode(metadata)
  system.print(MODULE_NAME .. "createPond: pond_id=" .. pond_id .. ", pond_name=" .. pond_name .. ", is_public=" .. tostring(is_public) .. ", metadata=" .. metadataRaw)

  local creator = system.getSender()
  system.print(MODULE_NAME .. "createPond: creator=" .. creator)

  -- default is public
  if is_public then
    is_public = 1
  else
    is_public = 0
  end

  __callFunction(MODULE_NAME_DB, "insert",
    "INSERT INTO horde_ponds(creator, pond_name, pond_id, is_public, metadata) VALUES (?, ?, ?, ?, ?)",
    creator, pond_name, pond_id, is_public, metadataRaw)

  -- TODO: save this activity

  -- success to write (201 Created)
  return {
    __module = MODULE_NAME,
    __func_name = "createPond",
    __status_code = "201",
    __status_sub_code = "",
    pond_creator = creator,
    pond_id = pond_id,
    pond_name = pond_name,
    pond_metadata = metadata,
    is_public = is_public
  }
end

function getPond(pond_id)
  system.print(MODULE_NAME .. "getPond: pond_id=" .. pond_id)

  -- check inserted data
  local rows = __callFunction(MODULE_NAME_DB, "select",
    "SELECT creator, pond_name, is_public, metadata FROM horde_ponds WHERE pond_id = ?", pond_id)
  local creator
  local pond_name
  local is_public
  local metadata

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

    exist = true
  end

  local sender = system.getSender()

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
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
    __func_name = "getPond",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    pond_creator = creator,
    pond_id = pond_id,
    pond_name = pond_name,
    pond_metadata = metadata,
    is_public = is_public
  }
end

function deletePond(pond_id)
  system.print(MODULE_NAME .. "deletePond: pond_id=" .. pond_id)

  -- read created Pond
  local res = getPond(pond_id)
  if "200" ~= res["__status_code"] then
    return res
  end
  system.print(MODULE_NAME .. "deletePond: res=" .. json:encode(res))

  local creator = res["pond_creator"]
  local pond_name = res["pond_name"]
  local is_public = res["is_public"]
  local metadata = res["pond_metadata"]

  -- check permissions (403.1 Execute access forbidden)
  local sender = system.getSender()
  if sender ~= creator then
    -- TODO: check sender's delete permission of pond
    return {
      __module = MODULE_NAME,
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
    __func_name = "deletePond",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    pond_creator = creator,
    pond_id = pond_id,
    pond_name = pond_name,
    pond_metadata = metadata,
    is_public = is_public
  }
end

function updatePond(pond_id, pond_name, is_public, metadata)
  -- TODO: report JSON type argument is not accepted for delegate call
  metadata = json:decode(metadata)
  local metadataRaw = json:encode(metadata)
  system.print(MODULE_NAME .. "updatePond: pond_id=" .. pond_id .. ", pond_name=" .. tostring(pond_name) .. ", is_public=" .. tostring(is_public) .. ", metadata=" .. tostring(metadataRaw))

  -- read created Pond
  local res = getPond(pond_id)
  if "200" ~= res["__status_code"] then
    return res
  end
  system.print(MODULE_NAME .. "updatePond: res=" .. json:encode(res))

  local creator = res["pond_creator"]

  -- check permissions (403.3 Write access forbidden)
  local sender = system.getSender()
  if sender ~= creator then
    -- TODO: check sender's update permission of pond
    return {
      __module = MODULE_NAME,
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
  else
    if is_public then
      is_public = 1
    else
      is_public = 0
    end
  end
  if isEmpty(metadataRaw) then
    metadata = res["pond_metadata"]
    metadataRaw = json:encode(metadata)
  end

  __callFunction(MODULE_NAME_DB, "update",
    "UPDATE horde_ponds SET pond_name = ?, is_public = ?, metadata = ? WHERE pond_id = ?",
    pond_name, is_public, metadataRaw, pond_id)

  -- TODO: save this activity

  -- 201 Created
  return {
    __module = MODULE_NAME,
    __func_name = "updatePond",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    pond_creator = creator,
    pond_id = pond_id,
    pond_name = pond_name,
    pond_metadata = metadata,
    is_public = is_public
  }
end

function createBNode(pond_id, bnode_id, bnode_name, metadata)
  -- TODO: report JSON type argument is not accepted for delegate call
  metadata = json:decode(metadata)
  local metadataRaw = json:encode(metadata)
  system.print(MODULE_NAME .. "createBNode: pond_id=" .. pond_id .. ", bnode_id=" .. bnode_id .. ", bnode_name=" .. bnode_name .. ", metadata=" .. metadataRaw)

  -- read created Pond
  local res = getPond(pond_id)
  if "200" ~= res["__status_code"] then
    return res
  end
  system.print(MODULE_NAME .. "createBNode: res=" .. json:encode(res))

  local pond_creator = res["pond_creator"]
  local is_public = res["is_public"]

  local sender = system.getSender()
  system.print(MODULE_NAME .. "createBNode: sender=" .. sender)

  -- check permissions (403.1 Execute access forbidden)
  if sender ~= pond_creator then
    if not is_public then
      -- TODO: check sender's create BNode permission of pond
      return {
        __module = MODULE_NAME,
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
    "INSERT INTO horde_bnodes(pond_id, creator, bnode_name, bnode_id, metadata) VALUES (?, ?, ?, ?, ?)",
    pond_id, sender, bnode_name, bnode_id, metadataRaw)

  -- TODO: save this activity

  local pond_name = res["pond_name"]
  local pond_metadata = res["pond_metadata"]

  -- success to write (201 Created)
  return {
    __module = MODULE_NAME,
    __func_name = "createBNode",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    pond_creator = pond_creator,
    pond_id = pond_id,
    pond_name = pond_name,
    pond_metadata = pond_metadata,
    is_public = is_public,
    bnode_list = {
      {
        bnode_creator = sender,
        bnode_name = bnode_name,
        bnode_id = bnode_id,
        bnode_metadata = metadata
      }
    }
  }
end

function getAllBNodes(pond_id)
  system.print(MODULE_NAME .. "getAllBNodes: pond_id=" .. pond_id)

  -- read created Pond
  local res = getPond(pond_id)
  if "200" ~= res["__status_code"] then
    return res
  end
  system.print(MODULE_NAME .. "getAllBNodes: res=" .. json:encode(res))

  local pond_creator = res["pond_creator"]
  local pond_name = res["pond_name"]
  local is_public = res["is_public"]
  local pond_metadata = res["pond_metadata"]

  -- check inserted data
  local rows = __callFunction(MODULE_NAME_DB, "select",
    "SELECT creator, bnode_id, bnode_name, metadata FROM horde_bnodes WHERE pond_id = ?", pond_id)

  local bnode_list = {}

  local exist = false
  for _, v in pairs(rows) do
    local bnode = {
      bnode_creator = v[1],
      bnode_id = v[2],
      bnode_name = v[3],
      bnode_metadata = json:decode(v[4])
    }
    table.insert(bnode_list, bnode)

    exist = true
  end

  local sender = system.getSender()

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __func_name = "getBNode",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find any blockchain (" .. pond_id .. ") node info",
      sender = sender,
      pond_creator = pond_creator,
      pond_id = pond_id,
      pond_name = pond_name,
      pond_metadata = pond_metadata,
      is_public = is_public
    }
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __func_name = "getBNode",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    pond_creator = pond_creator,
    pond_id = pond_id,
    pond_name = pond_name,
    pond_metadata = pond_metadata,
    is_public = is_public,
    bnode_list = bnode_list
  }
end

function getBNode(pond_id, bnode_id)
  system.print(MODULE_NAME .. "getBNode: pond_id=" .. pond_id .. ", bnode_id=" .. bnode_id)

  -- read created Pond
  local res = getPond(pond_id)
  if "200" ~= res["__status_code"] then
    return res
  end
  system.print(MODULE_NAME .. "getBNode: res=" .. json:encode(res))

  local pond_creator = res["pond_creator"]
  local pond_name = res["pond_name"]
  local is_public = res["is_public"]
  local pond_metadata = res["pond_metadata"]

  -- check inserted data
  local rows = __callFunction(MODULE_NAME_DB, "select",
    "SELECT creator, bnode_name, metadata FROM horde_bnodes WHERE pond_id = ? AND bnode_id = ?", pond_id, bnode_id)

  local bnode_list = {}

  local exist = false
  for _, v in pairs(rows) do
    local bnode = {
      bnode_id = bnode_id,
      bnode_creator = v[1],
      bnode_name = v[2],
      bnode_metadata = json:decode(v[3])
    }
    table.insert(bnode_list, bnode)

    exist = true
  end

  local sender = system.getSender()

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __func_name = "getBNode",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find the blockchain (" .. pond_id .. ") node (" .. bnode_id .. ") info",
      sender = sender,
      pond_creator = pond_creator,
      pond_id = pond_id,
      pond_name = pond_name,
      pond_metadata = pond_metadata,
      is_public = is_public,
      bnode_id = bnode_id
    }
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __func_name = "getBNode",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    pond_creator = pond_creator,
    pond_id = pond_id,
    pond_name = pond_name,
    pond_metadata = pond_metadata,
    is_public = is_public,
    bnode_list = bnode_list
  }
end

function deleteBNode(pond_id, bnode_id)
  system.print(MODULE_NAME .. "deleteBNode: pond_id=" .. pond_id .. ", bnode_id=" .. bnode_id)

  -- read created BNode
  local res = getBNode(pond_id, bnode_id)
  if "200" ~= res["__status_code"] then
    return res
  end
  system.print(MODULE_NAME .. "deleteBNode: res=" .. json:encode(res))

  local pond_creator = res["pond_creator"]
  local bnode_info = res["bnode_list"][1]
  local bnode_creator = bnode_info["bnode_creator"]

  -- check permissions (403.1 Execute access forbidden)
  local sender = system.getSender()
  if sender ~= pond_creator then
    if sender ~= bnode_creator then
      -- TODO: check sender's delete permission of pond
      return {
        __module = MODULE_NAME,
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
    __func_name = "deleteBNode",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    pond_creator = pond_creator,
    pond_id = pond_id,
    pond_name = res["pond_name"],
    pond_metadata = res["pond_metadata"],
    is_public = res["is_public"],
    bnode_list = res["bnode_list"]
  }
end

function updateBNode(pond_id, bnode_id, bnode_name, metadata)
  -- TODO: report JSON type argument is not accepted for delegate call
  metadata = json:decode(metadata)
  local metadataRaw = json:encode(metadata)
  system.print(MODULE_NAME .. "updateBNode: pond_id=" .. pond_id .. ", bnode_id=" .. bnode_id .. ", bnode_name=" .. tostring(bnode_name) .. ", metadata=" .. tostring(metadataRaw))

  -- read created BNode
  local res = getBNode(pond_id, bnode_id)
  if "200" ~= res["__status_code"] then
    return res
  end
  system.print(MODULE_NAME .. "updateBNode: res=" .. json:encode(res))

  local pond_creator = res["pond_creator"]
  local bnode_info = res["bnode_list"][1]
  local bnode_creator = bnode_info["bnode_creator"]

  -- check permissions (403.3 Write access forbidden)
  local sender = system.getSender()
  if sender ~= pond_creator then
    if sender ~= bnode_creator then
      -- TODO: check sender's update permission of pond
      return {
        __module = MODULE_NAME,
        __func_name = "updateBNode",
        __status_code = "403",
        __status_sub_code = "3",
        __err_msg = "Sender (" .. sender .. ") doesn't allow to update the blockchain (" .. pond_id .. ") node info",
        sender = sender,
        pond_creator = pond_creator,
        bnode_creator = bnode_creator,
        pond_id = pond_id,
        bnode_id = bnode_id
      }
    end
  end

  -- check arguments
  if isEmpty(bnode_name) then
    bnode_name = bnode_info["bnode_name"]
  end
  if isEmpty(metadataRaw) then
    metadata = bnode_info["bnode_metadata"]
    metadataRaw = json:encode(metadata)
  end

  __callFunction(MODULE_NAME_DB, "update",
    "UPDATE horde_bnodes SET bnode_name = ?, metadata = ? WHERE pond_id = ? AND bnode_id = ?",
    bnode_name, metadataRaw, pond_id, bnode_id)

  -- TODO: save this activity

  -- 201 Created
  return {
    __module = MODULE_NAME,
    __func_name = "updateBNode",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    pond_creator = pond_creator,
    pond_id = pond_id,
    pond_name = res["pond_name"],
    pond_metadata = res["pond_metadata"],
    is_public = res["is_public"],
    bnode_list = {
      {
        bnode_creator = bnode_creator,
        bnode_name = bnode_name,
        bnode_id = bnode_id,
        bnode_metadata = metadata
      }
    }
  }
end

-- exposed functions
abi.register(createPond, getPond, deletePond, updatePond, createBNode, getAllBNodes, getBNode, deleteBNode, updateBNode)
