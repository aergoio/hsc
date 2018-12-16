--
-- Horde Smart Contract (HSC): Configuration of Horde
--

MODULE_NAME = "__HSC_CONFIG__"

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

function registerHordeMaster(hm_id, info)
  system.print(MODULE_NAME .. "registerHordeMaster: hm_id=" .. hm_id .. ", info=" .. json:encode(info))

  local hm_info = json:decode(info)
  if hm_info.hm_id ~= hm_id then
    system.print(MODULE_NAME .. "registerHordeMaster: ERROR: cannot register Horde with a different ID.")
    -- TODO: need raise default module error
    return
  end

  -- one command to multiple HMCs
  for _, cnode in pairs(hm_info.cnode_list) do
    local count = 0
    if cnode.container_list ~= nil then
      for _, container in pairs(cnode.container_list) do
        count = count + 1
        system.print("CNode ID = " .. cnode.cnode_id .. ", Container ID = " .. container.container_id)
        __callFunction(MODULE_NAME_DB, "insertHordeInfo", hm_id, cnode.cnode_id, container.container_id)
      end
    end

    -- empty CNode
    if 0 == count then
      __callFunction(MODULE_NAME_DB, "insertHordeInfo", hm_id, cnode.cnode_id)
    end
  end
end

function queryHordeMaster(hm_id)
  system.print(MODULE_NAME .. "queryHordeMaster: hm_id=" .. hm_id)
  return __callFunction(MODULE_NAME_DB, "queryHordeInfo", hm_id)
end

function queryAllHordeMasters()
  system.print(MODULE_NAME .. "queryAllHordeMasters")
  return __callFunction(MODULE_NAME_DB, "queryAllHordeInfo")
end

abi.register(registerHordeMaster, queryHordeMaster, queryAllHordeMasters)
