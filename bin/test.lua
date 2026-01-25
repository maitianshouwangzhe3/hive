#!/usr/bin/hive

ct = ct or 0;
require "base/descriptor_pb"

local lbus = require "lbus"
print(lbus)
socket_mgr = lbus.create_socket_mgr(100);
pb = require "pb"
pb.load(descriptor_pb)
print(pb)
function hive.run()
    hive.sleep_ms(1000);
    print("ct="..ct);
    ct = ct + 1;
	if ct > 10 then
		print("quit");
		hive.run = nil;
	end
end


