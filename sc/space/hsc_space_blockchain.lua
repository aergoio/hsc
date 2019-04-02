--
-- Horde Smart Contract (HSC): Blockchain space
--

MODULE_NAME = "__HSC_SPACE_BLOCKCHAIN__"

MODULE_NAME_DB = "__MANIFEST_DB__"
MODULE_NAME_COMPUTING = "__HSC_SPACE_COMPUTING__"

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
  system.print(MODULE_NAME
          .. "constructor: manifestAddress=" .. manifestAddress)

  -- create Chain metadata table
  --    * is_public = [1=public, 0=permissioned]
  __callFunction(MODULE_NAME_DB, "createTable",
    [[CREATE TABLE IF NOT EXISTS chains(
            chain_creator   TEXT NOT NULL,
            chain_name      TEXT,
            chain_id        TEXT NOT NULL,
            chain_is_public INTEGER DEFAULT 0,
            chain_block_no  INTEGER DEFAULT NULL,
            chain_tx_id     TEXT NOT NULL,
            chain_metadata  TEXT,
            PRIMARY KEY (chain_id)
  )]])

  -- create Node metadata table
  __callFunction(MODULE_NAME_DB, "createTable",
    [[CREATE TABLE IF NOT EXISTS nodes(
            chain_id        TEXT NOT NULL,
            node_creator    TEXT NOT NULL,
            node_name       TEXT,
            node_id         TEXT NOT NULL,
            node_block_no   INTEGER DEFAULT NULL,
            node_tx_id      TEXT NOT NULL,
            node_metadata   TEXT,
            PRIMARY KEY (chain_id, node_id),
            FOREIGN KEY (chain_id) REFERENCES chains(chain_id)
              ON DELETE CASCADE ON UPDATE NO ACTION
  )]])

  -- create Chain access control table
  --    * ac_detail = [TODO: categorize all object and then designate (CREATE/READ/WRITE/DELETE)]
  __callFunction(MODULE_NAME_DB, "createTable",
    [[CREATE TABLE IF NOT EXISTS chains_ac_list(
            chain_id        TEXT NOT NULL,
            account_address TEXT NOT NULL,
            ac_detail       TEXT,
            PRIMARY KEY (chain_id, account_address)
            FOREIGN KEY (chain_id) REFERENCES chains(chain_id)
              ON DELETE CASCADE ON UPDATE NO ACTION
  )]])
end

local function isEmpty(v)
  return nil == v or 0 == string.len(v)
end

local function generateDposGenesisJson(chain_info)
  system.print(MODULE_NAME
          .. "generateDposGenesisJson: chain_info=" .. json:encode(chain_info))

  local chain_metadata = chain_info['chain_metadata']
  local bp_cnt = chain_metadata['bp_cnt']
  local genesis_json = chain_metadata['genesis_json']

  if nil ~= chain_metadata and nil ~= genesis_json then
    if bp_cnt == table.getn(genesis_json['bps']) then
      return genesis_json
    end
  end

  local node_list = chain_info['node_list']
  local bp_list = {}
  for _, node in pairs(node_list) do
    local node_metadata = node['node_metadata']
    if node_metadata['is_bp'] then
      table.insert(bp_list, node)
    end
  end

  local n_bp_list = table.getn(bp_list)
  system.print(MODULE_NAME 
          .. "generateDposGenesisJson: n_bp_list=" .. n_bp_list)

  if bp_cnt <= table.getn(bp_list) then
    local genesis = {
      chain_id = {
        magic = chain_info['chain_name'],
        public = chain_info['chain_is_public'],
        mainnet = chain_metadata['is_mainnet'],
        consensus = 'dpos',
      },
      balance = {},
      bps = {}
    }

    -- generate balance list
    for _, b in pairs(chain_metadata['coin_holders']) do
      local address = b['address']
      local amount = b['amount']

      genesis['balance'][address] = amount
    end

    -- generate BP list
    for i = 1, bp_cnt do
      table.insert(genesis['bps'], bp_list[i]['node_metadata']['server_id'])
    end

    return genesis
  else
    return nil
  end
end

