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

  -- create Horde master metadata table for CNodes
  __callFunction(MODULE_NAME_DB, "createTable", [[CREATE TABLE IF NOT EXISTS hordes(
    horde_owner TEXT NOT NULL,
    horde_name  TEXT,
    horde_id    TEXT NOT NULL,
    is_public   INTEGER DEFAULT 0,
    metadata    TEXT,
    PRIMARY KEY (horde_id)
  )]])

  -- create Horde CNode metadata table
  __callFunction(MODULE_NAME_DB, "createTable", [[CREATE TABLE IF NOT EXISTS horde_cnodes(
    horde_id    TEXT NOT NULL,
    cnode_owner TEXT NOT NULL,
    cnode_name  TEXT,
    cnode_id    TEXT NOT NULL,
    metadata    TEXT,
    PRIMARY KEY(horde_id, cnode_id),
    FOREIGN KEY(horde_id) REFERENCES hordes(horde_id)
      ON DELETE CASCADE ON UPDATE NO ACTION
  )]])

  -- create Horde CNode containers information table
  __callFunction(MODULE_NAME_DB, "createTable", [[CREATE TABLE IF NOT EXISTS horde_cnode_containers(
    horde_id        TEXT NOT NULL,
    cnode_id        TEXT NOT NULL,
    container_id    TEXT NOT NULL,
    container_info  TEXT,
    PRIMARY KEY(horde_id, cnode_id, container_id),
    FOREIGN KEY(horde_id, cnode_id) REFERENCES horde_cnodes(horde_id, cnode_id)
      ON DELETE CASCADE ON UPDATE NO ACTION
  )]])
end

local function isEmpty(v)
  return nil == v or 0 == string.len(v)
end

function addHorde(horde_id, horde_name, is_public, metadata)
  -- TODO: report JSON type argument is not accepted for delegate call
  metadata = json:decode(metadata)
  local metadataRaw = json:encode(metadata)
  system.print(MODULE_NAME .. "addHorde: horde_id=" .. horde_id .. ", horde_name=" .. horde_name .. ", is_public=" .. tostring(is_public) .. ", metadata=" .. metadataRaw)

  local horde_owner = system.getSender()
  system.print(MODULE_NAME .. "addHorde: horde_owner=" .. horde_owner)

  -- default is public
  if is_public then
    is_public = 1
  else
    is_public = 0
  end

  __callFunction(MODULE_NAME_DB, "insert",
    "INSERT INTO hordes(horde_owner, horde_name, horde_id, is_public, metadata) VALUES (?, ?, ?, ?, ?)",
    horde_owner, horde_name, horde_id, is_public, metadataRaw)

  -- TODO: save this activity

  -- success to write (201 Created)
  return {
    __module = MODULE_NAME,
    __func_name = "addHorde",
    __status_code = "201",
    __status_sub_code = "",
    horde_owner = horde_owner,
    horde_id = horde_id,
    horde_name = horde_name,
    horde_metadata = metadata,
    is_public = is_public
  }
end

function getHorde(horde_id)
  system.print(MODULE_NAME .. "getHorde: horde_id=" .. horde_id)

  -- check registered Horde
  local rows = __callFunction(MODULE_NAME_DB, "select",
    "SELECT horde_owner, horde_name, is_public, metadata FROM hordes WHERE horde_id = ?", horde_id)
  local horde_owner
  local horde_name
  local is_public
  local metadata

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

    exist = true
  end

  local sender = system.getSender()

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __func_name = "getHorde",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find the computing group (" .. horde_id .. ")",
      sender = sender,
      horde_id = horde_id
    }
  end

  -- check permissions (403.2 Read access forbidden)
  if sender ~= horde_owner then
    if not is_public then
      -- TODO: check sender's reading permission of horde
      return {
        __module = MODULE_NAME,
        __func_name = "getHorde",
        __status_code = "403",
        __status_sub_code = "2",
        __err_msg = "Sender (" .. sender .. ") doesn't allow to read the computing group (" .. horde_id .. ")",
        sender = sender,
        horde_id = horde_id
      }
    end
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __func_name = "getHorde",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    horde_owner = horde_owner,
    horde_id = horde_id,
    horde_name = horde_name,
    horde_metadata = metadata,
    is_public = is_public
  }
