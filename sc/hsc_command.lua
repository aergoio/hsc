--
-- Horde Smart Contract (HSC): Command
--

MODULE_NAME = "__HSC_COMMAND__"

MODULE_NAME_DB = "__MANIFEST_DB__"

MODULE_NAME_BSPACE = "__HSC_SPACE_BLOCKCHAIN__"
MODULE_NAME_CSPACE = "__HSC_SPACE_COMPUTING__"

state.var {
  -- contant variables
  _MANIFEST_ADDRESS = state.value(),
}

local function __init__(manifestAddress)
  _MANIFEST_ADDRESS:set(manifestAddress)
  local scAddress = system.getContractID()
  system.print(MODULE_NAME .. "__init__: sc_address=" .. scAddress)
  contract.call(_MANIFEST_ADDRESS:get(), "__init_module__", MODULE_NAME, scAddress)
end

local function __callFunction(module_name, func_name, ...)
  system.print(MODULE_NAME .. "__callFucntion: module_name=" .. module_name .. ", func_name=" .. func_name)
  return contract.call(_MANIFEST_ADDRESS:get(), "__call_module_function__", module_name, func_name, ...)
end

--[[ ============================================================================================================== ]]--

function constructor(manifestAddress)
  __init__(manifestAddress)
  system.print(MODULE_NAME .. "constructor: manifestAddress=" .. manifestAddress)
 
  -- create command table
  __callFunction(MODULE_NAME_DB, "createTable", [[CREATE TABLE IF NOT EXISTS commands(
    cmd_type      TEXT NOT NULL,
    cmd_id        TEXT PRIMARY KEY,
    orderer       TEXT NOT NULL,
    cmd_block_no  INTEGER DEFAULT NULL,
    cmd_body      TEXT NOT NULL
  )]])
 
  -- create command targets table
  --  * status: INIT > EXECUTING > SUCCESS or ERROR
  __callFunction(MODULE_NAME_DB, "createTable", [[CREATE TABLE IF NOT EXISTS command_targets(
    cmd_id          TEXT NOT NULL,
    horde_id        TEXT,
    cnode_id        TEXT,
    status          TEXT DEFAULT 'INIT',
    status_block_no INTEGER DEFAULT NULL,
    PRIMARY KEY(cmd_id, horde_id, cnode_id),
    FOREIGN KEY(cmd_id) REFERENCES command(cmd_id)
      ON DELETE CASCADE ON UPDATE NO ACTION
  )]])
 
  -- create command result table
  __callFunction(MODULE_NAME_DB, "createTable", [[CREATE TABLE IF NOT EXISTS command_results(
    cmd_id          TEXT NOT NULL,
    horde_id        TEXT,
    cnode_id        TEXT,
    result_id       TEXT NOT NULL,
    result          TEXT NOT NULL,
    result_block_no INTEGER DEFAULT NULL,
    PRIMARY KEY(cmd_id, horde_id, cnode_id, result_id),
    FOREIGN KEY(cmd_id) REFERENCES commands(cmd_id)
    	ON DELETE CASCADE ON UPDATE NO ACTION
  )]])
end

local function isEmpty(v)
  return nil == v or 0 == string.len(v)
end