function createChain(chain_id, chain_name, is_public, metadata)
  if type(metadata) == 'string' then
    metadata = json:decode(metadata)
  end
  local metadata_raw = json:encode(metadata)
  system.print(MODULE_NAME .. "createChain: chain_id=" .. tostring(chain_id)
          .. ", chain_name=" .. tostring(chain_name)
          .. ", is_public=" .. tostring(is_public)
          .. ", metadata=" .. metadata_raw)

  local creator = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "createChain: creator=" .. creator
          .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(chain_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "createChain",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = creator,
      chain_id = chain_id
    }
  end

  -- check new nodes
  local new_node_list = metadata['new_node_list']
  if nil == new_node_list then
    new_node_list = {}
  else
    metadata["new_node_list"] = nil
    metadata_raw = json:encode(metadata)
  end
  system.print(MODULE_NAME
          .. "createChain: new_node_list="
          .. json:encode(new_node_list))

  -- to shrink size of metadata
  local node_list = metadata['node_list']
  if nil ~= node_list then
    metadata["node_list"] = nil
    metadata_raw = json:encode(metadata)
  end

  -- read created Chain
  local res = getChain(chain_id)
  system.print(MODULE_NAME .. "createChain: res=" .. json:encode(res))

  if "404" == res["__status_code"] then
    -- check whether Chain is public
    local is_public_value = 0
    if is_public then
      is_public_value = 1
    else
      is_public_value = 0
    end

    -- tx id
    local tx_id = system.getTxhash()
    system.print(MODULE_NAME .. "createChain: tx_id=" .. tx_id)

    __callFunction(MODULE_NAME_DB, "insert",
      [[INSERT INTO chains(chain_creator,
                                chain_name,
                                chain_id,
                                chain_is_public,
                                chain_block_no,
                                chain_tx_id,
                                chain_metadata)
               VALUES (?, ?, ?, ?, ?, ?, ?)]],
      creator, chain_name, chain_id, is_public_value,
      block_no, tx_id, metadata_raw)
  end

  -- check and insert the created Node info from Horde
  for _, node in pairs(new_node_list) do
    local node_id = node['node_id']
    local node_name = node['node_name']
    local node_metadata = node['node_metadata']

    local res = createNode(chain_id, node_id, node_name, node_metadata)
    if "201" ~= res["__status_code"] then
      return res
    end
  end

  -- read created all Nodes of Chain
  local res = getAllNodes(chain_id)
  system.print(MODULE_NAME .. "createChain: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] and "404" ~= res["__status_code"] then
    return res
  end

  local chain_metadata = metadata
  chain_metadata['node_list'] = res['node_list']

  local consensus_alg = chain_metadata['consensus_alg']
  if consensus_alg ~= nil then
    if 'dpos' == consensus_alg then
      chain_metadata['genesis_json'] = generateDposGenesisJson(res)
    elseif 'raft' == consensus_alg then
    elseif 'poa' == consensus_alg then
    elseif 'pow' == consensus_alg then
    end

    local res2 = updateChain(chain_id, chain_name, is_public, chain_metadata)
    if "201" ~= res["__status_code"] then
      return res
    end
  end

  -- TODO: save this activity

  -- success to write (201 Created)
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "createChain",
    __status_code = "201",
    __status_sub_code = "",
    chain_creator = res['chain_creator'],
    chain_id = res['chain_id'],
    chain_name = res['chain_name'],
    chain_metadata = chain_metadata,
    chain_block_no = res['chain_block_no'],
    chain_tx_id = res['chain_tx_id'],
    chain_is_public = res['chain_is_public'],
    node_list = res['node_list'],
  }
end

function getPublicChains()
  system.print(MODULE_NAME .. "getPublicChains")

  local chain_list = {}
  local exist = false

  -- check all public Chains
  local rows = __callFunction(MODULE_NAME_DB, "select",
    [[SELECT chain_id, chain_name, chain_creator, chain_metadata,
              chain_block_no, chain_tx_id
        FROM chains
        WHERE chain_is_public = 1
        ORDER BY chain_block_no DESC]])

  for _, v in pairs(rows) do
    local chain_id = v[1]
    local node_list = {}

    local res = getAllNodes(chain_id)
    system.print(MODULE_NAME .. "getPublicChains: res=" .. json:encode(res))
    if "200" ~= res["__status_code"] and "404" ~= res["__status_code"] then
      return res
    elseif "200" == res["__status_code"] then
      node_list = res['node_list']
    end

    local pond = {
      chain_id = v[1],
      chain_name = v[2],
      chain_creator = v[3],
      chain_metadata = json:decode(v[4]),
      chain_block_no = v[5],
      chain_tx_id = v[6],
      chain_is_public = true,
      node_list = node_list,
    }
    table.insert(chain_list, pond)

    exist = true
  end

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "getPublicChains: sender=" .. tostring(sender)
          .. ", block_no=" .. tostring(block_no))

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getPublicChains",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find any public chain",
      sender = sender
    }
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "getPublicChains",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    chain_list = chain_list
  }
