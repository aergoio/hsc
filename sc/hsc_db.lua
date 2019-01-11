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

  -- create command table for saving commands
  db.exec([[CREATE TABLE IF NOT EXISTS command(
    cmd_id TEXT PRIMARY KEY,
    block_height INTEGER DEFAULT NULL,
    cmd_content TEXT NOT NULL
  )]])

  -- create target table for command ID of each HMC
  db.exec([[CREATE TABLE IF NOT EXISTS cmd_target(
    cmd_id TEXT NOT NULL,
    hmc_id TEXT NOT NULL,
    finished INTEGER DEFAULT NULL,
    FOREIGN KEY(cmd_id) REFERENCES command(cmd_id)
      ON DELETE CASCADE ON UPDATE NO ACTION
  )]])

  -- create result table from executing the command
  db.exec([[CREATE TABLE IF NOT EXISTS cmd_result(
    cmd_id TEXT NOT NULL,
    hmc_id TEXT NOT NULL,
    result TEXT NOT NULL,
    FOREIGN KEY(cmd_id) REFERENCES command(cmd_id)
      ON DELETE CASCADE ON UPDATE NO ACTION
  )]])

  -- create Docker container table
  db.exec([[CREATE TABLE IF NOT EXISTS master_conf(
    hmc_id TEXT,
    cnode_id TEXT,
    container_id TEXT,
    PRIMARY KEY (hmc_id, cnode_id, container_id)
  )]])
end

function insertCommand(cmd)
  -- tx id is for command id
  local cmd_id = system.getTxhash()
  local block_height = system.getBlockheight()
  system.print(MODULE_NAME .. "insertCommand: cmd_id=" .. cmd_id .. ", block_height=".. block_height .. ", cmd=" .. cmd)

  -- insert command
  local stmt = db.prepare("INSERT INTO command(cmd_id, block_height, cmd_content) VALUES (?, ?, ?)")
  stmt:exec(cmd_id, block_height, cmd)

  return {
    __module=MODULE_NAME,
    __func_name="insertCommand",
    cmd_id=cmd_id,
    block_height=block_height,
    cmd=cmd
  }
end

function insertCommandTarget(cmd_id, hmc_id)
  system.print(MODULE_NAME .. "insertCommandTarget: cmd_id=" .. cmd_id .. ", hmc_id=".. hmc_id)

  -- insert command target
  local stmt = db.prepare("INSERT INTO cmd_target(cmd_id, hmc_id) VALUES (?, ?)")
  stmt:exec(cmd_id, hmc_id)
end

function updateCommandTarget(cmd_id, hmc_id, finished)
  system.print(MODULE_NAME .. "updateCommandTarget: cmd_id=" .. cmd_id .. ", hmc_id=".. hmc_id .. ", finished=" .. finished)

  -- insert command target
  local stmt = db.prepare("UPDATE cmd_target SET finished = ? WHERE cmd_id = ? AND hmc_id = ?")
  stmt:exec(finished, cmd_id, hmc_id)
end

function queryAllCommands(hmc_id)
  system.print(MODULE_NAME .. "queryAllCommands: hmc_id=" .. hmc_id)

  local cmd_list = {}

  local sql = [[SELECT command.cmd_id, command.cmd_content, cmd_target.finished
    FROM command INNER JOIN cmd_target
    WHERE command.cmd_id = cmd_target.cmd_id
      AND cmd_target.hmc_id = ?
    ORDER BY command.block_height
  ]]
  local stmt = db.prepare(sql)
  local rs = stmt:query(hmc_id)
  while rs:next() do
    local col1, col2, col3 = rs:get()
    local item = {
      cmd_id = col1,
      cmd = col2,
      finished = tostring(col3)
    }
    table.insert(cmd_list, item)
  end

  return {
    __module=MODULE_NAME,
    __func_name="queryAllCommands",
    cmd_list = cmd_list
  }
end

function queryFinishedCommands(hmc_id)
  system.print(MODULE_NAME .. "queryFinishedCommands: hmc_id=" .. hmc_id)

  local cmd_list = {}

  local sql = [[SELECT command.cmd_id, command.cmd_content, cmd_target.finished
    FROM command INNER JOIN cmd_target
    WHERE command.cmd_id = cmd_target.cmd_id
      AND cmd_target.hmc_id = ?
      AND cmd_target.finished IS NOT NULL
    ORDER BY command.block_height
  ]]
  local stmt = db.prepare(sql)
  local rs = stmt:query(hmc_id)
  while rs:next() do
    local col1, col2, col3 = rs:get()
    local item = {
      cmd_id = col1,
      cmd = col2,
      finished = col3
    }
    table.insert(cmd_list, item)
  end

  return {
    __module=MODULE_NAME,
    __func_name="queryFinishedCommands",
    cmd_list = cmd_list
  }
end

function queryNotFinishedCommands(hmc_id)
  system.print(MODULE_NAME .. "queryNotFinishedCommands: hmc_id=" .. hmc_id)

  local cmd_list = {}

  local sql = [[SELECT command.cmd_id, command.cmd_content
    FROM command INNER JOIN cmd_target
    WHERE command.cmd_id = cmd_target.cmd_id
      AND cmd_target.hmc_id = ?
      AND cmd_target.finished IS NULL
    ORDER BY command.block_height
  ]]
  local stmt = db.prepare(sql)
  local rs = stmt:query(hmc_id)
  while rs:next() do
    local col1, col2 = rs:get()
    local item = {
      cmd_id = col1,
      cmd = col2,
      finished = "nil"
    }
    table.insert(cmd_list, item)
  end

  return {
    __module=MODULE_NAME,
    __func_name="queryNotFinishedCommands",
    cmd_list = cmd_list
  }
end

function insertResult(cmd_id, hmc_id, result)
  system.print(MODULE_NAME .. "insertResult: cmd_id=" .. cmd_id .. ", hmc_id=" .. hmc_id .. ", result=" .. json:encode(result))

  -- insert command result
  local stmt = db.prepare("INSERT INTO cmd_result(cmd_id, hmc_id, result) VALUES (?, ?, ?)")
  stmt:exec(cmd_id, hmc_id, result)
end

function queryResult(cmd_id)
  system.print(MODULE_NAME .. "queryResult: cmd_id=" .. cmd_id)

  local result_list = {}

  local stmt = db.prepare("SELECT hmc_id, result FROM cmd_result WHERE cmd_id = ?")
  local rs = stmt:query(cmd_id)
  while rs:next() do
    local col1, col2 = rs:get()
    local item = {
      hmc_id = col1,
      result = col2
    }
    table.insert(result_list, item)
  end
  return result_list
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
  createHordeTables, insertCommand,
  insertCommandTarget, updateCommandTarget,
  queryAllCommands, queryFinishedCommands, queryNotFinishedCommands,
  insertResult, queryResult,
  insertHordeInfo, queryHordeInfo, queryAllHordeInfo)
