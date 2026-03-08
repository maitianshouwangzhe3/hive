#!/bin/bash
root=$(pwd)
dir=$root/proto

# 进入目标目录，便于生成相对路径（可选但推荐）
cd "$dir" || exit 1

# 递归查找所有普通文件，处理路径
find . -type f | while IFS= read -r file; do
    # 去掉开头的 "./"
    rel_path="${file#./}"

    # 分离目录部分和文件名
    dir_part="${rel_path%/*}"
    filename="${rel_path##*/}"

    # 去掉文件后缀
    name_without_ext="${filename%.*}"

    # 重组路径：如果文件在子目录中，保留目录；否则只有文件名
    if [ "$dir_part" = "$rel_path" ]; then
        # 说明没有 "/"，即文件在当前目录
        result="$name_without_ext"
    else
        result="$dir_part/$name_without_ext"
    fi

    echo "$result"
    new_path="${result#proto/}"
    new_path="pb/$new_path"
    echo "$new_path"

    old_file="${result}.proto"
    new_file="${root}/${new_path}.pb"
    protoc --descriptor_set_out=$new_file --include_imports $old_file
done

