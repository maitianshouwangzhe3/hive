/*
** repository: https://github.com/trumanzhao/luna
** trumanzhao, 2017-05-13, trumanzhao@foxmail.com
*/

#pragma once

#include "luna.h"

class hive_app final
{
public:
    hive_app() { }
    ~hive_app() { }
    time_t get_file_time(const char* file_name);
    int64_t get_time_ms();
    int64_t get_time_ns();
    void sleep_ms(int ms);
    void daemon();
    void mkdir(const char* path);
    void register_signal(int n);
    void default_signal(int n);
    void ignore_signal(int n);
    int create_socket_mgr(lua_State* L);

private:
    void add_number_to_array(lua_State* L, const char* table_name, const char* array_field_name, lua_Number value);

    void add_string_to_array(lua_State* L, const char* table_name, const char* array_field_name, const char* str);

public:
    void __gc() { } // custom gc, just do nothing
    void set_signal(int n);
    void run(int argc, const char* argv[]);

    DECLARE_LUA_CLASS(hive_app);
private:
    uint64_t m_signal = 0;
    int32_t m_reload_time = 2000;
};

extern hive_app* g_app;