end

function getAllChains(creator)
  system.print(MODULE_NAME .. "getAllChains: creator=" .. tostring(creator))

  -- check all public Chains
  local res = getPublicChains()
  system.print(MODULE_NAME .. "getAllChains: res=" .. json:encode(res))
  if isEmpty(creator) then
    return res
  end

  local chain_list
  local exist = false
  if "404" == res["__status_code"] then
    chain_list = {}
  elseif "200" == res["__status_code"] then
    chain_list = res["chain_list"]
    exist = true
  else
    return res
  end

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "getAllChains: sender=" .. tostring(sender)
          .. ", block_no=" .. tostring(block_no))

  -- check all creator's private Chains
  local rows = __callFunction(MODULE_NAME_DB, "select",
    [[SELECT DISTINCT chain_id, chain_name, chain_metadata,
              chain_block_no, chain_tx_id
        FROM chains
          JOIN (
            SELECT DISTINCT
              clusters.cluster_id AS c_id,
              machines.machine_id AS m_id
            FROM clusters JOIN machines
            WHERE clusters.cluster_owner=? OR machines.machine_owner=?
          ) AS cm
        WHERE
          chains.chain_is_public = 0
          AND (
            chains.chain_creator=?
            OR chains.chain_creator=cm.c_id
            OR chains.chain_creator=cm.m_id
          )
        ORDER BY chain_block_no DESC]],
    creator, creator, creator)

  for _, v in pairs(rows) do
    local chain_id = v[1]
    local node_list = {}

    -- read all Nodes of Chain
    local res = getAllNodes(chain_id)
    system.print(MODULE_NAME .. "getAllChains: res=" .. json:encode(res))
    if "200" ~= res["__status_code"] and "404" ~= res["__status_code"] then
      return res
    elseif "200" == res["__status_code"] then
      node_list = res['node_list']
    end

    local pond = {
      chain_creator = creator,
      chain_id = chain_id,
      chain_name = v[2],
      chain_metadata = json:decode(v[3]),
      chain_block_no = v[4],
      chain_tx_id = v[5],
      chain_is_public = false,
      node_list = node_list,
    }
    table.insert(chain_list, pond)

    exist = true
  end

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getAllChains",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find any chain",
      sender = sender,
      chain_creator = creator,
    }
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "getAllChains",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    chain_list = chain_list
  }
end

function getChain(chain_id)
  system.print(MODULE_NAME .. "getChain: chain_id=" .. tostring(chain_id))

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "getChain: sender=" .. tostring(sender)
          .. ", block_no=" .. tostring(block_no))

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(chain_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getChain",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      chain_id = chain_id,
    }
  end

  -- check inserted data
  local rows = __callFunction(MODULE_NAME_DB, "select",
    [[SELECT chain_creator, chain_name, chain_is_public, chain_metadata,
              chain_block_no, chain_tx_id
        FROM chains
        WHERE chain_id = ?
        ORDER BY chain_block_no DESC]], chain_id)
  local chain_creator
  local chain_name
  local chain_is_public
  local chain_metadata
  local chain_block_no
  local chain_tx_id

  local exist = false
  for _, v in pairs(rows) do
    chain_creator = v[1]
    chain_name = v[2]

    if 1 == v[3] then
      chain_is_public = true
    else
      chain_is_public = false
    end

    chain_metadata = json:decode(v[4])
    chain_block_no = v[5]
    chain_tx_id = v[6]

    exist = true
  end

  --[[ TODO: cannot check the sender of a query contract
  -- check permissions (403.2 Read access forbidden)
  if sender ~= creator then
    if not is_public then
      -- TODO: check sender's reading permission of pond
      return {
        __module = MODULE_NAME,
        __block_no = block_no,
        __func_name = "getChain",
        __status_code = "403",
        __status_sub_code = "2",
        __err_msg = "Sender (" .. sender .. ") doesn't allow to read the chain (" .. chain_id .. ")",
        sender = sender,
        chain_id = chain_id
      }
    end
  end
  ]]--

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getChain",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find the chain",
      sender = sender,
      chain_id = chain_id
    }
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "getChain",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    chain_creator = chain_creator,
    chain_id = chain_id,
    chain_name = chain_name,
    chain_metadata = chain_metadata,
    chain_block_no = chain_block_no,
    chain_tx_id = chain_tx_id,
    chain_is_public = chain_is_public
  }
