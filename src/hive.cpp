/*
** repository: https://github.com/trumanzhao/luna
** trumanzhao, 2017-05-13, trumanzhao@foxmail.com
*/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <string>
#include <locale>
#include <stdint.h>
#include <signal.h>
#include <filesystem>
#include "lua.hpp"
#include "tools.h"
#include "socket_mgr.h"
#include "socket_wapper.h"
#include "hive.h"

extern "C" {
    int luaopen_pb(lua_State *L);
    int luaopen_lfs(lua_State * L);
}

#ifdef _MSC_VER
void daemon() {  } // do nothing !
#endif

#define REGISTER_LIBRARYS(name, lua_c_fn) \
    luaL_requiref(L, name, lua_c_fn, 0); \
    lua_pop(L, 1) /* remove lib */

hive_app* g_app = nullptr;

static void on_signal(int signo) {
    if (g_app)
    {
        g_app->set_signal(signo);
    }
}

LUA_EXPORT_CLASS_BEGIN(hive_app)
LUA_EXPORT_METHOD(get_file_time)
LUA_EXPORT_METHOD(get_time_ms)
LUA_EXPORT_METHOD(get_time_ns)
LUA_EXPORT_METHOD(sleep_ms)
LUA_EXPORT_METHOD(daemon)
LUA_EXPORT_METHOD(mkdir)
LUA_EXPORT_METHOD(register_signal)
LUA_EXPORT_METHOD(default_signal)
LUA_EXPORT_METHOD(ignore_signal)
LUA_EXPORT_METHOD(create_socket_mgr)
LUA_EXPORT_PROPERTY(m_signal)
LUA_EXPORT_PROPERTY(m_reload_time)
LUA_EXPORT_CLASS_END()

time_t hive_app::get_file_time(const char* file_name) {
    return ::get_file_time(file_name);
}

int64_t hive_app::get_time_ms() {
    return ::get_time_ms();
}

int64_t hive_app::get_time_ns() {
    return ::get_time_ns();
}

void hive_app::sleep_ms(int ms) {
    ::sleep_ms(ms);
}

void hive_app::daemon() {
    ::daemon(1, 0);
}

void hive_app::register_signal(int n) {
    signal(n, SIG_DFL);
}

void hive_app::default_signal(int n) {
    signal(n, SIG_DFL);
}

void hive_app::ignore_signal(int n) {
    signal(n, SIG_IGN);
}

int hive_app::create_socket_mgr(lua_State* L) {
    return ::create_socket_mgr(L);
}

void hive_app::set_signal(int n) {
    uint64_t mask = 1;
    mask <<= n;
    m_signal |= mask;
}

void hive_app::mkdir(const char* path) {
    std::filesystem::create_directories(path);
}

static const char* g_sandbox = u8R"__(
hive.files = {};
hive.meta = {__index=function(t, k) return _G[k]; end};
hive.print = print;
hive.args = {};

local do_load = function(filename, env)
    local trunk, msg = loadfile(filename, "bt", env);
    if not trunk then
        hive.print(string.format("load file: %s ... ... [failed]", filename));
        hive.print(msg);
        return nil;
    end

    local ok, err = pcall(trunk);
    if not ok then
        hive.print(string.format("exec file: %s ... ... [failed]", filename));
        hive.print(err);
        return nil;
    end

    hive.print(string.format("load file: %s ... ... [ok]", filename));
    return env;
end

function import(filename)
    local file_module = hive.files[filename];
    if file_module then
        return file_module.env;
    end

    local env = {};
    setmetatable(env, hive.meta);
    hive.files[filename] = {time=hive.get_file_time(filename), env=env };

    return do_load(filename, env);
end

hive.reload = function()
    for filename, filenode in pairs(hive.files) do
        local filetime = hive.get_file_time(filename);
        if filetime ~= filenode.time then
            filenode.time = filetime;
            if filetime ~= 0 then
                do_load(filename, filenode.env);
            end
        end
    end
end
)__";

void hive_app::run(int argc, const char* argv[]) {
    const char* filename = argv[1];
    lua_State* L = luaL_newstate();
    int64_t last_check = ::get_time_ms();

    luaL_openlibs(L);
    REGISTER_LIBRARYS("pb", luaopen_pb);
    REGISTER_LIBRARYS("lfs", luaopen_lfs);
    lua_push_object(L, this);
    lua_setglobal(L, "hive");
    luaL_dostring(L, g_sandbox);

    for (int i = 2; i < argc; i++)
    {
        add_string_to_array(L, "hive", "args", argv[i]);
    }

    lua_call_global_function(L, nullptr, "import", std::tie(), filename);

    while (lua_call_object_function(L, nullptr, this, "run", std::tie()))
    {
        int64_t now = ::get_time_ms();
        if (now > last_check + m_reload_time)
        {
            lua_call_object_function(L, nullptr, this, "reload");
            last_check = now;
        }
    }

    lua_close(L);
}

void hive_app::add_number_to_array(lua_State* L, const char* table_name, const char* array_field_name, lua_Number value) {
    // 1. 获取全局 table (t)
    lua_getglobal(L, table_name); // 假设 t 是全局变量
    if (!lua_istable(L, -1)) {
        luaL_error(L, "Expected table for %s", table_name);
        return;
    }

    // 2. 获取 t.arr
    lua_getfield(L, -1, array_field_name);
    if (!lua_istable(L, -1)) {
        luaL_error(L, "Expected table for %s.%s", table_name, array_field_name);
        lua_pop(L, 2); // 清理栈
        return;
    }

    // 3. 获取数组长度（#t.arr）
    lua_Integer len = lua_rawlen(L, -1);

    // 4. 压入要添加的值
    lua_pushnumber(L, value);

    // 5. 设置 t.arr[len + 1] = value
    lua_seti(L, -2, len + 1);

    // 6. 清理栈：弹出 t 和 t.arr
    lua_pop(L, 2);
}

void hive_app::add_string_to_array(lua_State* L, const char* table_name, const char* array_field_name, const char* str) {
    // 1. 获取全局 table t
    lua_getglobal(L, table_name);
    if (!lua_istable(L, -1)) {
        luaL_error(L, "Expected table for %s", table_name);
        return;
    }

    // 2. 获取 t.arr
    lua_getfield(L, -1, array_field_name);
    if (!lua_istable(L, -1)) {
        luaL_error(L, "Expected table for %s.%s", table_name, array_field_name);
        lua_pop(L, 2);
        return;
    }

    // 3. 获取当前数组长度
    lua_Integer len = lua_rawlen(L, -1);

    // 4. 压入要添加的字符串
    lua_pushlstring(L, str, strlen(str));

    // 5. 设置 t.arr[len + 1] = str
    lua_seti(L, -2, len + 1);

    // 6. 清理栈
    lua_pop(L, 2);
}
