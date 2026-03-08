require("common/tools");
import("c2s/import")

sessions = sessions or {};
session_count = session_count or 0;

lobby_sessions = lobby_sessions or {};
lobby_session_count = lobby_session_count or 0;

function setup()
    local tokens = split_string(hive.args.listen or "127.0.0.1:7571", ":");
    local ip, port = table.unpack(tokens);
    listener = socket_mgr.listen(ip, port);
    if not listener then
        log_err("failed to listen %s:%s", ip, port);
        os.exit(1);
    end
	log_info("listen client at %s:%s", ip, port);
	listen_ip = ip;
	listen_port = port;
    listener.on_accept = log_decorator(on_accept);
end

function update(frame)

end

function on_accept(ss)
    sessions[ss.token] = ss; 
	session_count = session_count + 1;

    ss.on_recv = function(msg, ...)
        log_debug("c2s msg: %s", msg);
        ss.alive_time = hive.now;
        if not msg then
            log_err("nil c2s msg !");
            return;
        end

        local proc = c2s[msg];
        if not proc then
            log_err("undefined c2s msg: %s", msg);
            return;
        end

        local ok, err = xpcall(proc, debug.traceback, ss, ...);
        if not ok then
            log_err("failed to call msg c2s.%s", msg);
            log_err("%s", err);
        end
    end

    ss.on_error = function(err)
        sessions[ss.token] = nil;
		session_count = session_count - 1;
        log_debug("connection lost, token=%s", ss.token);
    end

	log_info("new connection, token=%s", ss.token);
end

function client_loop(fd)
    lobby_node = hive.find_best_lobby()
    if not lobby_node then
        log_err("no lobby node")
        hive.socket.close(fd)
        return
    end

    local function ret_pak(data, len)
        hive.socket.sync_write(fd, data, len)
        return nil, 0
    end

    local lobby_imp = socket_mgr.connect(lobby_node.ip, lobby_node.port, 100)
    lobby_imp.set_protobuf(true)
    lobby_sessions[fd] = lobby_imp
    lobby_session_count = lobby_session_count + 1

    lobby_imp.on_recv = function(msg, ...)
        log_debug("lobby msg: %s", msg);
    end

    lobby_imp.on_pb_recv = function(token, data, data_len)
        return ret_pak(data, data_len)
    end

    lobby_imp.on_error = function(err)
        lobby_sessions[fd] = nil
        lobby_session_count = lobby_session_count - 1
        log_debug("connection lobby lost, token=%s", lobby_imp.token)
    end

    lobby_imp.on_connect = function()
        log_debug("connect to lobby: %s:%s", lobby_node.ip, lobby_node.port)
    end

    while true do
        local buf, err = hive.socket.readall(fd)
        if err or not buf then
            log_err("error: %s", err)
            hive.socket.close(fd)
            lobby_sessions[fd] = nil
            lobby_session_count = lobby_session_count - 1
            return
        end

        lobby_imp.async_send_forward(buf, #buf)
    end
end

