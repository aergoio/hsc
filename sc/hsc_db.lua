--
-- Horde Smart Contract (HSC): Database
--

MODULE_NAME = "__HSC_DB__"

state.var {
  -- contant variables
  HSC_ADDRESS = state.value(),
}

local function __init__(metaAddress)
  HSC_ADDRESS:set(metaAddress)
  local scAddress = system.getContractID()
  system.print(MODULE_NAME .. "__init__: sc_address=" .. scAddress)
  contract.call(HSC_ADDRESS:get(), "__init_module__", MODULE_NAME, scAddress)
end

local function __callFunction(module_name, func_name, ...)
  system.print(MODULE_NAME .. "__callFucntion: module_name=" .. module_name .. ", func_name=" .. func_name)
  return contract.call(HSC_ADDRESS:get(), "__call_module_function__", module_name, func_name, ...)
end

--[[ ============================================================================================================== ]]--

function constructor(metaAddress)
  __init__(metaAddress)
  system.print(MODULE_NAME .. "constructor")
end

function createTable(sql)
  system.print(MODULE_NAME .. "createTable: sql=" .. sql)
  db.exec(sql)
end

function insert(sql, ...)
  system.print(MODULE_NAME .. "insert: sql=" .. sql .. ", args=" .. json:encode({...}))
  local stmt = db.prepare(sql)
  stmt:exec(...)
end

function update(sql, ...)
  system.print(MODULE_NAME .. "update: sql=" .. sql .. ", args=" .. json:encode({...}))
  local stmt = db.prepare(sql)
  stmt:exec(...)
end

function select(sql, ...)
  system.print(MODULE_NAME .. "select: sql=" .. sql .. ", args=" .. json:encode({...}))

  local stmt = db.prepare(sql)
  local rs = stmt:query(...)
  local rows = {}

  while rs:next() do
    table.insert(rows, { rs:get() })
  end

  return rows
end

function createHordeTables()
  system.print(MODULE_NAME .. "createHordeTables")

  -- create Docker container table
  db.exec([[CREATE TABLE IF NOT EXISTS master_conf(
    hmc_id TEXT,
    cnode_id TEXT,
    container_id TEXT,
    PRIMARY KEY (hmc_id, cnode_id, container_id)
  )]])
end

function updateCommandTarget(cmd_id, hmc_id, finished)
  system.print(MODULE_NAME .. "updateCommandTarget: cmd_id=" .. cmd_id .. ", hmc_id=".. hmc_id .. ", finished=" .. finished)

  -- insert command target
  local stmt = db.prepare("UPDATE cmd_target SET finished = ? WHERE cmd_id = ? AND hmc_id = ?")
  stmt:exec(finished, cmd_id, hmc_id)
end

function insertHordeInfo(hmc_id, cnode_id, container_id)
  system.print(MODULE_NAME .. "insertHordeInfo: hmc_id=" .. hmc_id .. ", cnode_id=".. cnode_id)

  -- insert Horde info
  local stmt = db.prepare("INSERT OR REPLACE INTO master_conf(hmc_id, cnode_id, container_id) VALUES (?, ?, ?)")
  stmt:exec(hmc_id, cnode_id, container_id)
end

function queryHordeInfo(hmc_id)
  system.print(MODULE_NAME .. "queryHordeInfo: hmc_id=" .. hmc_id)

  local hm_info = {
    hmc_id = hmc_id,
    cnode_list = {}
  }

  local stmt = db.prepare("SELECT cnode_id, container_id FROM master_conf WHERE hmc_id = ? ORDER BY hmc_id, cnode_id")
  local rs = stmt:query(hmc_id)

  local cnode_id = ""
  local cnode_idx = 0
  local container_idx = 1
  while rs:next() do
    local col1, col2 = rs:get()

    -- collect cnode_id
    if col1 ~= cnode_id then
      cnode_id = col1
      cnode_idx = cnode_idx + 1
      hm_info.cnode_list[cnode_idx] = {
        cnode_id = cnode_id,
        container_list = {}
      }
      container_idx = 1
    end

    -- collect container_id
    if col2 ~= nil then
      hm_info.cnode_list[cnode_idx].container_list[container_idx] = {
        container_id = col2
      }
      container_idx = container_idx + 1
    end
  end

  return hm_info
end

function queryAllHordeInfo()
  system.print(MODULE_NAME .. "queryAllHordeInfo")

  local hm_list = {}

  local stmt = db.prepare("SELECT hmc_id, cnode_id, container_id FROM master_conf ORDER BY hmc_id, cnode_id")
  local rs = stmt:query()

  local hmc_id = ""
  local hmc_idx = 0
  local cnode_id = ""
  local cnode_idx = 0
  local container_idx = 1
  while rs:next() do
    local col1, col2, col3 = rs:get()

    -- collect hmc_id
    if col1 ~= hmc_id then
      hmc_id = col1
      hmc_idx = hmc_idx + 1
      hm_list[hmc_idx] = {
        hmc_id = hmc_id,
        cnode_list = {}
      }
      cnode_id = ""
      cnode_idx = 0
    end

    local hm_info = hm_list[hmc_idx]

    -- collect cnode_id
    if col2 ~= cnode_id then
      cnode_id = col2
      cnode_idx = cnode_idx + 1
      hm_info.cnode_list[cnode_idx] = {
        cnode_id = cnode_id,
        container_list = {}
      }
      container_idx = 1
    end

    -- collect container_id
    if col3 ~= nil then
      hm_info.cnode_list[cnode_idx].container_list[container_idx] = {
        container_id = col3
      }
      container_idx = container_idx + 1
    end
  end

  return hm_list
end

abi.register(createTable, insert, select,
  createHordeTables,
  updateCommandTarget,
  insertHordeInfo, queryHordeInfo, queryAllHordeInfo)
