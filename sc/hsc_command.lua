--
-- Horde Smart Contract (HSC): Command
--

MODULE_NAME = "__HSC_COMMAND__"

MODULE_NAME_DB = "__MANIFEST_DB__"

MODULE_NAME_USER = "__HSC_USER__"
MODULE_NAME_CSPACE = "__HSC_SPACE_COMPUTING__"

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

--[[ ====================================================================== ]]--

function constructor(manifestAddress)
  __init__(manifestAddress)
  system.print(MODULE_NAME .. "constructor: manifestAddress=" .. manifestAddress)

  -- create command table
  __callFunction(MODULE_NAME_DB, "createTable",
    [[CREATE TABLE IF NOT EXISTS commands(
            cmd_type      TEXT NOT NULL,
            cmd_id        TEXT PRIMARY KEY,
            cmd_orderer   TEXT NOT NULL,
            cmd_block_no  INTEGER DEFAULT NULL,
            cmd_tx_id     TEXT NOT NULL,
            cmd_body      TEXT NOT NULL
  )]])

  -- create command targets table
  --  * status: INIT > EXEC > DONE
  __callFunction(MODULE_NAME_DB, "createTable",
    [[CREATE TABLE IF NOT EXISTS command_targets(
            cmd_id          TEXT NOT NULL,
            target_index    INTEGER DEFAULT NULL,
            cluster_id      TEXT,
            machine_id      TEXT,
            status          TEXT DEFAULT 'INIT',
            status_block_no INTEGER DEFAULT NULL,
            status_tx_id    TEXT NOT NULL,
            PRIMARY KEY(cmd_id, target_index),
            FOREIGN KEY(cmd_id) REFERENCES commands(cmd_id)
              ON DELETE CASCADE ON UPDATE NO ACTION
  )]])

  -- create command result table
  __callFunction(MODULE_NAME_DB, "createTable",
    [[CREATE TABLE IF NOT EXISTS command_results(
            cmd_id          TEXT NOT NULL,
            cluster_id      TEXT,
            machine_id      TEXT,
            result_id       TEXT NOT NULL,
            result_body     TEXT NOT NULL,
            result_block_no INTEGER DEFAULT NULL,
            result_tx_id    TEXT NOT NULL,
            PRIMARY KEY(cmd_id, cluster_id, machine_id, result_id),
            FOREIGN KEY(cmd_id) REFERENCES commands(cmd_id)
            	ON DELETE CASCADE ON UPDATE NO ACTION
  )]])
end

local function isEmpty(v)
  return nil == v or 0 == string.len(v)
end

