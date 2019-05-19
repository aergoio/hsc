--
-- Horde Smart Contract (HSC): Computing space
--

MODULE_NAME = "__HSC_SPACE_COMPUTING__"

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

--[[ ====================================================================== ]]--

function constructor(manifestAddress)
  __init__(manifestAddress)
  system.print(MODULE_NAME .. "constructor: manifestAddress=" .. manifestAddress)

  -- create Horde master metadata table for Machines
  __callFunction(MODULE_NAME_DB, "createTable",
    [[CREATE TABLE IF NOT EXISTS clusters(
            cluster_owner     TEXT NOT NULL,
            cluster_name      TEXT,
            cluster_id        TEXT NOT NULL,
            cluster_is_public INTEGER DEFAULT 0,
            cluster_block_no  INTEGER DEFAULT NULL,
            cluster_tx_id     TEXT NOT NULL,
            cluster_metadata  TEXT,
            PRIMARY KEY (cluster_id)
  )]])

  -- create Horde Machine metadata table
  __callFunction(MODULE_NAME_DB, "createTable",
    [[CREATE TABLE IF NOT EXISTS machines(
            cluster_id        TEXT NOT NULL,
            machine_owner     TEXT NOT NULL,
            machine_name      TEXT,
            machine_id        TEXT NOT NULL,
            machine_block_no  INTEGER DEFAULT NULL,
            machine_tx_id     TEXT NOT NULL,
            machine_metadata  TEXT,
            PRIMARY KEY(cluster_id, machine_id),
            FOREIGN KEY(cluster_id) REFERENCES clusters(cluster_id)
              ON DELETE CASCADE ON UPDATE NO ACTION
  )]])

  -- create Horde access control table
  --    * ac_detail = [TODO: categorize all object and then designate (CREATE/READ/WRITE/DELETE)]
  __callFunction(MODULE_NAME_DB, "createTable",
    [[CREATE TABLE IF NOT EXISTS hordes_ac_list(
            cluster_id      TEXT NOT NULL,
            account_address TEXT NOT NULL,
            ac_detail       TEXT,
            PRIMARY KEY (cluster_id, account_address),
            FOREIGN KEY (cluster_id) REFERENCES clusters(cluster_id)
              ON DELETE CASCADE ON UPDATE NO ACTION
  )]])
end

local function isEmpty(v)
  return nil == v or 0 == string.len(v)
end

function addCluster(cluster_id, cluster_name, is_public, metadata)
  if type(metadata) == 'string' then
    metadata = json:decode(metadata)
  end
  local metadata_raw = json:encode(metadata)
  system.print(MODULE_NAME .. "addCluster: cluster_id=" .. tostring(cluster_id)
          .. ", cluster_name=" .. tostring(cluster_name)
          .. ", is_public=" .. tostring(is_public)
          .. ", metadata=" .. metadata_raw)

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "addCluster: sender=" .. sender
          .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(cluster_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "addCluster",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      cluster_id = cluster_id
    }
  end

  -- check new machines
  local new_machine_list = metadata['new_machine_list']
  if nil == new_machine_list then
    new_machine_list = {}
  else
    metadata["new_machine_list"] = nil
    metadata_raw = json:encode(metadata)
  end
  system.print(MODULE_NAME
          .. "addCluster: new_machine_list="
          .. json:encode(new_machine_list))

  -- read registered Horde
  local res = getCluster(cluster_id)
  system.print(MODULE_NAME .. "addCluster: res=" .. json:encode(res))

  if "404" == res["__status_code"] then
    -- check whether Horde is public
    local is_public_value = 0
    if is_public then
      is_public_value = 1
    else
      is_public_value = 0
    end

    -- tx id
    local tx_id = system.getTxhash()
    system.print(MODULE_NAME .. "addCluster: tx_id=" .. tx_id)

    __callFunction(MODULE_NAME_DB, "insert",
      [[INSERT INTO clusters(cluster_owner,
                             cluster_name,
                             cluster_id,
                             cluster_is_public,
                             cluster_block_no,
                             cluster_tx_id,
                             cluster_metadata)
               VALUES (?, ?, ?, ?, ?, ?, ?)]],
      sender, cluster_name, cluster_id, is_public,
      block_no, tx_id, metadata_raw)
  end

  -- check the Machine info from Horde
  for _, machine in pairs(new_machine_list) do
    local machine_id = machine['machine_id']
    local machine_name = machine['machine_name']
    local machine_metadata = machine['machine_metadata']

    addMachine(cluster_id, machine_id, machine_name, machine_metadata)
  end

  -- read registerd all Machines of Horde
  local res = getAllMachines(cluster_id)
  system.print(MODULE_NAME .. "addCluster: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] and "404" ~= res["__status_code"] then
    return res
  end

  -- TODO: save this activity

  -- success to write (201 Created)
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "addCluster",
    __status_code = "201",
    __status_sub_code = "",
    cluster_owner = res['cluster_owner'],
    cluster_id = res['cluster_id'],
    --[[
    cluster_name = res['cluster_name'],
    cluster_metadata = res['cluster_metadata'],
    cluster_block_no = res['cluster_block_no'],
    cluster_tx_id = res['cluster_tx_id'],
    cluster_is_public = res['cluster_is_public'],
    machine_list = res['machine_list'],
    ]]
  }