end

function deleteChain(chain_id)
  system.print(MODULE_NAME .. "deleteChain: chain_id=" .. tostring(chain_id))

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "deleteChain: sender=" .. sender
          .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(chain_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "deleteChain",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      chain_id = chain_id,
    }
  end

  -- read created Chain
  local res = getChain(chain_id)
  if "200" ~= res["__status_code"] then
    return res
  end
  system.print(MODULE_NAME .. "deleteChain: res=" .. json:encode(res))

  local chain_creator = res["chain_creator"]

  -- check permissions (403.1 Execute access forbidden)
  if sender ~= chain_creator then
    -- TODO: check sender's delete permission of pond
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "deleteChain",
      __status_code = "403",
      __status_sub_code = "1",
      __err_msg = "sender doesn't allow to delete the chain",
      sender = sender,
      chain_id = chain_id
    }
  end

  -- delete Chain
  __callFunction(MODULE_NAME_DB, "delete",
    "DELETE FROM chains WHERE chain_id = ?", chain_id)

  -- TODO: save this activity

  -- 201 Created
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "deleteChain",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    chain_creator = chain_creator,
    chain_id = chain_id,
    chain_name = res['chain_name'],
    chain_metadata = res['chain_metadata'],
    chain_block_no = res['chain_block_no'],
    chain_tx_id = res['chain_tx_id'],
    chain_is_public = res['chain_is_public']
  }
end

function updateChain(chain_id, chain_name, is_public, metadata)
  if type(metadata) == 'string' then
    metadata = json:decode(metadata)
  end
  local metadata_raw = json:encode(metadata)
  system.print(MODULE_NAME .. "updateChain: chain_id=" .. tostring(chain_id)
          .. ", chain_name=" .. tostring(chain_name)
          .. ", is_public=" .. tostring(is_public)
          .. ", metadata=" .. metadata_raw)

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "updateChain: sender=" .. sender
          .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(chain_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "updateChain",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      chain_id = chain_id,
    }
  end

  -- read created Chain
  local res = getChain(chain_id)
  if "200" ~= res["__status_code"] then
    return res
  end
  system.print(MODULE_NAME .. "updateChain: res=" .. json:encode(res))

  local chain_creator = res["chain_creator"]
  local node_list = metadata['node_list']
  local found_c_or_m = false
  for _, node in pairs(node_list) do
    local node_metadata = node['node_metadata']
    local cluster
    local machine
    if node_metadata == nil then
      cluster = node['cluster']
      machine = node['machine']
    else
      cluster = node_metadata['cluster']
      machine = node_metadata['machine']
    end
    if sender == cluster['id'] or sender == machine['id'] then
      found_c_or_m = true
      break
    end
  end

  -- check permissions (403.3 Write access forbidden)
  if sender ~= chain_creator and not found_c_or_m then
    -- TODO: check sender's update permission of pond
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "updateChain",
      __status_code = "403",
      __status_sub_code = "3",
      __err_msg = "sender doesn't allow to update the chain info",
      sender = sender,
      chain_id = chain_id
    }
  end

  -- check arguments
  if isEmpty(chain_name) then
    chain_name = res["chain_name"]
  end

  if nil == is_public then
    is_public = res["chain_is_public"]
  end

  local is_public_value = 0
  if is_public then
    is_public_value = 1
  else
    is_public_value = 0
  end

  if nil == metadata or isEmpty(metadata_raw) then
    metadata = res["chain_metadata"]
    metadata_raw = json:encode(metadata)
  end

  -- to shrink size of metadata
  local node_list = metadata['node_list']
  if nil ~= node_list then
    metadata["node_list"] = nil
    metadata_raw = json:encode(metadata)
  end

  __callFunction(MODULE_NAME_DB, "update",
    [[UPDATE chains SET chain_name = ?, chain_is_public = ?, chain_metadata = ?
        WHERE chain_id = ?]],
    chain_name, is_public_value, metadata_raw, chain_id)

  -- TODO: save this activity

  -- 201 Created
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "updateChain",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    chain_creator = chain_creator,
    chain_id = chain_id,
    chain_name = chain_name,
    chain_metadata = metadata,
    chain_block_no = res['chain_block_no'],
    chain_tx_id = res['chain_tx_id'],
    chain_is_public = is_public
  }
