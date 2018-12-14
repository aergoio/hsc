--
-- Horde Smart Contract (HSC): Command
--

MODULE_NAME = "__HSC_CMD__"

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

function insertCommand(cmd, ...)
  local args = {...}
  system.print(MODULE_NAME .. "insertCommand: cmd=" .. cmd .. ", args=" .. json:encode(args))

  local result = __callFunction(MODULE_NAME_DB, "insertCommand", cmd)
  system.print("result=" .. json:encode(result))

  local cmd_id = result['cmd_id']
  system.print("cmd_id=" .. cmd_id)

  -- one command to multiple HMCs
  for _, v in pairs(args) do
    __callFunction(MODULE_NAME_DB, "insertCommandTarget", cmd_id, tostring(v))
  end
end

function queryCommand(hmc_id, finished, all)
  system.print(MODULE_NAME .. "queryCommand: hmc_id=" .. hmc_id .. ", finished=" .. tostring(finished) .. ", all=" .. tostring(all))

  local result
  if not all then
    if finished then
      result = __callFunction(MODULE_NAME_DB, "queryFinishedCommands", hmc_id)
    else
      result = __callFunction(MODULE_NAME_DB, "queryNotFinishedCommands", hmc_id)
    end
  else
    result = __callFunction(MODULE_NAME_DB, "queryAllCommands", hmc_id)
  end
  system.print("result=" .. json:encode(result))

  return result
end

abi.register(insertCommand, queryCommand)
