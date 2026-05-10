#!/usr/bin/env bash

tmp_dir="/tmp/cliphist"
mkdir -p "$tmp_dir"

cliphist list | gawk -v tmp="$tmp_dir" '
BEGIN { FS="\t"; OFS="\t" }
{
    if ($2 ~ /^\[\[\s?binary.*(jpg|jpeg|png|bmp|webp)/) {
        match($2, /(jpg|jpeg|png|bmp|webp)/, ext)
        img_path = tmp "/" $1 "." ext[1]

        # test -s checks if the file exists AND is not empty (>0 bytes)
        if (system("test -s \"" img_path "\"") != 0) {
            # Use awks native pipe to safely send the exact line to cliphist
            cmd = "cliphist decode > \"" img_path "\""
            print $0 | cmd
            close(cmd)
        }

        # Output: ID \t DISPLAY_TEXT \t /path/to/image
        print $1, $2, img_path
    } else {
        # Regular text
        print $0
    }
}'
