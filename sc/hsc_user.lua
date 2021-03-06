--
-- Horde Smart Contract (HSC): Command
--

MODULE_NAME = "__HSC_USER__"

MODULE_NAME_DB = "__MANIFEST_DB__"

state.var {
  -- contant variables
  _MANIFEST_ADDRESS = state.value(),
}

local function __init__(manifestAddress)
  _MANIFEST_ADDRESS:set(manifestAddress)
  local scAddress = system.getContractID()
  system.print(MODULE_NAME .. "__init__: sc_address=" .. scAddress)
  contract.call(_MANIFEST_ADDRESS:get(),
    "__init_module__", MODULE_NAME, scAddress)
end

local function __callFunction(module_name, func_name, ...)
  system.print(MODULE_NAME .. "__callFucntion: module_name=" .. module_name
          .. ", func_name=" .. func_name)
  return contract.call(_MANIFEST_ADDRESS:get(),
    "__call_module_function__", module_name, func_name, ...)
end

local function __getManifestAddress()
  local address = _MANIFEST_ADDRESS:get()
  system.print(MODULE_NAME .. "__getManifestAddress: address=" .. address) 
  return address
end

--[[ ====================================================================== ]]--

function constructor(manifestAddress)
  __init__(manifestAddress)
  system.print(MODULE_NAME
          .. "constructor: manifestAddress=" .. manifestAddress)
 
  -- create user table
  __callFunction(MODULE_NAME_DB, "createTable",
    [[CREATE TABLE IF NOT EXISTS horde_users(
            user_id         TEXT NOT NULL,
            user_address    TEXT NOT NULL,
            user_block_no   INTEGER DEFAULT NULL,
            user_tx_id      TEXT NOT NULL,
            user_metadata   TEXT,
            PRIMARY KEY(user_id, user_address)
  )]])
end

local function isEmpty(v)
  return nil == v or 0 == string.len(v)
end

function createUser(user_id, user_address, metadata)
  if type(metadata) == 'string' then
    metadata = json:decode(metadata)
  end
  local metadata_raw = json:encode(metadata)
  system.print(MODULE_NAME .. "createUser: user_id=" .. tostring(user_id)
          .. ", user_address=" .. tostring(user_address)
          .. ", metadata=" .. metadata_raw)

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "createUser: sender=" .. sender
          .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  --if isEmpty(user_id) then
  if isEmpty(user_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "createUser",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      user_id = user_id,
    }
  end

  -- find a user
  local res = getUser(user_id)
  local is_the_first_time = false
  local exist_sender = false
  system.print(MODULE_NAME .. "createUser: res=" .. json:encode(res))
  if "404" == res["__status_code"] then
    is_the_first_time = true
  elseif "200" == res["__status_code"] then
    for _, info in pairs(res['user_info_list']) do
      local ua = info['user_address']
      if ua == sender then
        exist_sender = true
        break
      end
    end
  else
    return res
  end

  -- check permissions (403.1 Execute access forbidden)
  if not is_the_first_time and not exist_sender then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "createUser",
      __status_code = "403",
      __status_sub_code = "1",
      __err_msg = "sender doesn't allow to create a new user",
      sender = sender,
      user_id = user_id,
    }
  end

  -- tx id
  local tx_id = system.getTxhash()
  system.print(MODULE_NAME .. "createUser: tx_id=" .. tx_id)

  -- insert a new user
  __callFunction(MODULE_NAME_DB, "insert",
    [[INSERT INTO horde_users(user_id,
                              user_address,
                              user_block_no,
                              user_tx_id,
                              user_metadata)
             VALUES (?, ?, ?, ?, ?)]],
    user_id, user_address, block_no, tx_id, metadata_raw)

  -- success to write (201 Created)
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "createUser",
    __status_code = "201",
    __status_sub_code = "",
    user_id = user_id,
    user_info_list = {
      {
        user_address = user_address,
        user_block_no = block_no,
        user_tx_id = tx_id,
        user_metadata = metadata,
      },
    },
  }
end

function findUser(user_address)
  system.print(MODULE_NAME .. "findUser: user_address=" .. tostring(user_address))

  local sender = system.getSender()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "findUser: sender=" .. tostring(sender)
          .. ", block_no=" .. tostring(block_no))

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(user_address) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "findUser",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      user_address = user_address,
    }
  end

  -- check permissions (403.2 Read access forbidden)
  if sender ~= __getManifestAddress() then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "findUser",
      __status_code = "403",
      __status_sub_code = "2",
      __err_msg = "sender doesn't allow to use this method",
      sender = sender,
      user_address = user_address,
    }
  end

  -- check user ID
  local rows = __callFunction(MODULE_NAME_DB, "select",
    [[SELECT user_id FROM horde_users
        WHERE user_address = ?]],
    user_address)
  local user_list = {}
  local exist = false
  for _, v in pairs(rows) do
    local user_id = v[1]

    local rows2 = __callFunction(MODULE_NAME_DB, "select",
      [[SELECT user_address FROM horde_users
          WHERE user_id = ?
          ORDER BY user_block_no DESC]],
      user_id)

    for _, v2 in pairs(rows2) do
      table.insert(user_list, {
        user_id = user_id,
        user_address = v2[1],
      })
      exist = true
    end
  end

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "findUser",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find any user",
      sender = sender,
      user_address = user_address
    }
  end

  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "findUser",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    user_address = user_address,
    user_list = user_list,
  }