end

function getPublicClusters()
  system.print(MODULE_NAME .. "getPublicClusters")

  local cluster_list = {}
  local exist = false

  -- check all public Hordes
  local rows = __callFunction(MODULE_NAME_DB, "select",
    [[SELECT cluster_id, cluster_owner, cluster_name, cluster_metadata,
              cluster_block_no, cluster_tx_id
        FROM clusters
        WHERE cluster_is_public = 1
        ORDER BY cluster_block_no DESC]])

  for _, v in pairs(rows) do
    local cluster_id = v[1]
    local machine_list = {}

    local res = getAllMachines(cluster_id)
    system.print(MODULE_NAME .. "getPublicClusters: res=" .. json:encode(res))
    if "200" ~= res["__status_code"] and "404" ~= res["__status_code"] then
      return res
    elseif "200" == res["__status_code"] then
      machine_list = res['machine_list']
    end

    local horde = {
      cluster_id = v[1],
      cluster_owner = v[2],
      cluster_name = v[3],
      cluster_metadata = json:decode(v[4]),
      cluster_block_no = v[5],
      cluster_tx_id = v[6],
      cluster_is_public = true,
      machine_list = machine_list,
    }
    table.insert(cluster_list, horde)

    exist = true
  end

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "getPublicClusters: sender=" .. tostring(sender)
          .. ", block_no=" .. tostring(block_no))

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getPublicClusters",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find any public cluster",
      sender = sender
    }
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "getPublicClusters",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    cluster_list = cluster_list
  }
end