end

function dropHorde(horde_id)
  system.print(MODULE_NAME .. "dropHorde: horde_id=" .. horde_id)

  -- read registered Horde
  local res = getHorde(horde_id)
  if "200" ~= res["__status_code"] then
    return res
  end
  system.print(MODULE_NAME .. "dropHorde: res=" .. json:encode(res))

  local horde_owner = res["horde_owner"]
  local horde_name = res["horde_name"]
  local is_public = res["is_public"]
  local metadata = res["horde_metadata"]

  -- check permissions (403.1 Execute access forbidden)
  local sender = system.getSender()
  if sender ~= horde_owner then
    -- TODO: check sender's deregister (drop) permission of horde
    return {
      __module = MODULE_NAME,
      __func_name = "dropHorde",
      __status_code = "403",
      __status_sub_code = "1",
      __err_msg = "Sender (" .. sender .. ") doesn't allow to deregister the computing group (" .. horde_id .. ")",
      sender = sender,
      horde_id = horde_id
    }
  end

  --
  __callFunction(MODULE_NAME_DB, "delete", "DELETE FROM hordes WHERE horde_id = ?", horde_id)

  -- TODO: save this activity

  -- 201 Created
  return {
    __module = MODULE_NAME,
    __func_name = "dropHorde",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    horde_owner = horde_owner,
    horde_id = horde_id,
    horde_name = horde_name,
    horde_metadata = metadata,
    is_public = is_public
  }
end

