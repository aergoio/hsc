--
-- Horde Smart Contract (HSC): Main
--

MODULE_NAME = "__HSC_MAIN__"

MODULE_NAME_DB = "__HSC_DB__"
MODULE_NAME_CMD = "__HSC_CMD__"
MODULE_NAME_RESULT = "__HSC_RESULT__"
MODULE_NAME_CONFIG = "__HSC_CONFIG__"

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

function registerHordeMaster(hm_id, info)
  system.print(MODULE_NAME .. "registerHordeMaster")
  return __callFunction(MODULE_NAME_CONFIG, "registerHordeMaster", hm_id, info)
end

function queryHordeMaster(hm_id)
  system.print(MODULE_NAME .. "queryHordeMaster")
  return __callFunction(MODULE_NAME_CONFIG, "queryHordeMaster", hm_id)
end

function queryAllHordeMasters()
  system.print(MODULE_NAME .. "queryAllHordeMasters")
  return __callFunction(MODULE_NAME_CONFIG, "queryAllHordeMasters")
end

abi.register(createHordeTables, insertCommand, queryCommand, insertResult, queryResult,
  registerHordeMaster, queryHordeMaster, queryAllHordeMasters)
