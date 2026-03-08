
local socket = require "common.socket"
local hpms = require "common.hpms"

local _M = {}

local aefd, stop
function _M.start(endpoint, on_accept)
    aefd = socket.new_poll()
    hpms.init_timer()
    if not endpoint and not on_accept then
        print("just to be a client")
        return
    end
    assert(type(endpoint) == "string", "your need provide `host:port`(string type) for listennig")
    assert(type(on_accept) == "function", "your need provide a function to accept a client")
    socket.listen(endpoint, on_accept)
end

function _M.stop()
    stop = true
    socket.free_poll()
end

function _M.run()
    assert(aefd, "please call evloop.start first!")
    while not stop do
        socket.event_wait(hpms.expire_timer())
    end
    socket.free_poll()
end

function _M.wait(timeout)
    socket.event_wait(timeout or hpms.expire_timer())
end

return _M