end

function createNode(chain_id, node_id, node_name, metadata)
  if type(metadata) == 'string' then
    metadata = json:decode(metadata)
  end
  local metadata_raw = json:encode(metadata)
  system.print(MODULE_NAME .. "createNode: chain_id=" .. tostring(chain_id)
          .. ", node_id=" .. tostring(node_id)
          .. ", node_name=" .. tostring(node_name)
          .. ", metadata=" .. metadata_raw)

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "createNode: sender=" .. sender
          .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(chain_id) or isEmpty(node_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "createNode",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      chain_id = chain_id,
      node_id = node_id,
    }
  end

  -- read created Chain
  local res = getChain(chain_id)
  system.print(MODULE_NAME .. "createNode: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local chain_creator = res["chain_creator"]
  local chain_is_public = res["chain_is_public"]

  local cluster_id = metadata["cluster"]["id"]
  local machine_id = metadata["machine"]["id"]

  -- check permissions (403.1 Execute access forbidden)
  if sender ~= chain_creator
          and sender ~= cluster_id
          and sender ~= machine_id then
    if not chain_is_public then
      -- TODO: check sender's create Node permission of pond
      return {
        __module = MODULE_NAME,
        __block_no = block_no,
        __func_name = "createNode",
        __status_code = "403",
        __status_sub_code = "1",
        __err_msg = "sender doesn't allow to create a new node for the chain",
        sender = sender,
        chain_id = chain_id
      }
    end
  end

  -- tx id
  local tx_id = system.getTxhash()
  system.print(MODULE_NAME .. "createNode: tx_id=" .. tx_id)

  __callFunction(MODULE_NAME_DB, "insert",
    [[INSERT OR REPLACE INTO nodes(chain_id,
                               node_creator,
                               node_name,
                               node_id,
                               node_block_no,
                               node_tx_id,
                               node_metadata)
             VALUES (?, ?, ?, ?, ?, ?, ?)]],
    chain_id, sender, node_name, node_id,
    block_no, tx_id, metadata_raw)

  -- TODO: save this activity

  -- success to write (201 Created)
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "createNode",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    chain_creator = chain_creator,
    chain_id = chain_id,
    chain_name = res['chain_name'],
    chain_metadata = res['chain_metadata'],
    chain_block_no = res['chain_block_no'],
    chain_tx_id = res['chain_tx_id'],
    chain_is_public = chain_is_public,
    node_list = {
      {
        node_creator = sender,
        node_name = node_name,
        node_id = node_id,
        node_metadata = metadata,
        node_block_no = block_no,
        node_tx_id = tx_id
      }
    }
  }
end

