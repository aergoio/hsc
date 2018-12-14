--
-- Horde Smart Contract (HSC): Result
--

MODULE_NAME = "__HSC_RESULT__"

MODULE_NAME_DB = "__HSC_DB__"

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

function insertResult(cmd_id, hmc_id, result)
  system.print(MODULE_NAME .. "insertResult: cmd_id=" .. cmd_id .. ", hmc_id=" .. hmc_id .. ", result=" .. json:encode(result))

  local finished = system.getBlockheight()
  -- only command owner can update result

  __callFunction(MODULE_NAME_DB, "updateCommandTarget", cmd_id, hmc_id, finished)
  __callFunction(MODULE_NAME_DB, "insertResult", cmd_id, hmc_id, result)
end

function queryResult(cmd_id)
  system.print(MODULE_NAME .. "queryResult: cmd_id=" .. cmd_id)
  local results = __callFunction(MODULE_NAME_DB, "queryResult", cmd_id)
  return { cmd_id = cmd_id, results = results }
end

abi.register(insertResult, queryResult)