function addCommand(cmd_type, cmd_body, target_list)
  if type(cmd_body) == 'string' then
    cmd_body = json:decode(cmd_body)
  end
  local cmd_body_raw = json:encode(cmd_body)
  if type(target_list) == 'string' then
    target_list = json:decode(target_list)
  end
  local target_list_raw = json:encode(target_list)
  system.print(MODULE_NAME .. "addCommand: cmd_type=" .. tostring(cmd_type)
          .. ", cmd_body=" .. cmd_body_raw
          .. ", target_list=" .. target_list_raw)

  local orderer = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "addCommand: orderer=" .. orderer
          .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(cmd_type) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "addCommand",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = orderer,
      cmd_type = cmd_type,
    }
  end

  -- tx id is for command id
  local cmd_id = system.getTxhash()
  system.print(MODULE_NAME .. "addCommand: cmd_id=" .. cmd_id)

  -- find orderer's all available addresses
  local res = __callFunction(MODULE_NAME_USER, "findUser", orderer)
  system.print(MODULE_NAME .. "addCommand: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local orderer_list = res["user_list"]

  -- insert a new command
  __callFunction(MODULE_NAME_DB, "insert",
    [[INSERT INTO commands(cmd_type,
                           cmd_id,
                           cmd_orderer,
                           cmd_block_no,
                           cmd_tx_id,
                           cmd_body)
             VALUES (?, ?, ?, ?, ?, ?)]],
    cmd_type, cmd_id, orderer, block_no, cmd_id, cmd_body_raw)

  -- one command to multiple Horde targets
  local exist = false
  for _, v in pairs(target_list) do
    local target_index = v['target_index']
    local cluster_id = v['cluster_id']
    local machine_id = v['machine_id']
    system.print(MODULE_NAME .. "addCommand target: index=" .. target_index
            .. ", cluster_id=" .. cluster_id
            .. ", machine_id=" .. machine_id)

    local owner
    local is_public
    if isEmpty(machine_id) then
      local res = __callFunction(MODULE_NAME_CSPACE, "getCluster", cluster_id)
      system.print(MODULE_NAME .. "addCommand: res=" .. json:encode(res))
      if "200" ~= res["__status_code"] then
        return res
      end
      owner = res["cluster_owner"]
      is_public = res["cluster_is_public"]
    else
      local res = __callFunction(MODULE_NAME_CSPACE, "getMachine",
        cluster_id, machine_id)
      system.print(MODULE_NAME .. "addCommand: res=" .. json:encode(res))
      if "200" ~= res["__status_code"] then
        return res
      end
      owner = res["machine_list"][1]["machine_owner"]
      is_public = res["cluster_is_public"]
    end

    system.print(MODULE_NAME .. "addCommand: owner=" .. tostring(owner))

    if not is_public then
      -- check orderer owns cluster and/or machine
      local found = false
      for _, o in pairs(orderer_list) do
        if owner == o['user_address'] then
          found = true
          break
        end
      end

      if not found then
        -- check permissions (403.1 Execute access forbidden)
        if system.getCreator() ~= system.getOrigin() then
          return {
            __module = MODULE_NAME,
            __block_no = block_no,
            __func_name = "addCommand",
            __status_code = "403",
            __status_sub_code = "1",
            __err_msg = "sender doesn't allow to use a cluster or machine",
            sender = orderer,
          }
        end
      end
    end

    __callFunction(MODULE_NAME_DB, "insert",
      [[INSERT INTO command_targets(cmd_id,
                                    cluster_id,
                                    machine_id,
                                    target_index,
                                    status,
                                    status_block_no,
                                    status_tx_id)
               VALUES (?, ?, ?, ?, ?, ?, ?)]],
      cmd_id, cluster_id, machine_id, target_index, "INIT", block_no, cmd_id)

    exist = true
  end

  if not exist then
    -- check permissions (403.1 Execute access forbidden)
    if system.getCreator() ~= system.getOrigin() then
      return {
        __module = MODULE_NAME,
        __block_no = block_no,
        __func_name = "addCommand",
        __status_code = "403",
        __status_sub_code = "1",
        __err_msg = "sender doesn't allow to add a system command",
        sender = orderer,
      }
    end

    -- TODO: system administrators' multisig approvement to execute
    --        using 'status' field.
    --        ex) Alice, Bob, and Carl are administrators.
    --          1. Alice adds a system command without any target.
    --            In 'status' field, put Alice's address
    --          2. Bob approves Alice's system command.
    --            In 'status' field, add Bob's address
    --          3. A MiniHorde reads the Alice's system command.
    --            In 'status' field, Alice and Bob addresses are included.
    --            So, 2/3 agreements makes execute the command on the MiniHorde.

    -- insert a system command for all Hordes
    __callFunction(MODULE_NAME_DB, "insert",
      [[INSERT INTO command_targets(cmd_id,
                                    status,
                                    status_block_no,
                                    status_tx_id)
                VALUES (?, ?, ?, ?)]],
      cmd_id, "INIT", block_no, cmd_id)
  end

  -- success to write (201 Created)
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "addCommand",
    __status_code = "201",
    __status_sub_code = "",
    sender = orderer,
    cmd_id = cmd_id,
    cmd_orderer = orderer,
    --[[
    cmd_type = cmd_type,
    cmd_block_no = block_no,
    cmd_tx_id = cmd_id,
    cmd_body = cmd_body,
    target_list = target_list
    ]]
  }
