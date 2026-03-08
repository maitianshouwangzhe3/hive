cmake_minimum_required(VERSION 3.14)

project(hive)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -rdynamic")

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Debug CACHE STRING "Build type" FORCE)
endif()

aux_source_directory(${PROJECT_SOURCE_DIR}/src HIVE_CORE)

set(HIVE_INC
    ${PROJECT_SOURCE_DIR}/src
    ${PROJECT_SOURCE_DIR}/3rd/lua
    ${PROJECT_SOURCE_DIR}/3rd/luna
)

# 只添加lua子目录以构建静态库，但不安装其中的内容
# add_subdirectory(3rd/lua EXCLUDE_FROM_ALL)

# 根据子目录中构建的库调整链接目标
add_executable(hive ${HIVE_CORE})

target_include_directories(hive PRIVATE ${HIVE_INC})
# 如果构建了静态库，则链接lua_static，否则链接lua可执行文件目标
target_link_libraries(hive PRIVATE ${PROJECT_SOURCE_DIR}/3rd/lua/liblua.a ${PROJECT_SOURCE_DIR}/3rd/luna/luna.so)

include(GNUInstallDirs)

# 安装规则：只安装hive可执行文件到bin目录
install(TARGETS hive
    RUNTIME DESTINATION ${PROJECT_SOURCE_DIR}/bin
)