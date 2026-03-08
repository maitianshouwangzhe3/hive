
_G.c2s = _G.c2s or {}

function c2s.hello_service.say_hello(req)
    -- log_info("req: %s", req.name)
    return {message = "hello " .. req.name}
end