function getAllClusters(owner)
  system.print(MODULE_NAME .. "getAllClusters: owner=" .. tostring(owner))

  -- check all public Hordes
  local res = getPublicClusters()
  system.print(MODULE_NAME .. "getAllClusters: res=" .. json:encode(res))
  if isEmpty(owner) then
    return res
  end

  local cluster_list
  local exist = false
  if "404" == res["__status_code"] then
    cluster_list = {}
  elseif "200" == res["__status_code"] then
    cluster_list = res["cluster_list"]
    exist = true
  else
    return res
  end

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "getAllClusters: sender=" .. tostring(sender)
          .. ", block_no=" .. tostring(block_no))

  -- check all owner's private Hordes
  local rows = __callFunction(MODULE_NAME_DB, "select",
    [[SELECT cluster_id, cluster_name, cluster_metadata,
              cluster_block_no, cluster_tx_id
        FROM clusters
        WHERE cluster_owner = ? AND cluster_is_public = 0
        ORDER BY cluster_block_no DESC]],
    owner)

  for _, v in pairs(rows) do
    local cluster_id = v[1]
    local machine_list = {}

    -- read all Machines of Horde
    local res = getAllMachines(cluster_id)
    system.print(MODULE_NAME .. "getAllClusters: res=" .. json:encode(res))
    if "200" ~= res["__status_code"] and "404" ~= res["__status_code"] then
      return res
    elseif "200" == res["__status_code"] then
      machine_list = res['machine_list']
    end

    local horde = {
      cluster_id = cluster_id,
      cluster_owner = owner,
      cluster_name = v[2],
      cluster_metadata = json:decode(v[3]),
      cluster_block_no = v[4],
      cluster_tx_id = v[5],
      cluster_is_public = false,
      machine_list = machine_list,
    }
    table.insert(cluster_list, horde)

    exist = true
  end

  -- check permissions (403.2 Read access forbidden)
  --[[ TODO: how to set the horde admin?
  local cluster_admin = sender
  if sender ~= cluster_admin then
    if not is_public then
      -- TODO: check sender's reading permission of horde
      return {
        __module = MODULE_NAME,
      __block_no = block_no,
        __func_name = "getCluster",
        __status_code = "403",
        __status_sub_code = "2",
        __err_msg = "Sender (" .. sender .. ") doesn't allow to read the cluster (" .. cluster_id .. ")",
        sender = sender,
        cluster_id = cluster_id
      }
    end
  end]]--

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getAllClusters",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find any cluster",
      sender = sender,
      owner = owner,
    }
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "getAllClusters",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    cluster_list = cluster_list
  }
end

function getCluster(cluster_id)
  system.print(MODULE_NAME .. "getCluster: cluster_id=" .. tostring(cluster_id))

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "getCluster: sender=" .. tostring(sender)
          .. ", block_no=" .. tostring(block_no))

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(cluster_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "addCluster",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      cluster_id = cluster_id
    }
  end

  -- check registered Horde
  local rows = __callFunction(MODULE_NAME_DB, "select",
    [[SELECT cluster_owner, cluster_name, cluster_is_public, cluster_metadata,
              cluster_block_no, cluster_tx_id
        FROM clusters
        WHERE cluster_id = ?
        ORDER BY cluster_block_no DESC]],
    cluster_id)
  local cluster_owner
  local cluster_name
  local cluster_is_public
  local cluster_metadata
  local cluster_block_no
  local cluster_tx_id

  local exist = false
  for _, v in pairs(rows) do
    cluster_owner = v[1]
    cluster_name = v[2]

    if 1 == v[3] then
      cluster_is_public = true
    else
      cluster_is_public = false
    end

    cluster_metadata = json:decode(v[4])
    cluster_block_no = v[5]
    cluster_tx_id = v[6]

    exist = true
  end

  --[[ TODO: cannot check the sender of a query contract
  -- check permissions (403.2 Read access forbidden)
  if sender ~= cluster_owner then
    if not is_public then
      -- TODO: check sender's reading permission of horde
      return {
        __module = MODULE_NAME,
        __block_no = block_no,
        __func_name = "getCluster",
        __status_code = "403",
        __status_sub_code = "2",
        __err_msg = "Sender (" .. sender .. ") doesn't allow to read the cluster (" .. cluster_id .. ")",
        sender = sender,
        cluster_id = cluster_id
      }
    end
  end
  ]]--

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getCluster",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find the cluster",
      sender = sender,
      cluster_id = cluster_id
    }
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "getCluster",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    cluster_owner = cluster_owner,
    cluster_id = cluster_id,
    cluster_name = cluster_name,
    cluster_metadata = cluster_metadata,
    cluster_block_no = cluster_block_no,
    cluster_tx_id = cluster_tx_id,
    cluster_is_public = cluster_is_public
  }
end

