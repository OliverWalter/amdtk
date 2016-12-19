#!/usr/bin/env bash
if [[ $# -ne 3  ]]; then
  echo "Usage: $0 <setup> <parallel_opts> <output_dir>"
  exit 1
fi

# parse filenames
setup=$1
parallel_opts=$2
source ${setup} || exit 1

output_dir=$3

if [ ! -e ${output_dir}/.done ]; then
  amdtk_run $parallel_profile \
    --ntasks "$parallel_n_core" \
    --options "$convert_segmentation_parallel_opts" \
    "convert-segmentations" \
    "${output_dir}/convert.list" \
    "$root/utils/convert_segmentations.sh \$ITEM1 ${output_dir}/\$(echo \$ITEM1|sed \"s#${root}/${model_type}##\")_1best" \
    "$output_dir" || exit 1
    date > ${output_dir}/.done
else
  echo "1-best sequence already extracted. Skipping."
fi
