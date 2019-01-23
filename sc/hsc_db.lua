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

function alterTable(sql)
  system.print(MODULE_NAME .. "alterTable: sql=" .. sql)
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

function delete(sql, ...)
  system.print(MODULE_NAME .. "delete: sql=" .. sql .. ", args=" .. json:encode({...}))
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

function updateCommandTarget(cmd_id, hmc_id, finished)
  system.print(MODULE_NAME .. "updateCommandTarget: cmd_id=" .. cmd_id .. ", hmc_id=".. hmc_id .. ", finished=" .. finished)

  -- insert command target
  local stmt = db.prepare("UPDATE cmd_target SET finished = ? WHERE cmd_id = ? AND hmc_id = ?")
  stmt:exec(finished, cmd_id, hmc_id)
end

abi.register(createTable, alterTable, insert, update, delete, select)
abi.register(updateCommandTarget)