function dropCluster(cluster_id)
  system.print(MODULE_NAME .. "dropCluster: cluster_id=" .. tostring(cluster_id))

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "dropCluster: sender=" .. sender
          .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(cluster_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "addCluster",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      cluster_id = cluster_id
    }
  end

  -- read registered Horde
  local res = getCluster(cluster_id)
  system.print(MODULE_NAME .. "dropCluster: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local cluster_owner = res["cluster_owner"]

  -- check permissions (403.1 Execute access forbidden)
  if sender ~= cluster_owner and sender ~= cluster_id then
    -- TODO: check sender's deregister (drop) permission of horde
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "dropCluster",
      __status_code = "403",
      __status_sub_code = "1",
      __err_msg = "sender doesn't allow to deregister the clutser",
      sender = sender,
      cluster_id = cluster_id
    }
  end

  --
  __callFunction(MODULE_NAME_DB, "delete",
    "DELETE FROM clusters WHERE cluster_id = ?", cluster_id)

  -- TODO: save this activity

  -- 201 Created
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "dropCluster",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    cluster_owner = cluster_owner,
    cluster_id = cluster_id,
    --[[
    cluster_name = res['cluster_name'],
    cluster_metadata = res['cluster_metadata'],
    cluster_block_no = res['cluster_block_no'],
    cluster_tx_id = res['cluster_tx_id'],
    cluster_is_public = res['cluster_is_public']
    ]]
  }
end

function updateCluster(cluster_id, cluster_name, is_public, metadata)
  if type(metadata) == 'string' then
    metadata = json:decode(metadata)
  end
  local metadata_raw = json:encode(metadata)
  system.print(MODULE_NAME .. "updateCluster: cluster_id=" .. tostring(cluster_id)
          .. ", cluster_name=" .. tostring(cluster_name)
          .. ", is_public=" .. tostring(is_public)
          .. ", metadata=" .. metadata_raw)

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "updateCluster: sender=" .. sender
          .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(cluster_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "addCluster",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      cluster_id = cluster_id
    }
  end

  -- read registered Horde
  local res = getCluster(cluster_id)
  system.print(MODULE_NAME .. "updateCluster: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local cluster_owner = res["cluster_owner"]

  -- check permissions (403.3 Write access forbidden)
  if sender ~= cluster_owner and sender ~= cluster_id then
    -- TODO: check sender's update permission of Horde
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "updateCluster",
      __status_code = "403",
      __status_sub_code = "3",
      __err_msg = "sender doesn't allow to update the cluster info",
      sender = sender,
      cluster_id = cluster_id
    }
  end

  -- check arguments
  if isEmpty(cluster_name) then
    cluster_name = res["cluster_name"]
  end

  if nil == is_public then
    is_public = res["cluster_is_public"]
  end

  local is_public_value = 0
  if is_public then
    is_public_value = 1
  else
    is_public_value = 0
  end

  if nil == metadata or isEmpty(metadata_raw) then
    metadata = res["cluster_metadata"]
    metadata_raw = json:encode(metadata)
  end

  __callFunction(MODULE_NAME_DB, "update",
    [[UPDATE clusters SET cluster_name = ?, cluster_is_public = ?, cluster_metadata = ?
        WHERE cluster_id = ?]],
    cluster_name, is_public_value, metadata_raw, cluster_id)

  -- TODO: save this activity

  -- 201 Created
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "updateCluster",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    cluster_owner = cluster_owner,
    cluster_id = cluster_id,
    --[[
    cluster_name = cluster_name,
    cluster_metadata = metadata,
    cluster_block_no = res['cluster_block_no'],
    cluster_tx_id = res['cluster_tx_id'],
    cluster_is_public = cluster_is_public
    ]]
  }
end

