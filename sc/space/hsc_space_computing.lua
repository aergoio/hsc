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

  -- create Horde master table
  __callFunction(MODULE_NAME_DB, "createTable", [[CREATE TABLE IF NOT EXISTS horde_master(
    horde_id        TEXT PRIMARY KEY,
    info            TEXT
  )]])

  -- create Horde CNode metadata table
  __callFunction(MODULE_NAME_DB, "createTable", [[CREATE TABLE IF NOT EXISTS horde_cnodes(
    horde_id        TEXT,
    cnode_id        TEXT,
    info            TEXT,
    PRIMARY KEY(horde_id, cnode_id),
    FOREIGN KEY(horde_id) REFERENCES horde_master(horde_id)
      ON DELETE CASCADE ON UPDATE NO ACTION
  )]])

  -- create Horde CNode containers metadata table
  __callFunction(MODULE_NAME_DB, "createTable", [[CREATE TABLE IF NOT EXISTS horde_containers(
    horde_id        TEXT,
    cnode_id        TEXT,
    container_id    TEXT,
    info            TEXT,
    PRIMARY KEY(horde_id, cnode_id, container_id),
    FOREIGN KEY(horde_id, cnode_id) REFERENCES horde_cnodes(horde_id, cnode_id)
      ON DELETE CASCADE ON UPDATE NO ACTION
  )]])

  -- create Horde Pond metadata table
  __callFunction(MODULE_NAME_DB, "createTable", [[CREATE TABLE IF NOT EXISTS ponds(
    pond_name     TEXT,
    pond_id       TEXT,
    creator       TEXT,
    info          TEXT,
    PRIMARY KEY(pond_id, creator)
  )]])

  -- create Horde BNode metadata table
  __callFunction(MODULE_NAME_DB, "createTable", [[CREATE TABLE IF NOT EXISTS bnodes(
    bnode_name    TEXT,
    bnode_id      TEXT,
    pond_id       TEXT,
    creator       TEXT,
    info          TEXT,
    PRIMARY KEY(pond_id, bnode_id, creator)
    FOREIGN KEY(pond_id) REFERENCES ponds(pond_id)
      ON DELETE CASCADE ON UPDATE NO ACTION
  )]])
end

function registerHorde(horde_id, info, clean)
  system.print(MODULE_NAME .. "registerHorde: horde_id=" .. horde_id .. ", info=" .. json:encode(info) .. ", clean=" .. tostring(clean))

  local horde_info = json:decode(info)
  if horde_info.hmc_id ~= horde_id then
    system.print(MODULE_NAME .. "registerHordeMaster: ERROR: cannot register Horde with a different ID.")
    -- TODO: need raise default module error
    return
  end

  if clean then
    -- delete all information before inserting
    __callFunction(MODULE_NAME_DB, "delete",
                   "DELETE FROM horde_master WHERE horde_id = ?",
                   horde_id)
  end

  -- insert Horde information
  __callFunction(MODULE_NAME_DB, "insert",
                 [[INSERT OR REPLACE INTO horde_master(horde_id, info) VALUES (?, ?)]],
                 horde_id, json:encode(horde_info.info))

  -- one command to multiple CNodes
  for _, cnode in pairs(horde_info.cnode_list) do
    -- insert CNode info
    system.print(MODULE_NAME .. "CNode ID = " .. cnode.id .. ", No BNodes")
    __callFunction(MODULE_NAME_DB, "insert",
                   [[INSERT OR REPLACE INTO horde_cnodes(horde_id, cnode_id, info) VALUES (?, ?, ?)]],
                   horde_id, cnode.id, json:encode(cnode.info))

    if cnode.container_list ~= nil then
      for _, container in pairs(cnode.container_list) do
        system.print(MODULE_NAME .. "CNode ID = " .. cnode.id .. ", Container ID = " .. container.id)
        __callFunction(MODULE_NAME_DB, "insert",
                       [[INSERT OR REPLACE INTO horde_containers
                            (horde_id, cnode_id, container_id, info)
                          VALUES (?, ?, ?, ?)]],
                       horde_id, cnode.id, container.id, json:encode(container.info))
      end
    end
  end
end

