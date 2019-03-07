--
-- Manifest
--
--  !!! WARNING !!!
--    If change anything in this code,
--    the smart contract address of your application will be changed.
--

MODULE_NAME = "__MANIFEST__"

local function __init__()
  local scAddress = system.getContractID()
  system.print(MODULE_NAME .. "__init__: sc_address=" .. scAddress)

  db.exec([[CREATE TABLE IF NOT EXISTS modules(
    name    TEXT PRIMARY KEY,
    address TEXT NOT NULL
  )]])
  local stmt = db.prepare("INSERT INTO modules(name, address) VALUES (?, ?)")
  stmt:exec(MODULE_NAME, scAddress)
end

local function __getModuleOwner()
  return system.getItem(MODULE_NAME .. "__CREATOR__")
end

local function __callFunction(module_name, func_name, ...)
  system.print(MODULE_NAME .. "__callFunction: module_name=" .. module_name .. ", func_name=" .. func_name)

  local module_owner = __getModuleOwner()
  if sender ~= nil and string.len(sender) ~= 0 then
    system.setItem(MODULE_NAME .. "__SENDER__", sender)
    system.print(MODULE_NAME .. "__callFunction: sender(" .. sender .. ") calls owner(" .. module_owner .. ")'s module")
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

function __init_module__(module_name, address, ...)
  if system.getCreator() ~= system.getSender() then
    system.print(MODULE_NAME .. "__init_module__: ERROR: only the creator can initialize a module.")
    return
  end

  if MODULE_NAME == module_name then
    system.print(MODULE_NAME .. "__init_module__: ERROR: cannot initialize the Manifest module.")
    return
  end

  system.print(MODULE_NAME .. "__init_module__: initialize module:" .. module_name .. ", address=" .. address)

  -- insert module name and address
  local stmt = db.prepare("INSERT OR REPLACE INTO modules(name, address) VALUES (?, ?)")
  stmt:exec(module_name, address)
end

function __call_module_function__(module_name, func_name, ...)
  system.print(MODULE_NAME .. "__call_module_function__: module_name=" .. module_name .. ", func_name=" .. func_name)

  local address = __getModuleAddress(module_name)
  system.print(MODULE_NAME .. "__call_module_function__: address=" .. address)

  return contract.call(address, func_name, ...)
end

-- internal functions
abi.register(__init_module__, __call_module_function__)

--[[ ============================================================================================================== ]]--

function constructor()
  __init__()
  system.print(MODULE_NAME .. "constructor")
end

function callFunction(module, functionName, ...)
  system.print(MODULE_NAME .. "callFunction: module=" .. module .. ", functionName=" .. functionName)
  return __callFunction(module, functionName, ...)
end

function setVersion(version)
  system.print(MODULE_NAME .. "setVersion")
  system.setItem(MODULE_NAME .. "_VERSION__", version)
end

function getVersion()
  system.print(MODULE_NAME .. "getVersion")
  return system.getItem(MODULE_NAME .. "_VERSION__")
end

-- exposed functions
abi.register(setVersion, getVersion, callFunction)