end

function getSystemCommands()
  system.print(MODULE_NAME .. "getSystemCommands")

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "getSystemCommands: sender=" .. tostring(sender)
          .. ", block_no=" .. tostring(block_no))

  local sql = [[SELECT commands.cmd_type, commands.cmd_id,
                        commands.cmd_orderer, commands.cmd_block_no,
                        commands.cmd_tx_id, commands.cmd_body,
                        command_targets.cluster_id, command_targets.machine_id,
                        command_targets.status, command_targets.status_block_no,
                        command_targets.status_tx_id,
                        command_targets.target_index
                  FROM commands INNER JOIN command_targets
                  WHERE commands.cmd_id = command_targets.cmd_id
                    AND command_targets.cluster_id IS NULL
                    AND command_targets.machine_id IS NULL
                  ORDER BY commands.cmd_block_no DESC]]
  local rows = __callFunction(MODULE_NAME_DB, "select", sql)

  local cmd_list = {}
  local exist = false
  for _, v in pairs(rows) do
    local cmd = {
      cmd_type = v[1],
      cmd_id = v[2],
      cmd_orderer = v[3],
      cmd_block_no = v[4],
      cmd_tx_id = v[5],
      cmd_body = json:decode(v[6]),
      cluster_id = v[7],
      machine_id = v[8],
      status = v[9],
      status_block_no = v[10],
      status_tx_id = v[11],
      target_index = v[12]
    }
    table.insert(cmd_list, cmd)

    exist = true
  end

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getSystemCommands",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find any command",
      sender = sender,
    }
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "getSystemCommands",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    cmd_list = cmd_list
  }
end

function getCommand(cmd_id)
  system.print(MODULE_NAME .. "getCommand: cmd_id=" .. tostring(cmd_id))

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "getCommand: sender=" .. tostring(sender)
          .. ", block_no=" .. tostring(block_no))

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(cmd_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getCommand",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      cmd_id = cmd_id,
    }
  end

  -- check inserted commands
  local rows = __callFunction(MODULE_NAME_DB, "select",
    [[SELECT cmd_type, cmd_orderer, cmd_block_no, cmd_tx_id, cmd_body
        FROM commands
        WHERE cmd_id = ?
        ORDER BY cmd_block_no]], cmd_id)
  local cmd_type
  local cmd_orderer
  local cmd_block_no
  local cmd_tx_id
  local cmd_body

  local exist = false
  for _, v in pairs(rows) do
    cmd_type = v[1]
    cmd_orderer = v[2]
    cmd_block_no = v[3]
    cmd_tx_id = v[4]
    cmd_body = json:decode(v[5])

    exist = true
  end

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getCommand",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find the command",
      sender = sender,
      cmd_id = cmd_id
    }
  end

  local cmd_list = {}
  rows = __callFunction(MODULE_NAME_DB, "select",
    [[SELECT cluster_id, machine_id, status, status_block_no, status_tx_id,
              target_index
        FROM command_targets
        WHERE cmd_id = ?
        ORDER BY status_block_no]], cmd_id)
  for _, v in pairs(rows) do
    local cmd = {
      cmd_type = cmd_type,
      cmd_id = cmd_id,
      cmd_orderer = cmd_orderer,
      cmd_block_no = cmd_block_no,
      cmd_tx_id = cmd_tx_id,
      cmd_body = cmd_body,
      cluster_id = v[1],
      machine_id = v[2],
      status = v[3],
      status_block_no = v[4],
      status_tx_id = v[5],
      target_index = v[6]
    }
    table.insert(cmd_list, cmd)

    exist = true
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "getCommand",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    cmd_list = cmd_list
  }
end