function updateHorde(horde_id, horde_name, is_public, metadata)
  -- TODO: report JSON type argument is not accepted for delegate call
  metadata = json:decode(metadata)
  local metadataRaw = json:encode(metadata)
  system.print(MODULE_NAME .. "updateHorde: horde_id=" .. horde_id .. ", horde_name=" .. tostring(horde_name) .. ", is_public=" .. tostring(is_public) .. ", metadata=" .. tostring(metadataRaw))

  -- read registered Horde
  local res = getHorde(horde_id)
  if "200" ~= res["__status_code"] then
    return res
  end
  system.print(MODULE_NAME .. "updateHorde: res=" .. json:encode(res))

  local horde_owner = res["horde_owner"]

  -- check permissions (403.3 Write access forbidden)
  local sender = system.getSender()
  if sender ~= horde_owner then
    -- TODO: check sender's update permission of Horde
    return {
      __module = MODULE_NAME,
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
  else
    if is_public then
      is_public = 1
    else
      is_public = 0
    end
  end
  if isEmpty(metadataRaw) then
    metadata = res["horde_metadata"]
    metadataRaw = json:encode(metadata)
  end

  __callFunction(MODULE_NAME_DB, "update",
    "UPDATE hordes SET horde_name = ?, is_public = ?, metadata = ? WHERE horde_id = ?",
    horde_name, is_public, metadataRaw, horde_id)

  -- TODO: save this activity

  -- 201 Created
  return {
    __module = MODULE_NAME,
    __func_name = "updateHorde",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    horde_owner = horde_owner,
    horde_id = horde_id,
    horde_name = horde_name,
    horde_metadata = metadata,
    is_public = is_public
  }
end

function addCNode(horde_id, cnode_id, cnode_name, metadata)
  -- TODO: report JSON type argument is not accepted for delegate call
  metadata = json:decode(metadata)
  local metadataRaw = json:encode(metadata)
  system.print(MODULE_NAME .. "addCNode: horde_id=" .. horde_id .. ", cnode_id=" .. cnode_id .. ", cnode_name=" .. cnode_name .. ", metadata=" .. metadataRaw)

  -- read registered Horde
  local res = getHorde(horde_id)
  if "200" ~= res["__status_code"] then
    return res
  end
  system.print(MODULE_NAME .. "addCNode: res=" .. json:encode(res))

  local horde_owner = res["horde_owner"]
  local is_public = res["is_public"]

  local sender = system.getSender()
  system.print(MODULE_NAME .. "addCNode: sender=" .. sender)

  -- check permissions (403.1 Execute access forbidden)
  if sender ~= horde_owner then
    -- TODO: check sender's register CNode permission of horde
    return {
      __module = MODULE_NAME,
      __func_name = "addCNode",
      __status_code = "403",
      __status_sub_code = "1",
      __err_msg = "Sender (" .. sender .. ") doesn't allow to add a new node for the computing group (" .. horde_id .. ")",
      sender = sender,
      horde_id = horde_id
    }
  end

  __callFunction(MODULE_NAME_DB, "insert",
    "INSERT INTO horde_cnodes(horde_id, cnode_owner, cnode_name, cnode_id, metadata) VALUES (?, ?, ?, ?, ?)",
    horde_id, sender, cnode_name, cnode_id, metadataRaw)

  -- TODO: save this activity

  local horde_name = res["horde_name"]
  local horde_metadata = res["horde_metadata"]

  -- success to write (201 Created)
  return {
    __module = MODULE_NAME,
    __func_name = "addCNode",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    horde_owner = horde_owner,
    horde_id = horde_id,
    horde_name = horde_name,
    horde_metadata = horde_metadata,
    is_public = is_public,
    cnode_list = {
      {
        cnode_owner = sender,
        cnode_name = cnode_name,
        cnode_id = cnode_id,
        cnode_metadata = metadata
      }
    }
  }
end

function getAllCNodes(horde_id)
  system.print(MODULE_NAME .. "getAllCNodes: horde_id=" .. horde_id)

  -- read registered Horde
  local res = getHorde(horde_id)
  if "200" ~= res["__status_code"] then
    return res
  end
  system.print(MODULE_NAME .. "getAllCNodes: res=" .. json:encode(res))

  local horde_owner = res["horde_owner"]
  local horde_name = res["horde_name"]
  local is_public = res["is_public"]
  local horde_metadata = res["horde_metadata"]

  -- check inserted data
  local rows = __callFunction(MODULE_NAME_DB, "select",
    "SELECT cnode_owner, cnode_id, cnode_name, metadata FROM horde_cnodes WHERE horde_id = ?", horde_id)

  local cnode_list = {}

  local exist = false
  for _, v in pairs(rows) do
    local cnode = {
      cnode_owner = v[1],
      cnode_id = v[2],
      cnode_name = v[3],
      cnode_metadata = json:decode(v[4])
    }
    table.insert(cnode_list, cnode)

    exist = true
  end

  local sender = system.getSender()

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __func_name = "getAllCNodes",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find any computing node in the computing group (" .. horde_id .. ")",
      sender = sender,
      horde_owner = horde_owner,
      horde_id = horde_id,
      horde_name = horde_name,
      horde_metadata = horde_metadata,
      is_public = is_public
    }
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __func_name = "getAllCNodes",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    horde_owner = horde_owner,
    horde_id = horde_id,
    horde_name = horde_name,
    horde_metadata = horde_metadata,
    is_public = is_public,
    cnode_list = cnode_list
  }
end

function getCNode(horde_id, cnode_id)
  system.print(MODULE_NAME .. "getCNode: horde_id=" .. horde_id .. ", cnode_id=" .. cnode_id)

  -- read registered Horde
  local res = getHorde(horde_id)
  if "200" ~= res["__status_code"] then
    return res
  end
  system.print(MODULE_NAME .. "getCNode: res=" .. json:encode(res))

  local horde_owner = res["horde_owner"]
  local horde_name = res["horde_name"]
  local is_public = res["is_public"]
  local horde_metadata = res["horde_metadata"]

  -- check inserted data
  local rows = __callFunction(MODULE_NAME_DB, "select",
    "SELECT cnode_owner, cnode_name, metadata FROM horde_cnodes WHERE horde_id = ? AND cnode_id = ?", horde_id, cnode_id)

  local cnode_list = {}

  local exist = false
  for _, v in pairs(rows) do
    local cnode = {
      cnode_id = cnode_id,
      cnode_owner = v[1],
      cnode_name = v[2],
      cnode_metadata = json:decode(v[3])
    }
    table.insert(cnode_list, cnode)

    exist = true
  end

  local sender = system.getSender()

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __func_name = "getCNode",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find the node (" .. cnode_id .. ") info in the computing group (" .. horde_id .. ")",
      sender = sender,
      horde_owner = horde_owner,
      horde_id = horde_id,
      horde_name = horde_name,
      horde_metadata = horde_metadata,
      is_public = is_public,
      cnode_id = cnode_id
    }
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __func_name = "getCNode",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    horde_owner = horde_owner,
    horde_id = horde_id,
    horde_name = horde_name,
    horde_metadata = horde_metadata,
    is_public = is_public,
    cnode_list = cnode_list
  }