function addMachine(cluster_id, machine_id, machine_name, metadata)
  if type(metadata) == 'string' then
    metadata = json:decode(metadata)
  end
  local metadata_raw = json:encode(metadata)
  system.print(MODULE_NAME .. "addMachine: cluster_id=" .. tostring(cluster_id)
          .. ", machine_id=" .. tostring(machine_id)
          .. ", machine_name=" .. tostring(machine_name)
          .. ", metadata=" .. metadata_raw)

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "addMachine: sender=" .. sender
          .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(cluster_id) or isEmpty(machine_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "addCluster",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      cluster_id = cluster_id,
      machine_id = machine_id,
    }
  end

  -- read registered Horde
  local res = getCluster(cluster_id)
  system.print(MODULE_NAME .. "addMachine: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local cluster_owner = res["cluster_owner"]

  -- check permissions (403.1 Execute access forbidden)
  if sender ~= cluster_owner and sender ~= cluster_id then
    -- TODO: check sender's register Machine permission of horde
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "addMachine",
      __status_code = "403",
      __status_sub_code = "1",
      __err_msg = "sender doesn't allow to add a new machine for the cluster",
      sender = sender,
      cluster_id = cluster_id
    }
  end

  -- tx id
  local tx_id = system.getTxhash()
  system.print(MODULE_NAME .. "addMachine: tx_id=" .. tx_id)

  __callFunction(MODULE_NAME_DB, "insert",
    [[INSERT OR REPLACE INTO machines(cluster_id,
                                          machine_owner,
                                          machine_name,
                                          machine_id,
                                          machine_block_no,
                                          machine_tx_id,
                                          machine_metadata)
             VALUES (?, ?, ?, ?, ?, ?, ?)]],
    cluster_id, sender, machine_name, machine_id,
    block_no, tx_id, metadata_raw)

  -- TODO: save this activity

  -- success to write (201 Created)
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "addMachine",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    cluster_owner = cluster_owner,
    cluster_id = cluster_id,
    machine_owner = sender,
    machine_id = machine_id,
    --[[
    cluster_name = res['cluster_name'],
    cluster_metadata = res['cluster_metadata'],
    cluster_block_no = res['cluster_block_no'],
    cluster_tx_id = res['cluster_tx_id'],
    cluster_is_public = res['cluster_is_public'],
    machine_list = {
      {
        machine_owner = sender,
        machine_name = machine_name,
        machine_id = machine_id,
        machine_metadata = metadata,
        machine_block_no = block_no,
        machine_tx_id = tx_id
      }
    }
    ]]
  }
end

function getAllMachines(cluster_id)
  system.print(MODULE_NAME .. "getAllMachines: cluster_id=" .. tostring(cluster_id))

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "getAllMachines: sender=" .. tostring(sender)
          .. ", block_no=" .. tostring(block_no))

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(cluster_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getAllMachines",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      cluster_id = cluster_id,
    }
  end

  -- read registered Horde
  local res = getCluster(cluster_id)
  system.print(MODULE_NAME .. "getAllMachines: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local cluster_owner = res["cluster_owner"]
  local cluster_name = res["cluster_name"]
  local cluster_is_public = res["cluster_is_public"]
  local cluster_metadata = res["cluster_metadata"]
  local cluster_block_no = res["cluster_block_no"]
  local cluster_tx_id = res['cluster_tx_id']

  -- check inserted data
  local rows = __callFunction(MODULE_NAME_DB, "select",
    [[SELECT machine_owner, machine_id, machine_name, machine_metadata,
              machine_block_no, machine_tx_id
        FROM machines
        WHERE cluster_id = ?
        ORDER BY machine_block_no DESC]],
    cluster_id)

  local machine_list = {}

  local exist = false
  for _, v in pairs(rows) do
    local machine = {
      machine_owner = v[1],
      machine_id = v[2],
      machine_name = v[3],
      machine_metadata = json:decode(v[4]),
      machine_block_no = v[5],
      machine_tx_id = v[6]
    }
    table.insert(machine_list, machine)

    exist = true
  end

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getAllMachines",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find any machine in the cluster",
      sender = sender,
      cluster_owner = cluster_owner,
      cluster_id = cluster_id,
      cluster_name = cluster_name,
      cluster_metadata = cluster_metadata,
      cluster_block_no = cluster_block_no,
      cluster_tx_id = cluster_tx_id,
      cluster_is_public = cluster_is_public
    }
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "getAllMachines",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    cluster_owner = cluster_owner,
    cluster_id = cluster_id,
    cluster_name = cluster_name,
    cluster_metadata = cluster_metadata,
    cluster_block_no = cluster_block_no,
    cluster_tx_id = cluster_tx_id,
    cluster_is_public = cluster_is_public,
    machine_list = machine_list
  }