function getCommandsOfTarget(cluster_id, machine_id, status)
  system.print(MODULE_NAME .. "getCommandsOfTarget: cluster_id=" .. tostring(cluster_id)
          .. ", machine_id=" .. tostring(machine_id)
          .. ", status=" .. tostring(status))

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "getCommandsOfTarget: sender=" .. tostring(sender)
          .. ", block_no=" .. tostring(block_no))

  -- if not exist, (400 Bad Request)
  if isEmpty(cluster_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getCommandsOfTarget",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: need a target to search",
      sender = sender,
      cluster_id = cluster_id,
    }
  end

  local sql = [[SELECT commands.cmd_type, commands.cmd_id,
                        commands.cmd_orderer, commands.cmd_block_no,
                        commands.cmd_tx_id, commands.cmd_body,
                        command_targets.cluster_id, command_targets.machine_id,
                        command_targets.status, command_targets.status_block_no,
                        command_targets.status_tx_id,
                        command_targets.target_index
                  FROM commands INNER JOIN command_targets
                  WHERE commands.cmd_id = command_targets.cmd_id]]
  local rows

  if isEmpty(status) then
    sql = sql .. " AND ((command_targets.cluster_id = ?"
    if not isEmpty(machine_id) then
      sql = sql .. " AND command_targets.machine_id = ?"
    end
    sql = sql .. ") OR command_targets.cluster_id IS NULL)"
    sql = sql .. " ORDER BY commands.cmd_block_no"

    if isEmpty(machine_id) then
      rows = __callFunction(MODULE_NAME_DB, "select", sql, cluster_id)
    else
      rows = __callFunction(MODULE_NAME_DB, "select", sql, cluster_id, machine_id)
    end
  else
    sql = sql .. " AND ((command_targets.cluster_id = ?"
    if not isEmpty(machine_id) then
      sql = sql .. " AND command_targets.machine_id = ?"
    end
    sql = sql .. ") OR command_targets.cluster_id IS NULL)"
    sql = sql .. " AND command_targets.status = ?"
    sql = sql .. " ORDER BY commands.cmd_block_no"

    if isEmpty(machine_id) then
      rows = __callFunction(MODULE_NAME_DB, "select",
        sql, cluster_id, status)
    else
      rows = __callFunction(MODULE_NAME_DB, "select",
        sql, cluster_id, machine_id, status)
    end
  end

  local cmd_list = {}
  local exist = false
  for _, v in pairs(rows) do
    local cmd = {
      cmd_type = v[1],
      cmd_id = v[2],
      cmd_orderer = v[3],
      cmd_block_no = v[4],
      cmd_tx_id = v[5],
      cmd_body = json:decode(v[6]),
      cluster_id = v[7],
      machine_id = v[8],
      status = v[9],
      status_block_no = v[10],
      status_tx_id = v[11],
      target_index = v[12],
    }
    table.insert(cmd_list, cmd)

    exist = true
  end

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getCommandsOfTarget",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find any command",
      sender = sender,
      cluster_id = cluster_id,
      machine_id = machine_id,
      status = status
    }
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "getCommandsOfTarget",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    cmd_list = cmd_list
  }
end

