--
-- Horde Smart Contract (HSC): Metadata
--

MODULE_NAME = "__HSC_META__"

MODULE_NAME_MAIN = "__HSC_MAIN__"
MODULE_NAME_DB = "__HSC_DB__"
MODULE_NAME_CMD = "__HSC_CMD__"
MODULE_NAME_RESULT = "__HSC_RESULT__"
MODULE_NAME_CONFIG = "__HSC_CONFIG__"
MODULE_NAME_POND = "__HSC_POND__"

local function __init__()
  local scAddress = system.getContractID()
  system.print(MODULE_NAME .. "__init__: sc_address=" .. scAddress)

  db.exec([[CREATE TABLE IF NOT EXISTS modules(
    name TEXT PRIMARY KEY,
    address TEXT NOT NULL
  )]])
  local stmt = db.prepare("INSERT INTO modules(name, address) VALUES (?, ?)")
  stmt:exec(MODULE_NAME, scAddress)

  system.setItem(MODULE_NAME .. "__CREATOR__", system.getSender())
end

local function __getOwner()
  return system.getItem(MODULE_NAME .. "__CREATOR__")
end

local function __callFunction(module_name, func_name, ...)
  system.print(MODULE_NAME .. "__callFucntion: module_name=" .. module_name .. ", func_name=" .. func_name)

  if __getOwner() ~= system.getSender() then
    system.print(MODULE_NAME .. "__callFunction: WARNING: might not be authorized sender: " .. system.getSender())
    -- TODO: need raise security error
    --return
  end

  return __call_module_function__(module_name, func_name, ...)
end

local function __getModuleAddress(name)
  system.print(MODULE_NAME .. "__getModuleAddress: name=" .. name)

  local address
  local stmt = db.prepare("SELECT address FROM modules WHERE name=?")
  local rs = stmt:query(name)
  while rs:next() do
    address = rs:get()
  end
  system.print(MODULE_NAME .. "__getModuleAddress: address=" .. address)

  return address
end

function __init_module__(module_name, address)
  if MODULE_NAME == module_name then
    system.print(MODULE_NAME .. "__init_module__: ERROR: cannot initialize META module.")
    -- TODO: need raise default module error
    return
  elseif MODULE_NAME_MAIN == module_name
          or MODULE_NAME_DB == module_name
          or MODULE_NAME_CMD == module_name
          or MODULE_NAME_RESULT == module_name
          or MODULE_NAME_CONFIG == module_name
          or MODULE_NAME_POND == module_name
  then
    system.print(MODULE_NAME .. "__init_module__: initialize module:" .. module_name .. ", address=" .. address)
  else
    system.print(MODULE_NAME .. "__init_module__: ERROR: cannot recognize module:" .. module_name)
    -- TODO: need raise user specific error
    return
  end

  local stmt = db.prepare("INSERT OR REPLACE INTO modules(name, address) VALUES (?, ?)")
  stmt:exec(module_name, address)
end

function __call_module_function__(module_name, func_name, ...)
  system.print(MODULE_NAME .. "__call_module_function__: module_name=" .. module_name)

  local address = __getModuleAddress(module_name)

  system.print(MODULE_NAME .. "__call_module_function__: address=" .. address .. ", func_name=" .. func_name)

  return contract.call(address, func_name, ...)
end

-- internal functions
abi.register(__init_module__, __call_module_function__)

--[[ ============================================================================================================== ]]--

function constructor()
  __init__()
  system.print(MODULE_NAME .. "constructor")
end

function setVersion(version)
  system.print(MODULE_NAME .. "setVersion")
  system.setItem(MODULE_NAME .. "_VERSION__", version)
end

function getVersion()
  system.print(MODULE_NAME .. "getVersion")
  return system.getItem(MODULE_NAME .. "_VERSION__")
end

function createHordeTables()
  system.print(MODULE_NAME .. "createHordeTables")
  return __callFunction(MODULE_NAME_DB, "createHordeTables")
end

function insertCommand(cmd, ...)
  system.print(MODULE_NAME .. "insertCommand")
  __callFunction(MODULE_NAME_CMD, "insertCommand", cmd, ...)
end

function queryCommand(hmc_id, finished, all)
  system.print(MODULE_NAME .. "queryCommand")
  return __callFunction(MODULE_NAME_CMD, "queryCommand", hmc_id, finished, all)
end

function insertResult(cmd_id, hmc_id, result)
  system.print(MODULE_NAME .. "insertResult")
  __callFunction(MODULE_NAME_RESULT, "insertResult", cmd_id, hmc_id, result)
end

function queryResult(cmd_id)
  system.print(MODULE_NAME .. "queryResult")
  return __callFunction(MODULE_NAME_RESULT, "queryResult", cmd_id)
end

function registerHordeMaster(hmc_id, info)
  system.print(MODULE_NAME .. "registerHordeMaster")
  return __callFunction(MODULE_NAME_CONFIG, "registerHordeMaster", hmc_id, info)
end

function queryHordeMaster(hmc_id)
  system.print(MODULE_NAME .. "queryHordeMaster")
  return __callFunction(MODULE_NAME_CONFIG, "queryHordeMaster", hmc_id)
end

function queryAllHordeMasters()
  system.print(MODULE_NAME .. "queryAllHordeMasters")
  return __callFunction(MODULE_NAME_CONFIG, "queryAllHordeMasters")
end

function insertPond(...)
  system.print(MODULE_NAME .. "insertPond")
  return __callFunction(MODULE_NAME_POND, "insertPond", system.getSender(), ...)
end

function queryPonds(...)
  system.print(MODULE_NAME .. "queryPonds")
  return __callFunction(MODULE_NAME_POND, "queryPonds", ...)
end

-- exposed functions
abi.register(setVersion, getVersion,
  -- DB
  createHordeTables,
  -- CMD
  insertCommand, queryCommand,
  -- RESULT
  insertResult, queryResult,
  -- CONFIG
  registerHordeMaster, queryHordeMaster, queryAllHordeMasters,
  -- POND
  insertPond, queryPonds
)