end

function getMachine(cluster_id, machine_id)
  system.print(MODULE_NAME .. "getMachine: cluster_id=" .. tostring(cluster_id)
          .. ", machine_id=" .. tostring(machine_id))

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "getMachine: sender=" .. tostring(sender)
          .. ", block_no=" .. tostring(block_no))

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(cluster_id) or isEmpty(machine_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getMachine",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      cluster_id = cluster_id,
      machine_id = machine_id,
    }
  end

  -- read registered Horde
  local res = getCluster(cluster_id)
  system.print(MODULE_NAME .. "getMachine: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local cluster_owner = res["cluster_owner"]
  local cluster_name = res["cluster_name"]
  local cluster_is_public = res["cluster_is_public"]
  local cluster_metadata = res["cluster_metadata"]
  local cluster_block_no = res["cluster_block_no"]
  local cluster_tx_id = res['cluster_tx_id']

  -- check inserted data
  local rows = __callFunction(MODULE_NAME_DB, "select",
    [[SELECT machine_owner, machine_name, machine_metadata,
              machine_block_no, machine_tx_id
        FROM machines
        WHERE cluster_id = ? AND machine_id = ?
        ORDER BY machine_block_no DESC]],
    cluster_id, machine_id)

  local machine_list = {}

  local exist = false
  for _, v in pairs(rows) do
    local machine = {
      machine_id = machine_id,
      machine_owner = v[1],
      machine_name = v[2],
      machine_metadata = json:decode(v[3]),
      machine_block_no = v[4],
      machine_tx_id = v[5]
    }
    table.insert(machine_list, machine)

    exist = true
  end

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getMachine",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find the machine info in the cluster",
      sender = sender,
      cluster_owner = cluster_owner,
      cluster_id = cluster_id,
      cluster_name = cluster_name,
      cluster_metadata = cluster_metadata,
      cluster_block_no = cluster_block_no,
      cluster_tx_id = cluster_tx_id,
      cluster_is_public = cluster_is_public,
      machine_id = machine_id
    }
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "getMachine",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    cluster_owner = cluster_owner,
    cluster_id = cluster_id,
    cluster_name = cluster_name,
    cluster_metadata = cluster_metadata,
    cluster_block_no = cluster_block_no,
    cluster_tx_id = cluster_tx_id,
    cluster_is_public = cluster_is_public,
    machine_list = machine_list
  }
end

function dropMachine(cluster_id, machine_id)
  system.print(MODULE_NAME .. "dropMachine: cluster_id=" .. tostring(cluster_id)
          .. ", machine_id=" .. tostring(machine_id))

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "dropMachine: sender=" .. sender
          .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(cluster_id) or isEmpty(machine_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "dropMachine",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      cluster_id = cluster_id,
      machine_id = machine_id,
    }
  end

  -- read registered Machine
  local res = getMachine(cluster_id, machine_id)
  system.print(MODULE_NAME .. "dropMachine: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local cluster_owner = res["cluster_owner"]
  local machine_info = res["machine_list"][1]
  local machine_owner = machine_info["machine_owner"]

  -- check permissions (403.1 Execute access forbidden)
  if sender ~= cluster_owner and sender ~= cluster_id then
    if sender ~= machine_owner and sender ~= machine_id then
      -- TODO: check sender's deregister (drop) permission of horde Machine
      return {
        __module = MODULE_NAME,
        __block_no = block_no,
        __func_name = "dropMachine",
        __status_code = "403",
        __status_sub_code = "1",
        __err_msg = "sender doesn't allow to deregister a node of the cluster",
        sender = sender,
        cluster_id = cluster_id,
        machine_id = machine_id
      }
    end
  end

  -- drop Machine
  __callFunction(MODULE_NAME_DB, "delete",
    "DELETE FROM machines WHERE cluster_id = ? AND machine_id = ?",
    cluster_id, machine_id)

  -- TODO: save this activity

  -- 201 Created
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "dropMachine",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    cluster_owner = cluster_owner,
    cluster_id = cluster_id,
    machine_owner = machine_owner,
    machine_id = machine_id
    --[[
    cluster_name = res["cluster_name"],
    cluster_metadata = res["cluster_metadata"],
    cluster_block_no = res["cluster_block_no"],
    cluster_tx_id = res['cluster_tx_id'],
    cluster_is_public = res["cluster_is_public"],
    machine_list = res["machine_list"]
    ]]
  }
