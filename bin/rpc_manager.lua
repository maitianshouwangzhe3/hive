
local rpc = require "rpc"
local rpc_pb = require "pb"
local rpc_lfs = require "lfs"

require "descriptor_pb"

_G.c2s = _G.c2s or {}
_G.s2s = _G.s2s or {}

_G.rpc_server = rpc.new_server()
_G.rpc_client = rpc.new_client()

local rpc_service = {
    __index = function(self, key)
        return function(body)
            local service = self.rpc_service_info[key .. "_function"]
            if not service then
                return nil
            end

            local data = rpc_pb.encode(service.input_type, body)
            local req = {
                service_name = service.service_name,
                func_name = key,
                args = data
            }

            local req_data = rpc_pb.encode(".rpc.rpc_requst", req)
            local rsq = _G.rpc_client.invoke(req_data, #req_data)
            local ret = rpc_pb.decode(".rpc.rpc_response", rsq)
            if not ret then
                return nil
            end

            return rpc_pb.decode(service.output_type, ret.result)
        end
    end
}

local rpc_manager = setmetatable({}, rpc_service)

rpc_manager.rpc_service_info = {}

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
    print(file)
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
                    print("register_service function name:", method.name)
                    rpc_manager.rpc_service_info[key] = service
                end
                rpc_manager.rpc_service_info[svc.name .. "_service"] = service
            end 
        end
    end
end

function rpc_manager.dispatch(fd, msg, len)
    local rpc_req = rpc_pb.decode(".rpc.rpc_requst", msg)
    if not rpc_req then
        print("rpc_req is nil")
        return
    end
    print("pc_req.func_name:", rpc_req.func_name)
    local service = rpc_manager.rpc_service_info[rpc_req.service_name .. "_service"]
    if not service then
        print("service is nil")
        return
    end

    local rpc_req_data = rpc_pb.decode(service.input_type, rpc_req.args)
    if not rpc_req_data then
        print("rpc_req_data is nil")
        return
    end

    local svr = _G[service.package]
    if not svr then
        print("svr is nil")
        return
    end

    print("service name:", service.service_name)
    for key, value in pairs(svr[service.service_name]) do
        print("key:", key, "value:", value)
    end
    if svr[service.service_name] then
        local func = svr[service.service_name][rpc_req.func_name]
        if not func then
            print("func is nil")
            return
        end

        local rsq = func(rpc_req_data)
        if not rsq then
            print("rsq is nil")
            return
        end

        local rsq_1, _ = rpc_pb.encode(service.output_type, rsq)
        if not rsq_1 then
            print("rsq_1 is nil")
            return
        end

        local rsq_2, len = rpc_pb.encode(".rpc.rpc_response", {
            code = 0,
            result = rsq_1
        })
        print("len:", len)
        _G.rpc_server.push(fd, rsq_2, len)
    else
        print("service_name not found")
    end
end

function rpc_manager.import(dir)
    for _, rel_path in ipairs(get_file_relpaths(dir)) do
        rpc_pb.loadfile(rel_path)
        register_service(rel_path)
    end
end

function rpc_manager.server_start(ip, port)
    _G.rpc_server.start(ip, port)
end

function rpc_manager.client_init(ip, port)
    return _G.rpc_client.init(ip, port)
end

rpc_pb.load(descriptor_pb)
rpc.callback(rpc_manager.dispatch)
rpc_service.rpc_service_info = rpc_manager.rpc_service_info

return rpc_manager