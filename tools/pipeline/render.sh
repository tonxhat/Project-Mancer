#!/bin/bash
# NOTE: edit S= (work folder) and the Godot binary path below for your machine. Copies the project to $S/rp and writes frames to $S/shots.
# usage: render.sh FRAMES [debug.gd]  -> renders project copy to shots/
S=/tmp/claude-0/-home-claude/6a0c7b53-723c-597b-8660-8f872140e9c7/scratchpad
rm -rf $S/rp && cp -r /home/claude/mancer_hd2d $S/rp && rm -f $S/shots/*
if [ -n "$2" ]; then cp $2 $S/rp/dbg.gd; printf '\n[autoload]\n\nDbg="*res://dbg.gd"\n' >> $S/rp/project.godot; fi
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json timeout 600 xvfb-run -a $S/godot/../godot47/Godot_v4.7.1-stable_linux.x86_64 --path $S/rp --rendering-method ${RM:-forward_plus} --rendering-driver vulkan --write-movie $S/shots/f.png --fixed-fps 30 --quit-after $1 2>&1 | grep -v -i -E "leak|^\s*at:|^\s*$|resources still|RID alloc" | grep -v "^---" 
