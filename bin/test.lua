#!/usr/bin/hive

ct = ct or 0;

socket_mgr = hive.create_socket_mgr(100, 1024 * 1024, 1024 * 8);

stream = socket_mgr.connect("127.0.0.1", 7571);


function hive.run()
    hive.sleep_ms(1000);
	socket_mgr.wait(1000);
	stream.call("login_req")
    print("ct="..ct);
    ct = ct + 1;
	if ct > 10 then
		print("quit");
		hive.run = nil;
	end
end