end

function updateMachine(cluster_id, machine_id, machine_name, metadata)
  if type(metadata) == 'string' then
    metadata = json:decode(metadata)
  end
  local metadata_raw = json:encode(metadata)
  system.print(MODULE_NAME .. "updateMachine: cluster_id=" .. tostring(cluster_id)
          .. ", machine_id=" .. tostring(machine_id)
          .. ", machine_name=" .. tostring(machine_name)
          .. ", metadata=" .. metadata_raw)

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "updateMachine: sender=" .. sender .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(cluster_id) or isEmpty(machine_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "updateMachine",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      cluster_id = cluster_id,
      machine_id = machine_id,
    }
  end

  -- read registered Machine
  local res = getMachine(cluster_id, machine_id)
  system.print(MODULE_NAME .. "updateMachine: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local cluster_owner = res["cluster_owner"]
  local machine_info = res["machine_list"][1]
  local machine_owner = machine_info["machine_owner"]

  -- check permissions (403.3 Write access forbidden)
  if sender ~= cluster_owner and sender ~= cluster_id then
    if sender ~= machine_owner and sender ~= machine_id then
      -- TODO: check sender's update permission of Horde
      return {
        __module = MODULE_NAME,
        __block_no = block_no,
        __func_name = "updateMachine",
        __status_code = "403",
        __status_sub_code = "3",
        __err_msg = "sender doesn't allow to update a node info of the cluster",
        sender = sender,
        cluster_id = cluster_id,
        machine_id = machine_id
      }
    end
  end

  -- check arguments
  if isEmpty(machine_name) then
    machine_name = machine_info["machine_name"]
  end
  if isEmpty(metadata_raw) then
    metadata = machine_info["machine_metadata"]
    metadata_raw = json:encode(metadata)
  end

  __callFunction(MODULE_NAME_DB, "update",
    [[UPDATE machines SET machine_name = ?, machine_metadata = ?
        WHERE cluster_id = ? AND machine_id = ?]],
    machine_name, metadata_raw, cluster_id, machine_id)

  -- TODO: save this activity

  -- 201 Created
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "updateMachine",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    cluster_owner = cluster_owner,
    cluster_id = cluster_id,
    machine_owner = machine_owner,
    machine_id = machine_id,
    --[[
    cluster_name = res["cluster_name"],
    cluster_metadata = res["cluster_metadata"],
    cluster_block_no = res["cluster_block_no"],
    cluster_tx_id = res['cluster_tx_id'],
    cluster_is_public = res["cluster_is_public"],
    machine_list = {
      {
        machine_owner = machine_owner,
        machine_name = machine_name,
        machine_id = machine_id,
        machine_metadata = metadata,
        machine_block_no = machine_info['machine_block_no'],
        machine_tx_id = machine_info['machine_tx_id']
      }
    }
    ]]
  }
end

abi.register(addCluster, getPublicClusters, getAllClusters, getCluster,
  dropCluster, updateCluster, addMachine, getAllMachines,
  getMachine, dropMachine, updateMachine)
