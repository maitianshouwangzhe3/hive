#!/usr/bin/python
#coding: utf-8

import sys, os, subprocess, string, re;

apps = ["router", "gateway", "lobby", "dbagent"];

#根据app名字找到进程id
def find_pid_list(app):
    keyword = app + ".lua";
    text = subprocess.getoutput("ps aux");
    lines = text.split('\n');
    pids = [];
    for line in lines:
        if line.find(keyword) >= 0:
            words = line.split();
            pids.append(int(words[1]));
    return pids;

def find_all_app():
    pids = [];
    for one in apps:
        pids += find_pid_list(one);
    return pids;