function addCommand(cmd_type, cmd_body, target_list)
  -- TODO: report JSON type argument is not accepted for delegate call
  cmd_body = json:decode(cmd_body)
  local cmd_body_raw = json:encode(cmd_body)
  target_list = json:decode(target_list)
  local target_list_raw = json:encode(target_list)
  system.print(MODULE_NAME .. "addCommand: cmd_type=" .. cmd_type .. ", cmd_body=" .. cmd_body_raw .. ", target_list=" .. target_list_raw)

  -- tx id is for command id
  local cmd_id = system.getTxhash()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "addCommand: cmd_id=" .. cmd_id .. ", block_no=" .. block_no)

  -- TODO: how to check sender's authorization?
  local orderer = system.getSender()
  system.print(MODULE_NAME .. "addCommand: orderer=" .. orderer)

  -- insert a new command
  __callFunction(MODULE_NAME_DB, "insert",
    "INSERT INTO commands(cmd_type, cmd_id, orderer, cmd_block_no, cmd_body) VALUES (?, ?, ?, ?, ?)",
    cmd_type, cmd_id, orderer, block_no, cmd_body_raw)

  -- one command to multiple Horde targets
  local exist = false
  for _, v in pairs(target_list) do
    local horde_id = v['horde_id']
    local cnode_id = v['cnode_id']
    system.print(MODULE_NAME .. "addCommand target: horde_id=" .. horde_id .. ", cnode_id=" .. cnode_id)

    __callFunction(MODULE_NAME_DB, "insert",
      "INSERT INTO command_targets(cmd_id, horde_id, cnode_id, status, status_block_no) VALUES (?, ?, ?, ?, ?)",
      cmd_id, horde_id, cnode_id, "INIT", block_no)

    exist = true
  end

  if not exist then
    -- insert command for all Hordes
    __callFunction(MODULE_NAME_DB, "insert",
      "INSERT INTO command_targets(cmd_id) VALUES (?)", cmd_id)
  end

  -- success to write (201 Created)
  return {
    __module = MODULE_NAME,
    __func_name = "addCommand",
    __status_code = "201",
    __status_sub_code = "",
    cmd_type = cmd_type,
    cmd_id = cmd_id,
    orderer = orderer,
    cmd_block_no = block_no,
    cmd_body = cmd_body,
    target_list = target_list
  }
end

function getCommand(cmd_id)
  system.print(MODULE_NAME .. "getCommand: cmd_id=" .. cmd_id)

  -- check inserted commands
  local rows = __callFunction(MODULE_NAME_DB, "select",
    "SELECT cmd_type, orderer, cmd_block_no, cmd_body FROM commands WHERE cmd_id = ?", cmd_id)
  local cmd_type
  local orderer
  local cmd_block_no
  local cmd_body

  local exist = false
  for _, v in pairs(rows) do
    cmd_type = v[1]
    orderer = v[2]
    cmd_block_no = v[3]
    cmd_body = json:decode(v[4])

    exist = true
  end

  local sender = system.getSender()
  system.print(MODULE_NAME .. "getCommand: sender=" .. sender)

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __func_name = "getCommand",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find the command (" .. cmd_id .. ")",
      sender = sender,
      cmd_id = cmd_id
    }
  end

  local target_list = {}
  rows = __callFunction(MODULE_NAME_DB, "select",
    "SELECT horde_id, cnode_id, status, status_block_no FROM command_targets WHERE cmd_id = ?", cmd_id)
  for _, v in pairs(rows) do
    local target = {
      horde_id = v[1],
      cnode_id = v[2],
      status = v[3],
      status_block_no = v[4],
    }
    table.insert(target_list, target)

    exist = true
  end

  return {
    __module = MODULE_NAME,
    __func_name = "getCommand",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    cmd_type = cmd_type,
    cmd_id = cmd_id,
    orderer = orderer,
    cmd_block_no = cmd_block_no,
    cmd_body = cmd_body,
    target_list = target_list
  }
end

