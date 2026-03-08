if not rpc then
    rpc = require "rpc"
end

if not rpc_pb then
    rpc_pb = require "pb"
end

if not rpc_lfs then
    rpc_lfs = require "rpc.lfs"
end

require "rpc/descriptor_pb"

_G.c2s = _G.c2s or {}
_G.s2s = _G.s2s or {}

local rpc_service = {
    __index = function(self, key)
        return function(body)
            local service = self.rpc_service_info[key .. "_function"]
            if not service then
                log_err("undefined service: %s", key)
                return nil
            end

            local ok, data = xpcall(rpc_pb.encode, debug.traceback, service.input_type, body)
            if not ok then
                log_err("encode request error: %s", data)
                return nil
            end

            local req = {
                service_name = service.service_name,
                func_name = key,
                args = data
            }

            local ok2, req_data = xpcall(rpc_pb.encode, debug.traceback, ".rpc.rpc_requst", req)
            if not ok2 then
                log_err("encode rpc request error: %s", req_data)
                return nil
            end

            local rsq = _G.rpc_client.invoke(req_data, #req_data)

            local ok3, ret = xpcall(rpc_pb.decode, debug.traceback, ".rpc.rpc_response", rsq)
            if not ok3 then
                log_err("decode rpc response(%s) error: %s", rpc_pb.tohex(rsq), ret)
                return nil
            end

            local ok4, ret2 = xpcall(rpc_pb.decode, debug.traceback, service.output_type, ret.result)
            if not ok4 then
                log_err("decode rpc response(%s) output error: %s", rpc_pb.tohex(ret.result), ret2)
                return nil
            end

            return ret2
        end
    end
}

if not hive.init_flag then
    _G.rpc_mgr = setmetatable({}, rpc_service)
    rpc_mgr.rpc_service_info = {}
end

local function get_file_relpaths(root_dir)
    local result = {}

    local function walk(dir, base)
        for entry in lfs.dir(dir) do
            if entry ~= "." and entry ~= ".." then
                local full_path = dir .. "/" .. entry
                local rel_path = base and (base .. "/" .. entry) or entry
                
                local attr = lfs.attributes(full_path)
                if attr.mode == "directory" then
                    walk(full_path, rel_path)
                else
                    if full_path:sub(-3) == ".pb" then
                        table.insert(result, full_path)
                    end
                end
            end
        end
    end

    walk(root_dir, nil)
    return result
end

local function register_service(file)
    local f = io.open(file, "rb")
    data = f:read("*a")
    f:close()

    local FileDescriptorSet = rpc_pb.decode(".google.protobuf.FileDescriptorSet", data)
    for _, file in ipairs(FileDescriptorSet.file) do
        if file.service then
           for _, svc in ipairs(file.service) do
                local service = { package = file.package , service_name = svc.name }
                if not _G[file.package][svc.name] then
                    _G[file.package][svc.name] = {}
                end
                
                for _, method in ipairs(svc.method) do
                    service.input_type = method.input_type
                    service.output_type = method.output_type
                    service.function_name = method.name
                    local key = method.name .. "_function"
                    log_info("type:%s, register_service(%s) function name: %s", file.package, svc.name, method.name)
                    rpc_mgr.rpc_service_info[key] = service
                end
                rpc_mgr.rpc_service_info[svc.name .. "_service"] = service
            end 
        end
    end
end

local function dispatch(fd, msg, len)
    local ok, rpc_req = xpcall(rpc_pb.decode_binary, debug.traceback, ".rpc.rpc_requst", msg, len)
    if not ok then
        log_info("rpc_req is nil, error: %s", rpc_req)
        return
    end

    local service = rpc_mgr.rpc_service_info[rpc_req.service_name .. "_service"]
    if not service then
        log_info("service(%s) is nil", rpc_req.service_name)
        return
    end

    local ok, rpc_req_data = xpcall(rpc_pb.decode, debug.traceback, service.input_type, rpc_req.args)
    if not ok then
        log_info("decode rpc_req_data(%s) error: %s", service.input_type, rpc_req_data)
        return
    end

    local svr = _G[service.package]
    if not svr then
        log_info("svr(%s) is nil", service.package)
        return
    end

    if svr[service.service_name] then
        local func = svr[service.service_name][rpc_req.func_name]
        if not func then
            log_info("func(%s) is nil", rpc_req.func_name)
            return
        end

        local ok, rsq = xpcall(func, debug.traceback, rpc_req_data)
        if not ok or not rsq then
            log_info("rsq is nil, error: %s", rsq)
            return
        end

        local ok, rsq_1 = xpcall(rpc_pb.encode, debug.traceback, service.output_type, rsq)
        if not ok or not rsq_1 then
            log_info("encode rsq error: %s", rsq_1)
            return
        end

        local ok, rsq_2, len = xpcall(rpc_pb.encode, debug.traceback, ".rpc.rpc_response", {
            result = rsq_1,
            code = 0,
        })

        if not _G.rpc_server then
            return rsq_2, len
        end

        _G.rpc_server.push(fd, rsq_2, len)
    else
        log_warn("service_name not found")
    end
end

function _G.dispatch_pb_message(fd, msg, len)
    local ok, data, data_len = xpcall(dispatch, debug.traceback, fd, msg, len)
    if not ok then
        log_err("dispatch error");
        return nil, 0
    end

    return data, data_len
end

rpc_mgr.dispatch = _G.dispatch_pb_message

function rpc_mgr.import_pb(dir)
    for _, rel_path in ipairs(get_file_relpaths(dir)) do
        log_info("import pb file: %s", rel_path)
        local ok, err = rpc_pb.loadfile(rel_path)
        if not ok then
            log_debug("load pb file failed: %d", err)
            return
        end
        register_service(rel_path)
    end
end

function rpc_mgr.server_start(ip, port)
    if not _G.rpc_server then
        _G.rpc_server = rpc.new_server()
    end
    _G.rpc_server.start(ip, port)
end

function rpc_mgr.client_init(ip, port)
    if not _G.rpc_client then
        _G.rpc_client = rpc.new_client()
    end
    return _G.rpc_client.init(ip, port)
end

function rpc_mgr.callback(func)
    rpc.callback(func)
end

function setup(dir)
    log_info("rpc_mgr setup dir: %s", dir)
    rpc_pb.load(descriptor_pb)
    -- rpc_pb.load(RPC_PB_DATA)
    rpc_mgr.import_pb(dir)
end

rpc_service.rpc_service_info = rpc_mgr.rpc_service_info
rpc_mgr.setup = setup

return rpc_mgr