function updateTarget(cmd_id, cluster_id, machine_id, target_index, status)
  system.print(MODULE_NAME .. "updateTarget: cmd_id=" .. tostring(cmd_id)
          .. ", cluster_id=" .. tostring(cluster_id)
          .. ", machine_id=" .. tostring(machine_id)
          .. ", target_index=" .. tostring(target_index)
          .. ", status=" .. tostring(status))

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "updateTarget: sender=" .. sender
          .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(cmd_id) or isEmpty(cluster_id) or isEmpty(status) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "updateTarget",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      cmd_id = cmd_id,
      cluster_id = cluster_id,
      status = status
    }
  end

  local c_or_m_owner
  local c_or_m_id
  if isEmpty(machine_id) then
    local res = __callFunction(MODULE_NAME_CSPACE, "getCluster", cluster_id)
    system.print(MODULE_NAME .. "updateTarget: res=" .. json:encode(res))
    if "200" ~= res["__status_code"] then
      return res
    end
    c_or_m_owner = res["cluster_owner"]
    c_or_m_id = res["cluster_id"]
  else
    local res = __callFunction(MODULE_NAME_CSPACE, "getMachine",
      cluster_id, machine_id)
    system.print(MODULE_NAME .. "updateTarget: res=" .. json:encode(res))
    if "200" ~= res["__status_code"] then
      return res
    end
    c_or_m_owner = res["machine_list"][1]["machine_owner"]
    c_or_m_id = res["machine_list"][1]["machine_id"]
  end

  -- check permissions (403.3 Write access forbidden)
  if sender ~= c_or_m_owner and sender ~= c_or_m_id then
    -- TODO: check sender's update permission of target
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "updateTarget",
      __status_code = "403",
      __status_sub_code = "3",
      __err_msg = "sender doesn't allow to update the target of the command",
      sender = sender,
      cmd_id = cmd_id,
      cluster_id = cluster_id,
      machine_id = machine_id,
      target_index = target_index,
      status = status
    }
  end

  -- insert or replace
  local tx_id = system.getTxhash()
  system.print(MODULE_NAME .. "updateTarget: tx_id=" .. tx_id)

  local res = getCommand(cmd_id)
  system.print(MODULE_NAME .. "updateTarget: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local cmd = res['cmd_list'][1]

  local sql = [[UPDATE command_targets
                   SET status=?, status_block_no=?, status_tx_id=?
                 WHERE cmd_id=? AND cluster_id=?]]
  if nil ~= machine_id then
    sql = sql .. ' AND machine_id=?'

    if nil ~= target_index then
      sql = sql .. ' AND target_index=?'
      __callFunction(MODULE_NAME_DB, "update", sql,
        status, block_no, tx_id, cmd_id, cluster_id, machine_id, target_index)
    else
      __callFunction(MODULE_NAME_DB, "update", sql,
        status, block_no, tx_id, cmd_id, cluster_id, machine_id)
    end
  else
    __callFunction(MODULE_NAME_DB, "update", sql,
      status, block_no, tx_id, cmd_id, cluster_id)
  end

  -- 201 Created
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "updateTarget",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    cmd_id = cmd_id,
    --[[
    cmd_type = cmd["cmd_type"],
    cmd_orderer = cmd['cmd_orderer'],
    cmd_block_no = cmd["cmd_block_no"],
    cmd_tx_id = cmd["cmd_tx_id"],
    cmd_body = cmd["cmd_body"],
    cluster_id = cluster_id,
    machine_id = machine_id,
    status = status,
    status_block_no = block_no,
    status_tx_id = tx_id,
    target_index = target_index
    ]]
  }
end

