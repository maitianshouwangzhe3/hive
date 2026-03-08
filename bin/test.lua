#!/usr/bin/hive

local lbus = require "lbus"
local lfs = require "rpc.lfs"
require("common/log");

local rpc_manager = require "rpc.rpc_mgr"

local hpms = require "common/hpms"
rpc_manager.setup(lfs.currentdir())
rpc_manager.client_init("127.0.0.1", 8989)

local function test(count)
	local index = 0;
	while index < count do
		index = index + 1;
		local ok, ret = xpcall(rpc_manager.say_hello, debug.traceback, {name = "lua"})
		if not ok then
			log_info("call rpc failed");
			return;
		else
			if not ret then
				log_info("call rpc failed ret nil");
				return;
			end

			if index % 100 == 0 then
				log_info("call rpc ok, ret=%s", ret.message);
			end
		end
	end
end

function hive.run()
    hive.sleep_ms(1000);
	local ok, ret = xpcall(rpc_manager.say_hello, debug.traceback, {name = "lua"})
	log_debug("ret: %s", ret)
	if not ok then
		log_info("call rpc failed: %s", ret);
		return;
	else
		log_info("call rpc ok, ret=%s", ret.message);
	end

	-- local count = 10000;
	-- local old = hive.get_time_ms();
	-- test(count);
	-- local new = hive.get_time_ms();
	-- print("cost time:", new - old);
	-- print("ave time:", (new - old) / count);
	hive.run = nil;
end


