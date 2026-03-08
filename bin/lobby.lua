
require("common/log")
require("common/signal")
require("common/service")
require("common/alt_getopt")

_G.s2s = s2s or {}; --所有server间的rpc定义在s2s中
if not lbus then
    lbus = require("lbus")
end

local fs = require("lfs")

if not hive.init_flag then
    local long_opts = {
        routers=1, --router addr: 127.0.0.1:6000;127.0.0.1:6001
        listen=1, --listen addr for client: 127.0.0.1:5000
        index=1, --instance index
        daemon=0, 
        log=1, --log file: gamesvr.1
        connections=1, --max-connection-count
    };

    local args, optind = alt_getopt.get_opts(hive.args, "", long_opts);
    if args.daemon then
        hive.daemon(1, 1);
    end

    log_open(args.log or "lobby", 60000);

    _G.socket_mgr = lbus.create_socket_mgr(args.connections or 1024);

    hive.args = args;
    hive.optind = optind;
    hive.start_time = hive.start_time or hive.get_time_ms();
    hive.frame = hive.frame or 0;

    rpc_mgr = import("rpc/rpc_mgr.lua");

    rpc_mgr.setup(fs.currentdir());
    import("c2s/import.lua")

    router_mgr = import("common/router_mgr.lua");
    session_mgr = import("lobby/session_mgr.lua");
    
    router_mgr.setup("lobby");
    session_mgr.setup();

    hive.init_flag = true;
end

collectgarbage("stop");

hive.run = function()
    hive.now = os.time();
    socket_mgr.wait(50);
    local cost_time = hive.get_time_ms() - hive.start_time;
    if 100 * hive.frame <  cost_time  then
        hive.frame = hive.frame + 1;
        local ok, err = xpcall(on_tick, debug.traceback, hive.frame);
        if not ok then
            log_err("on_tick error: %s", err);
        end
        collectgarbage("collect");
    end

    if check_quit_signal() then
        hive.run = nil;
    end
end

function on_tick(frame)
    if frame % 10  == 0 then
        _G.call_router_all("heart_beat", nil);
    end
    router_mgr.update(frame);
    session_mgr.update(frame);
end