function addCommandResult(cmd_id, cluster_id, machine_id, target_index, result)
  if type(result) == 'string' then
    result = json:decode(result)
  end
  local result_raw = json:encode(result)
  system.print(MODULE_NAME .. "addCommandResult: cmd_id=" .. tostring(cmd_id)
          .. ", cluster_id=" .. tostring(cluster_id)
          .. ", machine_id=" .. tostring(machine_id)
          .. ", target_index=" .. tostring(target_index)
          .. ", result=" .. result_raw)

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "addCommandResult: sender=" .. sender
          .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(cmd_id) or isEmpty(cluster_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "addCommandResult",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      cmd_id = cmd_id,
      cluster_id = cluster_id
    }
  end

  local c_or_m_owner
  local c_or_m_id
  if isEmpty(machine_id) then
    local res = __callFunction(MODULE_NAME_CSPACE, "getCluster", cluster_id)
    system.print(MODULE_NAME .. "addCommandResult: res=" .. json:encode(res))
    if "200" ~= res["__status_code"] then
      return res
    end
    c_or_m_owner = res["cluster_owner"]
    c_or_m_id = res["cluster_id"]
  else
    local res = __callFunction(MODULE_NAME_CSPACE, "getMachine",
      cluster_id, machine_id)
    system.print(MODULE_NAME .. "addCommandResult: res=" .. json:encode(res))
    if "200" ~= res["__status_code"] then
      return res
    end
    c_or_m_owner = res["machine_list"][1]["machine_owner"]
    c_or_m_id = res["machine_list"][1]["machine_id"]
  end

  -- check permissions (403.3 Write access forbidden)
  if sender ~= c_or_m_owner and sender ~= c_or_m_id then
    -- TODO: check sender is same with Horde owner or cNode owner
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "addCommandResult",
      __status_code = "403",
      __status_sub_code = "3",
      __err_msg = "sender doesn't allow to add result of the command",
      sender = sender,
      cmd_id = cmd_id,
      cluster_id = cluster_id,
      machine_id = machine_id
    }
  end

  local res = getCommand(cmd_id)
  system.print(MODULE_NAME .. "addCommandResult: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local cmd = res['cmd_list'][1]
  if cmd['status'] == 'DONE' then
    return getCommandResult(cmd_id)
  end

  -- tx id is for command id
  local tx_id = system.getTxhash()
  system.print(MODULE_NAME .. "addCommandResult: tx_id=" .. tx_id)

  -- insert command result
  __callFunction(MODULE_NAME_DB, "insert",
    [[INSERT INTO command_results(cmd_id,
                                  cluster_id,
                                  machine_id,
                                  result_id,
                                  result_body,
                                  result_block_no,
                                  result_tx_id)
             VALUES (?, ?, ?, ?, ?, ?, ?)]],
    cmd_id, cluster_id, machine_id, tx_id, result_raw, block_no, tx_id)

  -- update command status
  res = updateTarget(cmd_id, cluster_id, machine_id, target_index, 'DONE')

  -- 201 Created
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "addCommandResult",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    cmd_id = cmd_id,
    result_id = tx_id,
    --[[
    cmd_type = res['cmd_type'],
    cmd_orderer = res['cmd_orderer'],
    cmd_block_no = res["cmd_block_no"],
    cmd_tx_id = res["cmd_tx_id"],
    cmd_body = res["cmd_body"],
    cluster_id = cluster_id,
    machine_id = machine_id,
    status = res['status'],
    status_block_no = res['status_block_no'],
    status_tx_id = res['status_tx_id'],
    target_index = res['target_index'],
    result_block_no = block_no,
    result_tx_id = tx_id,
    result_body = result
    ]]
  }
end

function getCommandResult(cmd_id)
  system.print(MODULE_NAME .. "getCommandResult: cmd_id=" .. tostring(cmd_id))

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "getCommandResult: sender=" .. tostring(sender)
          .. ", block_no=" .. tostring(block_no))

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(cmd_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
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

  local cmd_orderer = res['cmd_list'][1]["cmd_orderer"]

  --[[ TODO: cannot check the sender of a query contract
  -- check permissions (403.2 Read access forbidden)
  if sender ~= orderer then
    -- TODO: check sender's read result permission of the command
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getCommandResult",
      __status_code = "403",
      __status_sub_code = "2",
      __err_msg = "Sender (" .. sender .. ") doesn't allow to read the result of the command (" .. cmd_id .. ")",
      sender = sender,
      cmd_id = cmd_id
    }
  end
  ]]--

  local rows = __callFunction(MODULE_NAME_DB, "select",
    [[SELECT cluster_id, machine_id, result_id,
              result_block_no, result_tx_id, result_body
        FROM command_results
        WHERE cmd_id = ?
        ORDER BY cluster_id, result_block_no DESC]],
    cmd_id)
  local result_list = {}
  local exist = false
  for _, v in pairs(rows) do
    local item = {
      cluster_id = v[1],
      machine_id = v[2],
      result_id = v[3],
      result_block_no = v[4],
      result_tx_id = v[5],
      result_body = json:decode(v[6])
    }
    table.insert(result_list, item)

    exist = true
  end

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getCommandResult",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find any result of the command",
      sender = sender,
      cmd_id = cmd_id
    }
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "getCommandResult",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    cmd_id = cmd_id,
    result_list = result_list
  }
end

abi.register(addCommand, getSystemCommands, getCommand, getCommandsOfTarget,
  updateTarget, addCommandResult, getCommandResult)
