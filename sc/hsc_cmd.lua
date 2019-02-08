--
-- Horde Smart Contract (HSC): Command
--

MODULE_NAME = "__HSC_CMD__"

MODULE_NAME_DB = "__MANIFEST_DB__"

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
  __callFunction(MODULE_NAME_DB, "createTable", [[CREATE TABLE IF NOT EXISTS command(
    cmd_id          TEXT    PRIMARY KEY,
    block_height    INTEGER DEFAULT NULL,
    cmd_context     TEXT    NOT NULL
  )]])
 
  -- create command targets table
  __callFunction(MODULE_NAME_DB, "createTable", [[CREATE TABLE IF NOT EXISTS command_target(
    cmd_id      TEXT NOT NULL,
    horde_id    TEXT NOT NULL,
    finished    INTEGER DEFAULT NULL,
    FOREIGN KEY(cmd_id) REFERENCES command(cmd_id)
      ON DELETE CASCADE ON UPDATE NO ACTION
  )]])
 
  -- create command result table
  __callFunction(MODULE_NAME_DB, "createTable", [[CREATE TABLE IF NOT EXISTS command_result(
    cmd_id        TEXT NOT NULL,
    horde_id      TEXT NOT NULL,
    result        TEXT NOT NULL,
    result_time   INTEGER DEFAULT 0,
    FOREIGN KEY(cmd_id) REFERENCES command(cmd_id)
    	ON DELETE CASCADE ON UPDATE NO ACTION
  )]])
end

function insertCommand(cmd, ...)
  -- tx id is for command id
  local cmd_id = system.getTxhash()
  local block_height = system.getBlockheight()
  local args = {...}
  system.print(MODULE_NAME .. "insertCommand: cmd_id=" .. cmd_id .. ", block_height=" .. block_height .. ", cmd=" .. cmd .. ", args=" .. json:encode(args))

  -- insert a new command
  __callFunction(MODULE_NAME_DB, "insert",
                 "INSERT INTO command(cmd_id, block_height, cmd_context) VALUES (?, ?, ?)",
                 cmd_id, block_height, cmd)

  -- one command to multiple HMCs
  for _, v in pairs(args) do
    local horde_id = tostring(v)
    system.print(MODULE_NAME .. "insert command target: horde_id=" .. horde_id)
    __callFunction(MODULE_NAME_DB, "insert",
                   "INSERT INTO command_target(cmd_id, horde_id) VALUES (?, ?)", 
                   cmd_id, horde_id)
  end
end

function queryCommand(horde_id, finished, all)
  system.print(MODULE_NAME .. "queryCommand: horde_id=" .. horde_id .. ", finished=" .. tostring(finished) .. ", all=" .. tostring(all))

  local rows
  if not all then
    if not finished then
      -- default query
      system.print(MODULE_NAME .. "query not finished commands")
      rows = __callFunction(MODULE_NAME_DB, "select",
                            [[SELECT command.cmd_id, command.cmd_context, command_target.finished
                              FROM command INNER JOIN command_target
                              WHERE command.cmd_id = command_target.cmd_id
                                AND command_target.horde_id = ?
                                AND command_target.finished IS NULL
                              ORDER BY command.block_height]],
                            horde_id)
    else
      -- finished=True query
      system.print(MODULE_NAME .. "query finished commands")
      rows = __callFunction(MODULE_NAME_DB, "select",
                            [[SELECT command.cmd_id, command.cmd_context, command_target.finished
                              FROM command INNER JOIN command_target
                              WHERE command.cmd_id = command_target.cmd_id
                                AND command_target.horde_id = ?
                                AND command_target.finished IS NOT NULL
                              ORDER BY command.block_height]],
                            horde_id)
    end
  else
    -- all=True and finished=True query
    system.print(MODULE_NAME .. "query all commands")
    rows = __callFunction(MODULE_NAME_DB, "select",
                          [[SELECT command.cmd_id, command.cmd_context, command_target.finished
                            FROM command INNER JOIN command_target
                            WHERE command.cmd_id = command_target.cmd_id
                              AND command_target.horde_id = ?
                            ORDER BY command.block_height]],
                          horde_id)
  end

  local cmd_list = {}
  for _, v in pairs(rows) do
    local item = {
      cmd_id = v[1],
      cmd = v[2],
      finished = v[3]
    }
    table.insert(cmd_list, item)
  end

  system.print("cmd_list=" .. json:encode(cmd_list))

  return {
    __module = MODULE_NAME,
    __func_name = "queryCommand",
    cmd_list = cmd_list
  }
end

function insertCommandResult(cmd_id, horde_id, result, result_time)
  system.print(MODULE_NAME .. "insertCommandResult: cmd_id=" .. cmd_id .. ", horde_id=" .. horde_id .. ", result=" .. result)

  -- insert command result
  __callFunction(MODULE_NAME_DB, "insert",
                 "INSERT INTO command_result(cmd_id, horde_id, result, result_time) VALUES (?, ?, ?, ?)",
                 cmd_id, horde_id, result, result_time)
end

function queryCommandResult(cmd_id)
  system.print(MODULE_NAME .. "queryCommandResult: cmd_id=" .. cmd_id)

  local rows = __callFunction(MODULE_NAME_DB, "select",
                              "SELECT horde_id, result, result_time FROM command_result WHERE cmd_id = ? ORDER BY horde_id, result_time",
                              cmd_id)
  local result_list = {}
  for _, v in pairs(rows) do
    local item = {
      horde_id = v[1],
      result = v[2],
      result_time = v[3]
    }
    table.insert(result_list, item)
  end

  system.print("result_list=" .. json:encode(result_list))

  return {
    __module = MODULE_NAME,
    __func_name = "queryCommandResult",
    result_list = result_list
  }
end


abi.register(insertCommand, queryCommand, insertCommandResult, queryCommandResult)
