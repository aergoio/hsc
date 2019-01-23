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
  system.print(MODULE_NAME .. "constructor: metaAddress=" .. metaAddress)

  -- create Horde master table
  __callFunction(MODULE_NAME_DB, "createTable", [[CREATE TABLE IF NOT EXISTS horde_master(
    horde_id TEXT,
    cnode_id TEXT,
    container_id TEXT,
    PRIMARY KEY (horde_id, cnode_id, container_id)
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
    __callFunction(MODULE_NAME_DB, "delete",
                   "DELETE FROM horde_master WHERE horde_id = ?",
                   horde_id)
  end

  -- one command to multiple HMCs
  for _, cnode in pairs(horde_info.cnode_list) do
    local count = 0
    if cnode.container_list ~= nil then
      for _, container in pairs(cnode.container_list) do
        count = count + 1
        system.print(MODULE_NAME .. "CNode ID = " .. cnode.cnode_id .. ", Container ID = " .. container.container_id)
        __callFunction(MODULE_NAME_DB, "insert",
                       "INSERT OR REPLACE INTO horde_master(horde_id, cnode_id, container_id) VALUES (?, ?, ?)",
                       horde_id, cnode.cnode_id, container.container_id)
      end
    end

    -- empty CNode
    if 0 == count then
      system.print(MODULE_NAME .. "CNode ID = " .. cnode.cnode_id .. ", No Container")
      __callFunction(MODULE_NAME_DB, "insert",
                     "INSERT OR REPLACE INTO horde_master(horde_id, cnode_id) VALUES (?, ?)",
                     horde_id, cnode.cnode_id)
    end
  end
end

function queryHorde(horde_id)
  system.print(MODULE_NAME .. "queryHorde: horde_id=" .. horde_id)

  local horde_info = {
    hmc_id = horde_id,
    cnode_list = {}
  }

  local rows = __callFunction(MODULE_NAME_DB, "select",
                              [[SELECT cnode_id, container_id
                                  FROM horde_master
                                  WHERE horde_id = ?
                                  ORDER BY horde_id, cnode_id]],
                              horde_id)
  local cnode_id = ""
  local cnode_idx = 0
  local container_idx = 1
  for _, v in pairs(rows) do
    local col1 = v[1]
    local col2 = v[2]

    -- collect cnode_id
    if col1 ~= cnode_id then
      cnode_id = col1
      cnode_idx = cnode_idx + 1
      horde_info.cnode_list[cnode_idx] = {
        cnode_id = cnode_id,
        container_list = {}
      }
      container_idx = 1
    end

    -- collect container_id
    if col2 ~= nil then
      horde_info.cnode_list[cnode_idx].container_list[container_idx] = {
        container_id = col2
      }
      container_idx = container_idx + 1
    end
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

  local rows = __callFunction(MODULE_NAME_DB, "select",
                              [[SELECT horde_id, cnode_id, container_id
                                  FROM horde_master
                                  ORDER BY horde_id, cnode_id]])
  local horde_id = ""
  local horde_idx = 0
  local cnode_id = ""
  local cnode_idx = 0
  local container_idx = 1
  for _, v in pairs(rows) do
    local col1 = v[1]
    local col2 = v[2]
    local col3 = v[3]

    -- collect horde_id
    if col1 ~= horde_id then
      horde_id = col1
      horde_idx = horde_idx + 1
      horde_list[horde_idx] = {
        hmc_id = horde_id,
        cnode_list = {}
      }
      cnode_id = ""
      cnode_idx = 0
    end

    local horde_info = horde_list[horde_idx]

    -- collect cnode_id
    if col2 ~= cnode_id then
      cnode_id = col2
      cnode_idx = cnode_idx + 1
      horde_info.cnode_list[cnode_idx] = {
        cnode_id = cnode_id,
        container_list = {}
      }
      container_idx = 1
    end

    -- collect container_id
    if col3 ~= nil then
      horde_info.cnode_list[cnode_idx].container_list[container_idx] = {
        container_id = col3
      }
      container_idx = container_idx + 1
    end
  end

  return {
    __module = MODULE_NAME,
    __func_name = "queryAllHordes",
    horde_list = horde_list,
  }
end

abi.register(registerHorde, queryHorde, queryAllHordes)