function getCommandOfTarget(horde_id, cnode_id, status)
  system.print(MODULE_NAME .. "getCommandOfTarget: horde_id=" .. tostring(horde_id) .. ", cnode_id=" .. tostring(cnode_id) .. ", status=" .. tostring(status))

  local sender = system.getSender()
  system.print(MODULE_NAME .. "getCommandOfTarget: sender=" .. sender)

  -- if not exist, (400 Bad Request)
  if isEmpty(horde_id) then
    return {
      __module = MODULE_NAME,
      __func_name = "getCommandOfTarget",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: need a target to search",
      sender = sender,
      horde_id = horde_id,
      cnode_id = cnode_id
    }
  end

  local sql = [[SELECT commands.cmd_type, commands.cmd_id, commands.orderer, commands.cmd_block_no, commands.cmd_body
                        command_targets.horde_id, command_targets.cnode_id,
                        command_targets.status, command_targets.status_block_no
                  FROM commands INNER JOIN command_targets
                  WHERE commands.cmd_id = command_targets.cmd_id]]
  local rows

  if isEmpty(status) then
    sql = sql .. " AND command_targets.horde_id = ?"
    if not isEmpty(cnode_id) then
      sql = sql .. " AND command_targets.cnode_id = ?"
    end
    sql = sql .. " ORDER BY commands.cmd_block_no"

    if isEmpty(cnode_id) then
      rows = __callFunction(MODULE_NAME_DB, "select", sql, horde_id)
    else
      rows = __callFunction(MODULE_NAME_DB, "select", sql, horde_id, cnode_id)
    end
  else
    sql = sql .. " AND ((command_targets.horde_id = ?"
    if not isEmpty(cnode_id) then
      sql = sql .. " AND command_targets.cnode_id = ?"
    end
    sql = sql .. ") OR command_targets.horde_id IS NULL) AND command_targets.status = ? ORDER BY commands.cmd_block_no"

    if isEmpty(cnode_id) then
      rows = __callFunction(MODULE_NAME_DB, "select", sql, horde_id, status)
    else
      rows = __callFunction(MODULE_NAME_DB, "select", sql, horde_id, cnode_id, status)
    end
  end

  local cmd_list = {}
  local exist = false
  for _, v in pairs(rows) do
    local cmd = {
      cmd_type = v[1],
      cmd_id = v[2],
      orderer = v[3],
      cmd_block_no = v[4],
      cmd_body = v[5],
      horde_id = v[6],
      cnode_id = v[7],
      status = v[8],
      status_block_no = v[9]
    }
    table.insert(cmd_list, cmd)

    exist = true
  end

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __func_name = "getCommandOfTarget",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find any command",
      sender = sender,
      horde_id = horde_id,
      cnode_id = cnode_id
    }
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __func_name = "getCommandOfTarget",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    horde_id = horde_id,
    cnode_id = cnode_id,
    cmd_list = cmd_list
  }
end

function updateTarget(cmd_id, horde_id, cnode_id, status)
  system.print(MODULE_NAME .. "updateTarget: cmd_id=" .. tostring(cmd_id) .. ", horde_id=" .. tostring(horde_id) .. ", cnode_id=" .. tostring(cnode_id) .. ", status=" .. tostring(status))

  local sender = system.getSender()
  system.print(MODULE_NAME .. "updateTarget: sender=" .. sender)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(cmd_id) or isEmpty(horde_id) or isEmpty(status) then
    return {
      __module = MODULE_NAME,
      __func_name = "updateTarget",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      cmd_id = cmd_id,
      horde_id = horde_id,
      status = status
    }
  end

  local res = getCommand(cmd_id)
  if "200" ~= res["__status_code"] then
    return res
  end
  system.print(MODULE_NAME .. "updateTarget: res=" .. json:encode(res))

  local orderer = res["orderer"]

  -- check permissions (403.3 Write access forbidden)
  if sender ~= orderer then
    -- TODO: check sender's update permission of target
    return {
      __module = MODULE_NAME,
      __func_name = "updateTarget",
      __status_code = "403",
      __status_sub_code = "3",
      __err_msg = "Sender (" .. sender .. ") doesn't allow to update the target of the command (" .. cmd_id .. ")",
      sender = sender,
      cmd_id = cmd_id
    }
  end

  -- insert or replace
  local block_no = system.getBlockheight()
  __callFunction(MODULE_NAME_DB, "insert",
    "INSERT OR REPLACE INTO command_targets (cmd_id, horde_id, cmd_id, status, status_block_no) VALUES (?, ?, ?, ?, ?)",
    cmd_id, horde_id, cnode_id, status, block_no)

  -- 201 Created
  return {
    __module = MODULE_NAME,
    __func_name = "updateTarget",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    cmd_type = res["cmd_type"],
    cmd_id = cmd_id,
    orderer = orderer,
    cmd_block_no = res["cmd_block_no"],
    cmd_body = res["cmd_body"],
    horde_id = horde_id,
    cnode_id = cnode_id,
    status = status,
    status_block_no = block_no,
  }
end