function queryHorde(horde_id)
  system.print(MODULE_NAME .. "queryHorde: horde_id=" .. horde_id)

  local horde_info = {
    hmc_id = horde_id,
    info = {},
    cnode_list = {}
  }

  -- get horde info
  local rows = __callFunction(MODULE_NAME_DB, "select",
                              [[SELECT info FROM horde_master WHERE horde_id = ?]],
                              horde_id)
  for _, v in pairs(rows) do
    horde_info.info = json:decode(v[1])
  end

  -- get cnode info
  rows = __callFunction(MODULE_NAME_DB, "select",
                        [[SELECT cnode_id, info FROM horde_cnodes WHERE horde_id = ?]],
                        horde_id)
  for _, v in pairs(rows) do
    table.insert(horde_info.cnode_list, {
      id = v[1],
      info = json:decode(v[2]),
      container_list = {}
    })
  end

  -- get container info
  rows = __callFunction(MODULE_NAME_DB, "select",
                        [[SELECT cnode_id, container_id, info FROM horde_containers
                            WHERE horde_id = ? ORDER BY cnode_id]],
                        horde_id)
  local cnode = {}
  for _, v in pairs(rows) do
    local cnode_id = v[1]
    local container_id = v[2]
    local container_info = json:decode(v[3])

    if cnode.id ~= cnode_id then
      for _, v2 in pairs(horde_info.cnode_list) do
        if cnode_id == v2.id then
          cnode = v2
          break
        end
      end
    end

    table.insert(cnode.container_list, {
      id = container_id,
      info = container_info,
    })
  end

  return {
    __module = MODULE_NAME,
    __func_name = "queryHorde",
    horde_info = horde_info,
  }
end

function queryAllHordes()
  system.print(MODULE_NAME .. "queryAllHordes")

  local horde_list = {}

  -- get horde info
  local rows = __callFunction(MODULE_NAME_DB, "select",
                              [[SELECT horde_id, info FROM horde_master]])
  for _, v in pairs(rows) do
    system.print("horde_id=" .. v[1] .. ", horde_info=" .. v[2])

    table.insert(horde_list, {
      hmc_id = v[1],
      info = json:decode(v[2]),
      cnode_list = {}
    })
  end

  -- get cnode info
  rows = __callFunction(MODULE_NAME_DB, "select",
                        [[SELECT horde_id, cnode_id, info FROM horde_cnodes ORDER BY horde_id]])
  local horde = {}
  for _, v in pairs(rows) do
    local horde_id = v[1]
    local cnode_id = v[2]
    local cnode_info = json:decode(v[3])

    system.print("horde_id=" .. horde_id .. ", cnode_id=" .. cnode_id .. ", cnode_info=" .. v[3])

    if horde.id ~= horde_id then
      for _, v2 in pairs(horde_list) do
        if horde_id == v2.hmc_id then
          horde = v2
          break
        end
      end
    end

    table.insert(horde.cnode_list, {
      id = cnode_id,
      info = cnode_info,
      container_list = {}
    })
  end

  -- get container info
  rows = __callFunction(MODULE_NAME_DB, "select",
                        [[SELECT horde_id, cnode_id, container_id, info FROM horde_containers
                            ORDER BY horde_id, cnode_id]])
  local horde = {}
  local cnode = {}
  for _, v in pairs(rows) do
    local horde_id = v[1]
    local cnode_id = v[2]
    local container_id = v[3]
    local container_info = json:decode(v[4])

    system.print("horde_id=" .. horde_id .. ", cnode_id=" .. cnode_id .. ", container_id=" .. container_id .. ", container_info=" .. v[3])

    if horde.id ~= horde_id then
      for _, v2 in pairs(horde_list) do
        if horde_id == v2.hmc_id then
          horde = v2
          break
        end
      end
    end

    if cnode.id ~= cnode_id then
      for _, v2 in pairs(horde.cnode_list) do
        if cnode_id == v2.id then
          cnode = v2
          break
        end
      end
    end

    table.insert(cnode.container_list, {
      id = container_id,
      info = container_info
    })
  end

  return {
    __module = MODULE_NAME,
    __func_name = "queryAllHordes",
    horde_list = horde_list,
  }
end

abi.register(registerHorde, queryHorde, queryAllHordes)