end

function getUser(user_id)
  system.print(MODULE_NAME .. "getUser: user_id=" .. tostring(user_id))

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "getUser: sender=" .. tostring(sender)
          .. ", block_no=" .. tostring(block_no))

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(user_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getUser",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      user_id = user_id,
    }
  end

  -- check inserted commands
  local rows = __callFunction(MODULE_NAME_DB, "select",
    [[SELECT user_address, user_block_no, user_tx_id, user_metadata
        FROM horde_users
        WHERE user_id = ?
        ORDER BY user_block_no DESC]],
    user_id)
  local user_info_list = {}

  local allowed = false
  local exist = false
  for _, v in pairs(rows) do
    local user_address = v[1]

    table.insert(user_info_list, {
      user_address = user_address,
      user_block_no = v[2],
      user_tx_id = v[3],
      user_metadata = json:decode(v[4]),
    })

    if sender == user_address then
      allowed = true
    end

    exist = true
  end

  --[[ TODO: cannot check the sender of a query contract
  -- check permissions (403.2 Read access forbidden)
  if allowed then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getUser",
      __status_code = "403",
      __status_sub_code = "2",
      __err_msg = "Sender (" .. sender .. ") doesn't allow to read the user(" .. user_id .. ") info",
      sender = sender,
      user_id = user_id
    }
  end
  ]]--

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getUser",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find the user",
      sender = sender,
      user_id = user_id
    }
  end

  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "getUser",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    user_id = user_id,
    user_info_list = user_info_list,
  }
end

function deleteUser(user_id, user_address)
  system.print(MODULE_NAME .. "deleteUser: user_id=" .. tostring(user_id)
          .. ", user_address=" .. tostring(user_address))

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "deleteUser: sender=" .. sender
          .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(user_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "deleteUser",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      user_id = user_id,
      user_address = user_address,
    }
  end

  -- read created user info
  local res = getUser(user_id)
  system.print(MODULE_NAME .. "deleteUser: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local user_info = nil
  local exist_sender = false
  for _, info in pairs(res['user_info_list']) do
    local ua = info['user_address']
    if ua == user_address then
      user_info = info
    end
    if ua == sender then
      exist_sender = true
    end
    if user_info ~= nil and exist_sender then
      break
    end
  end

  -- check permissions (403.1 Execute access forbidden)
  if not exist_sender then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "deleteUser",
      __status_code = "403",
      __status_sub_code = "1",
      __err_msg = "sender doesn't allow to delete the user",
      sender = sender,
      user_id = user_id,
      user_address = user_address,
    }
  end

  -- if not exist, (404 Not Found)
  if user_info == nil then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "deleteUser",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find the user",
      sender = sender,
      user_id = user_id,
      user_address = user_address,
    }
  end

  -- delete Pond
  __callFunction(MODULE_NAME_DB, "delete",
    "DELETE FROM horde_users WHERE user_id = ? AND user_address = ?"
    , user_id, user_address)

  -- TODO: save this activity

  -- 201 Created
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "deleteUser",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    user_id = user_id,
    user_info_list = {
      {
        user_address = user_address,
        user_block_no = user_info['user_block_no'],
        user_tx_id = user_info['user_tx_id'],
        user_metadata = user_info['user_metadata'],
      },
    },
  }
end

function updateUser(user_id, user_address, metadata)
  if type(metadata) == 'string' then
    metadata = json:decode(metadata)
  end
  local metadata_raw = json:encode(metadata)
  system.print(MODULE_NAME .. "updateUser: user_id=" .. tostring(user_id)
          .. ", user_address=" .. tostring(user_address)
          .. ", metadata=" .. metadata_raw)

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "updateUser: sender=" .. sender
          .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(user_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "updateUser",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      user_id = user_id,
      user_address = user_address,
    }
  end

  -- read created user info
  local res = getUser(user_id)
  system.print(MODULE_NAME .. "updateUser: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local user_info = nil
  local exist_sender = false
  for _, info in pairs(res['user_info_list']) do
    local ua = info['user_address']
    if ua == user_address then
      user_info = info
    end
    if ua == sender then
      exist_sender = true
    end
    if user_info ~= nil and exist_sender then
      break
    end
  end

  -- check permissions (403.3 Write access forbidden)
  if not exist_sender then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "updateUser",
      __status_code = "403",
      __status_sub_code = "3",
      __err_msg = "sender doesn't allow to update the user info",
      sender = sender,
      user_id = user_id,
      user_address = user_address,
    }
  end

  -- if not exist, (404 Not Found)
  if nil == user_info then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "updateUser",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find the user",
      sender = sender,
      user_id = user_id,
      user_address = user_address,
    }
  end

  -- update
  local block_no = system.getBlockheight()
  __callFunction(MODULE_NAME_DB, "update",
    [[UPDATE horde_users SET user_metadata = ?
        WHERE user_id = ? AND user_address = ?]],
    metadata_raw, user_id, user_address)

  -- TODO: save this activity

  -- 201 Created
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "updateUser",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    user_id = user_id,
    user_info_list = {
      {
        user_address = user_address,
        user_block_no = user_info['user_block_no'],
        user_tx_id = user_info['user_tx_id'],
        user_metadata = metadata,
      },
    },
  }
end

abi.register(createUser, findUser, getUser, deleteUser, updateUser)
