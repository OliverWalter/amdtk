#!/usr/bin/env bash
if [[ $# -ne 2  ]]; then
  echo "Usage: $0 <timing_file> <output_dir>"
  exit 1
fi

# parse filenames
timing_file=$1
output_dir=$2

rm -f ${output_dir}/*.lab
mkdir -p ${output_dir}
awk -v OUTDIR="$output_dir" -F' ' '{
  sub(".latt",".lab", $1);
  sub("</s>","", $2);
  if($2 != ""){
    line = gensub(/([0-9])a/, "\\1\na", "g", $2);
    print line >> OUTDIR"/"$1
  }
}' "$timing_file"

