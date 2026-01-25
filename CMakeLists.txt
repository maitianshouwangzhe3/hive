cmake_minimum_required(VERSION 3.14)

project(hive)

set(CMAKE_CXX_STANDARD 17)

aux_source_directory(${PROJECT_SOURCE_DIR}/src HIVE_CORE)

set(HIVE_INC
    ${PROJECT_SOURCE_DIR}/lz4
    ${PROJECT_SOURCE_DIR}/src
    ${PROJECT_SOURCE_DIR}/lua
)

# 只添加lua子目录以构建静态库，但不安装其中的内容
add_subdirectory(3rd/lua EXCLUDE_FROM_ALL)
add_subdirectory(3rd/luna EXCLUDE_FROM_ALL)

# 根据子目录中构建的库调整链接目标
add_executable(hive ${HIVE_CORE} ${HIVE_LUA})

target_include_directories(hive PRIVATE ${HIVE_INC} ${PROJECT_SOURCE_DIR}/3rd/lua ${PROJECT_SOURCE_DIR}/3rd/luna)
# 如果构建了静态库，则链接lua_static，否则链接lua可执行文件目标
target_link_libraries(hive PRIVATE lua_static luna_static)

include(GNUInstallDirs)

# 安装规则：只安装hive可执行文件到bin目录
install(TARGETS hive
    RUNTIME DESTINATION ${PROJECT_SOURCE_DIR}/bin
)