function getAllNodes(chain_id)
  system.print(MODULE_NAME .. "getAllNodes: chain_id=" .. tostring(chain_id))

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "getAllNodes: sender=" .. tostring(sender)
          .. ", block_no=" .. tostring(block_no))

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(chain_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getAllNodes",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      chain_id = chain_id,
    }
  end

  -- read created Chain
  local res = getChain(chain_id)
  system.print(MODULE_NAME .. "getAllNodes: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local chain_creator = res["chain_creator"]
  local chain_name = res["chain_name"]
  local chain_is_public = res["chain_is_public"]
  local chain_metadata = res["chain_metadata"]
  local chain_block_no = res["chain_block_no"]
  local chain_tx_id = res['chain_tx_id']

  -- check inserted data
  local rows = __callFunction(MODULE_NAME_DB, "select",
    [[SELECT node_creator, node_id, node_name, node_metadata,
              node_block_no, node_tx_id
        FROM nodes
        WHERE chain_id = ? ORDER BY node_block_no DESC]],
    chain_id)

  local node_list = {}

  local exist = false
  for _, v in pairs(rows) do
    local node = {
      node_creator = v[1],
      node_id = v[2],
      node_name = v[3],
      node_metadata = json:decode(v[4]),
      node_block_no = v[5],
      node_tx_id = v[6]
    }
    table.insert(node_list, node)

    exist = true
  end

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getAllNodes",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find any node in the chain",
      sender = sender,
      chain_creator = chain_creator,
      chain_id = chain_id,
      chain_name = chain_name,
      chain_metadata = chain_metadata,
      chain_block_no = chain_block_no,
      chain_tx_id = chain_tx_id,
      chain_is_public = chain_is_public
    }
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "getAllNodes",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    chain_creator = chain_creator,
    chain_id = chain_id,
    chain_name = chain_name,
    chain_metadata = chain_metadata,
    chain_block_no = chain_block_no,
    chain_tx_id = chain_tx_id,
    chain_is_public = chain_is_public,
    node_list = node_list
  }
end

function getNode(chain_id, node_id)
  system.print(MODULE_NAME .. "getNode: chain_id=" .. tostring(chain_id)
          .. ", node_id=" .. tostring(node_id))

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "getNode: sender=" .. tostring(sender)
          .. ", block_no=" .. tostring(block_no))

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(chain_id) or isEmpty(node_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getNode",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      chain_id = chain_id,
      node_id = node_id,
    }
  end

  -- read created Chain
  local res = getChain(chain_id)
  system.print(MODULE_NAME .. "getNode: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local chain_creator = res["chain_creator"]
  local chain_name = res["chain_name"]
  local chain_is_public = res["chain_is_public"]
  local chain_metadata = res["chain_metadata"]
  local chain_block_no = res["chain_block_no"]
  local chain_tx_id = res['chain_tx_id']

  -- check inserted data
  local rows = __callFunction(MODULE_NAME_DB, "select",
    [[SELECT node_creator, node_name, node_metadata,
              node_block_no, node_tx_id
        FROM nodes
        WHERE chain_id = ? AND node_id = ?
        ORDER BY node_block_no DESC]],
    chain_id, node_id)

  local node_list = {}

  local exist = false
  for _, v in pairs(rows) do
    local node = {
      node_id = node_id,
      node_creator = v[1],
      node_name = v[2],
      node_metadata = json:decode(v[3]),
      node_block_no = v[4],
      node_tx_id = v[5]
    }
    table.insert(node_list, node)

    exist = true
  end

  -- if not exist, (404 Not Found)
  if not exist then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "getNode",
      __status_code = "404",
      __status_sub_code = "",
      __err_msg = "cannot find the node",
      sender = sender,
      chain_creator = chain_creator,
      chain_id = chain_id,
      chain_name = chain_name,
      chain_metadata = chain_metadata,
      chain_block_no = chain_block_no,
      chain_tx_id = chain_tx_id,
      chain_is_public = chain_is_public,
      node_id = node_id
    }
  end

  -- 200 OK
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "getNode",
    __status_code = "200",
    __status_sub_code = "",
    sender = sender,
    chain_creator = chain_creator,
    chain_id = chain_id,
    chain_name = chain_name,
    chain_metadata = chain_metadata,
    chain_block_no = chain_block_no,
    chain_tx_id = chain_tx_id,
    chain_is_public = chain_is_public,
    node_list = node_list
  }
end