end

function dropCNode(horde_id, cnode_id)
  system.print(MODULE_NAME .. "dropCNode: horde_id=" .. horde_id .. ", cnode_id=" .. cnode_id)

  -- read registered CNode
  local res = getCNode(horde_id, cnode_id)
  if "200" ~= res["__status_code"] then
    return res
  end
  system.print(MODULE_NAME .. "dropCNode: res=" .. json:encode(res))

  local horde_owner = res["horde_owner"]
  local cnode_info = res["cnode_list"][1]
  local cnode_owner = cnode_info["cnode_owner"]

  -- check permissions (403.1 Execute access forbidden)
  local sender = system.getSender()
  if sender ~= horde_owner then
    if sender ~= cnode_owner then
      -- TODO: check sender's deregister (drop) permission of horde CNode
      return {
        __module = MODULE_NAME,
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
    "DELETE FROM horde_cnodes WHERE horde_id = ? AND cnode_id = ?", horde_id, cnode_id)

  -- TODO: save this activity

  -- 201 Created
  return {
    __module = MODULE_NAME,
    __func_name = "dropCNode",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    horde_owner = horde_owner,
    horde_id = horde_id,
    horde_name = res["horde_name"],
    horde_metadata = res["horde_metadata"],
    is_public = res["is_public"],
    cnode_list = res["cnode_list"]
  }
end

function updateCNode(horde_id, cnode_id, cnode_name, metadata)
  -- TODO: report JSON type argument is not accepted for delegate call
  metadata = json:decode(metadata)
  local metadataRaw = json:encode(metadata)
  system.print(MODULE_NAME .. "updateCNode: horde_id=" .. horde_id .. ", cnode_id=" .. cnode_id .. ", cnode_name=" .. tostring(cnode_name) .. ", metadata=" .. tostring(metadataRaw))

  -- read registered CNode
  local res = getCNode(horde_id, cnode_id)
  if "200" ~= res["__status_code"] then
    return res
  end
  system.print(MODULE_NAME .. "updateCNode: res=" .. json:encode(res))

  local horde_owner = res["horde_owner"]
  local cnode_info = res["cnode_list"][1]
  local cnode_owner = cnode_info["cnode_owner"]

  -- check permissions (403.3 Write access forbidden)
  local sender = system.getSender()
  if sender ~= horde_owner then
    if sender ~= cnode_owner then
      -- TODO: check sender's update permission of Horde
      return {
        __module = MODULE_NAME,
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
  if isEmpty(metadataRaw) then
    metadata = cnode_info["cnode_metadata"]
    metadataRaw = json:encode(metadata)
  end

  __callFunction(MODULE_NAME_DB, "update",
    "UPDATE horde_cnodes SET cnode_name = ?, metadata = ? WHERE horde_id = ? AND cnode_id = ?",
    cnode_name, metadataRaw, horde_id, cnode_id)

  -- TODO: save this activity

  -- 201 Created
  return {
    __module = MODULE_NAME,
    __func_name = "updateCNode",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    horde_owner = horde_owner,
    horde_id = horde_id,
    horde_name = res["horde_name"],
    horde_metadata = res["horde_metadata"],
    is_public = res["is_public"],
    cnode_list = {
      {
        cnode_owner = cnode_owner,
        cnode_name = cnode_name,
        cnode_id = cnode_id,
        cnode_metadata = metadata
      }
    }
  }
end

abi.register(addHorde, getHorde, dropHorde, updateHorde, addCNode, getAllCNodes, getCNode, dropCNode, updateCNode)