function addCommandResult(cmd_id, horde_id, cnode_id, result)
  -- TODO: report JSON type argument is not accepted for delegate call
  result = json:decode(result)
  local result_raw = json:encode(result)
  system.print(MODULE_NAME .. "addCommandResult: cmd_id=" .. cmd_id .. ", horde_id=" .. horde_id .. ", cnode_id=" .. tostring(cnode_id) .. ", result=" .. result_raw)

  local sender = system.getSender()
  system.print(MODULE_NAME .. "addCommandResult: sender=" .. sender)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(cmd_id) or isEmpty(horde_id) then
    return {
      __module = MODULE_NAME,
      __func_name = "addCommandResult",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      cmd_id = cmd_id,
      horde_id = horde_id
    }
  end

  local horde_owner
  if isEmpty(cnode_id) then
    local res = __callFunction(MODULE_NAME_CSPACE, "getHorde", horde_id)
    if "200" ~= res["__status_code"] then
      return res
    end
    system.print(MODULE_NAME .. "addCommandResult: res=" .. json:encode(res))
    horde_owner = res["horde_owner"]
  else
    local res = __callFunction(MODULE_NAME_CSPACE, "getCNode", horde_id, cnode_id)
    if "200" ~= res["__status_code"] then
      return res
    end
    system.print(MODULE_NAME .. "addCommandResult: res=" .. json:encode(res))
    horde_owner = res["cnode_list"][1]["cnode_owner"]
  end

  -- check permissions (403.3 Write access forbidden)
  if sender ~= horde_owner then
    -- TODO: check sender is same with Horde owner or cNode owner
    return {
      __module = MODULE_NAME,
      __func_name = "addCommandResult",
      __status_code = "403",
      __status_sub_code = "3",
      __err_msg = "Sender (" .. sender .. ") doesn't allow to update the target of the command (" .. cmd_id .. ")",
      sender = sender,
      cmd_id = cmd_id
    }
  end

  -- tx id is for command id
  local result_id = system.getTxhash()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "addCommandResult: result_id=" .. result_id .. ", block_no=" .. block_no)

  -- insert command result
  __callFunction(MODULE_NAME_DB, "insert",
    "INSERT INTO command_results(cmd_id, horde_id, cnode_id, result_id, result, result_block_no) VALUES (?, ?, ?, ?, ?, ?)",
    cmd_id, horde_id, cnode_id, result_id, result_raw, block_no)

  -- 201 Created
  return {
    __module = MODULE_NAME,
    __func_name = "addCommandResult",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    cmd_id = cmd_id,
    horde_id = horde_id,
    cnode_id = cnode_id,
    result_id = result_id,
    result_block_no = block_no,
    result = result
  }
end

function getCommandResult(cmd_id)
  system.print(MODULE_NAME .. "getCommandResult: cmd_id=" .. cmd_id)

  local sender = system.getSender()
  system.print(MODULE_NAME .. "getCommandResult: sender=" .. sender)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(cmd_id) then
    return {
      __module = MODULE_NAME,
      __func_name = "getCommandResult",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      cmd_id = cmd_id
    }
  end

  local res = getCommand(cmd_id)
  if "200" ~= res["__status_code"] then
    return res
  end
  system.print(MODULE_NAME .. "getCommandResult: res=" .. json:encode(res))

  local orderer = res["orderer"]

  -- check permissions (403.2 Read access forbidden)
  if sender ~= orderer then
    -- TODO: check sender's read result permission of the command
    return {
      __module = MODULE_NAME,
      __func_name = "getCommandResult",
      __status_code = "403",
      __status_sub_code = "2",
      __err_msg = "Sender (" .. sender .. ") doesn't allow to read the result of the command (" .. cmd_id .. ")",
      sender = sender,
      cmd_id = cmd_id
    }
  end

  local rows = __callFunction(MODULE_NAME_DB, "select",
    "SELECT horde_id, cnode_id, result_id, result_block_no, result FROM command_results WHERE cmd_id = ? ORDER BY horde_id, result_block_no",
    cmd_id)
  local result_list = {}
  local exist = false
  for _, v in pairs(rows) do
    local item = {
      horde_id = v[1],
      cnode_id = v[2],
      result_id = v[3],
      result_block_no = v[4],
      result_detail = json:decode(v[5])
    }
    table.insert(result_list, item)

    exist = true
  end

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __func_name = "getCommandResult",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find the result of the command (" .. cmd_id .. ")",
      sender = sender,
      cmd_id = cmd_id
    }
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __func_name = "getCommandResult",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    cmd_id = cmd_id,
    result_list = result_list
  }
end

abi.register(addCommand, getCommand, getCommandOfTarget, updateTarget, addCommandResult, getCommandResult)