function deleteNode(chain_id, node_id)
  system.print(MODULE_NAME .. "deleteNode: chain_id=" .. tostring(chain_id)
          .. ", node_id=" .. tostring(node_id))

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "deleteNode: sender=" .. sender
          .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(chain_id) or isEmpty(node_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "deleteNode",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      chain_id = chain_id,
      node_id = node_id,
    }
  end

  -- read created Node
  local res = getNode(chain_id, node_id)
  system.print(MODULE_NAME .. "deleteNode: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local chain_creator = res["chain_creator"]
  local node_info = res["node_list"][1]
  local node_creator = node_info["node_creator"]

  -- check permissions (403.1 Execute access forbidden)
  if sender ~= chain_creator then
    if sender ~= node_creator then
      -- TODO: check sender's delete permission of pond
      return {
        __module = MODULE_NAME,
        __block_no = block_no,
        __func_name = "deleteNode",
        __status_code = "403",
        __status_sub_code = "1",
        __err_msg = "sender doesn't allow to delete the node",
        sender = sender,
        chain_id = chain_id,
        node_id = node_id
      }
    end
  end

  -- delete Node
  __callFunction(MODULE_NAME_DB, "delete",
    "DELETE FROM nodes WHERE chain_id = ? AND node_id = ?",
    chain_id, node_id)

  -- TODO: save this activity

  -- 201 Created
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "deleteNode",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    chain_creator = chain_creator,
    chain_id = chain_id,
    chain_name = res["chain_name"],
    chain_metadata = res["chain_metadata"],
    chain_block_no = res['chain_block_no'],
    chain_tx_id = res['chain_tx_id'],
    chain_is_public = res["chain_is_public"],
    node_list = res["node_list"]
  }
end

function updateNode(chain_id, node_id, node_name, metadata)
  if type(metadata) == 'string' then
    metadata = json:decode(metadata)
  end
  local metadata_raw = json:encode(metadata)
  system.print(MODULE_NAME .. "updateNode: chain_id=" .. tostring(chain_id)
          .. ", node_id=" .. tostring(node_id)
          .. ", node_name=" .. tostring(node_name)
          .. ", metadata=" .. metadata_raw)

  local sender = system.getOrigin()
  local block_no = system.getBlockheight()
  system.print(MODULE_NAME .. "updateNode: sender=" .. sender
          .. ", block_no=" .. block_no)

  -- if not exist critical arguments, (400 Bad Request)
  if isEmpty(chain_id) or isEmpty(node_id) then
    return {
      __module = MODULE_NAME,
      __block_no = block_no,
      __func_name = "updateNode",
      __status_code = "400",
      __status_sub_code = "",
      __err_msg = "bad request: miss critical arguments",
      sender = sender,
      chain_id = chain_id,
      node_id = node_id,
    }
  end

  -- read created Node
  local res = getNode(chain_id, node_id)
  system.print(MODULE_NAME .. "updateNode: res=" .. json:encode(res))
  if "200" ~= res["__status_code"] then
    return res
  end

  local chain_creator = res["chain_creator"]
  local node_info = res["node_list"][1]
  local node_creator = node_info["node_creator"]

  -- check permissions (403.3 Write access forbidden)
  if sender ~= chain_creator then
    if sender ~= node_creator then
      -- TODO: check sender's update permission of pond
      return {
        __module = MODULE_NAME,
        __block_no = block_no,
        __func_name = "updateNode",
        __status_code = "403",
        __status_sub_code = "3",
        __err_msg = "sender doesn't allow to update the node info",
        sender = sender,
        chain_id = chain_id,
        node_id = node_id
      }
    end
  end

  -- check arguments
  if isEmpty(node_name) then
    node_name = node_info["node_name"]
  end
  if nil == metadata or isEmpty(metadata_raw) then
    metadata = node_info["node_metadata"]
    metadata_raw = json:encode(metadata)
  end

  __callFunction(MODULE_NAME_DB, "update",
    [[UPDATE nodes SET node_name = ?, node_metadata = ?
        WHERE chain_id = ? AND node_id = ?]],
    node_name, metadata_raw, chain_id, node_id)

  -- TODO: save this activity

  -- 201 Created
  return {
    __module = MODULE_NAME,
    __block_no = block_no,
    __func_name = "updateNode",
    __status_code = "201",
    __status_sub_code = "",
    sender = sender,
    chain_creator = chain_creator,
    chain_id = chain_id,
    chain_name = res["chain_name"],
    chain_metadata = res["chain_metadata"],
    chain_block_no = res['chain_block_no'],
    chain_tx_id = res['chain_tx_id'],
    chain_is_public = res["chain_is_public"],
    node_list = {
      {
        node_creator = node_creator,
        node_name = node_name,
        node_id = node_id,
        node_metadata = metadata,
        node_block_no = node_info['node_block_no'],
        node_tx_id = node_info['node_tx_id']
      }
    }
  }
end

-- exposed functions
abi.register(createChain, getPublicChains, getAllChains,
  getChain, deleteChain, updateChain,
  createNode, getAllNodes, getNode, deleteNode, updateNode)
