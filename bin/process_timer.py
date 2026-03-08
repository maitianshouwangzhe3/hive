#!/usr/bin/env python3
"""
Python脚本：拉起5个进程，记录每个进程的开始时间和结束时间，单位为毫秒
"""

import multiprocessing
import time
import random
import sys
import subprocess
import os
from typing import List, Tuple


def worker_process(pid: int, queue: multiprocessing.Queue) -> None:
    """
    工作进程函数
    :param pid: 进程ID
    :param queue: 用于传递时间信息的队列
    """
    # 记录开始时间（毫秒）
    start_time_ms = time.time() * 1000
    
    # 获取工作目录（脚本所在目录，即 bin 目录）
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = script_dir  # 根目录改为 bin 目录
    project_parent = os.path.dirname(project_root)  # 项目根目录（hive 目录）
    
    # 执行 ./hive ./test.lua 命令（在 bin 目录下执行）
    hive_path = os.path.join(project_root, "hive")
    test_lua_path = os.path.join(project_root, "test.lua")
    
    # 检查文件是否存在
    if not os.path.exists(hive_path):
        print(f"错误: hive 可执行文件不存在: {hive_path}")
        hive_path = os.path.join(project_parent, "build", "hive")
        if os.path.exists(hive_path):
            print(f"使用 build/hive: {hive_path}")
        else:
            print(f"错误: build/hive 也不存在")
            end_time_ms = time.time() * 1000
            queue.put((pid, start_time_ms, end_time_ms))
            print(f"进程 {pid} 失败: hive 可执行文件未找到")
            return
    
    if not os.path.exists(test_lua_path):
        print(f"警告: test.lua 文件不存在: {test_lua_path}")
    
    cmd = [hive_path, test_lua_path]
    
    try:
        # 在 bin 目录下执行命令
        result = subprocess.run(
            cmd,
            cwd=project_root,
            capture_output=True,
            text=True,
            timeout=500  # 设置500秒超时
        )
        
        # 记录结束时间（毫秒）
        end_time_ms = time.time() * 1000
        
        # 将时间信息放入队列
        queue.put((pid, start_time_ms, end_time_ms))
        
        # 打印进程信息
        duration_ms = end_time_ms - start_time_ms
        if result.returncode == 0:
            print(f"进程 {pid} 完成，耗时: {duration_ms:.2f} 毫秒，返回码: {result.returncode}")
        else:
            print(f"进程 {pid} 失败，耗时: {duration_ms:.2f} 毫秒，返回码: {result.returncode}")
            print(f"错误输出: {result.stderr[:200]}...")  # 只显示前200个字符
            
    except subprocess.TimeoutExpired:
        # 超时处理
        end_time_ms = time.time() * 1000
        queue.put((pid, start_time_ms, end_time_ms))
        print(f"进程 {pid} 超时，耗时: {end_time_ms - start_time_ms:.2f} 毫秒")
        
    except Exception as e:
        # 其他异常处理
        end_time_ms = time.time() * 1000
        queue.put((pid, start_time_ms, end_time_ms))
        print(f"进程 {pid} 异常: {e}，耗时: {end_time_ms - start_time_ms:.2f} 毫秒")


def main() -> None:
    """主函数"""
    print("启动5个进程并记录时间...")
    
    # 显示执行信息
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = script_dir  # 根目录改为 bin 目录
    project_parent = os.path.dirname(project_root)  # 项目根目录（hive 目录）
    
    hive_path = os.path.join(project_root, "hive")
    if not os.path.exists(hive_path):
        hive_path = os.path.join(project_parent, "build", "hive")
    
    test_lua_path = os.path.join(project_root, "test.lua")
    
    print(f"工作目录: {project_root}")
    print(f"项目目录: {project_parent}")
    print(f"hive 路径: {hive_path}")
    print(f"test.lua 路径: {test_lua_path}")
    print(f"执行命令: {os.path.basename(hive_path)} {os.path.basename(test_lua_path)}")
    print(f"超时时间: 500秒")
    
    # 创建队列用于进程间通信
    queue = multiprocessing.Queue()
    
    # 创建5个进程
    processes: List[multiprocessing.Process] = []
    for i in range(5):
        p = multiprocessing.Process(target=worker_process, args=(i, queue))
        processes.append(p)
    
    # 记录主程序开始时间
    main_start_ms = time.time() * 1000
    
    # 启动所有进程
    for p in processes:
        p.start()
        print(f"进程 {processes.index(p)} 已启动")
    
    # 等待所有进程完成
    for p in processes:
        p.join()
    
    # 记录主程序结束时间
    main_end_ms = time.time() * 1000
    
    # 收集结果
    results: List[Tuple[int, float, float]] = []
    while not queue.empty():
        try:
            result = queue.get_nowait()
            results.append(result)
        except:
            break
    
    # 按进程ID排序
    results.sort(key=lambda x: x[0])
    
    # 打印结果
    print("\n" + "="*60)
    print("进程时间统计（单位：毫秒）:")
    print("="*60)
    print(f"{'进程ID':<8} {'开始时间':<20} {'结束时间':<20} {'持续时间':<15}")
    print("-"*60)
    
    for pid, start_ms, end_ms in results:
        duration_ms = end_ms - start_ms
        print(f"{pid:<8} {start_ms:<20.2f} {end_ms:<20.2f} {duration_ms:<15.2f}")
    
    # 打印总统计信息
    print("-"*60)
    total_duration_ms = main_end_ms - main_start_ms
    print(f"总执行时间: {total_duration_ms:.2f} 毫秒")
    print(f"进程数量: {len(results)}")
    
    # 计算平均持续时间
    if results:
        avg_duration = sum(end_ms - start_ms for _, start_ms, end_ms in results) / len(results)
        print(f"平均进程持续时间: {avg_duration:.2f} 毫秒")
    
    print("="*60)


if __name__ == "__main__":
    main()