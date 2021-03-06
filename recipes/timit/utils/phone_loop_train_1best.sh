#!/usr/bin/env bash

if [ $# -ne 7 ]; then
    echo "usage: $0 <setup.sh> <parallel_opts> <niter> <keys> <model_in_dir> <labels_dir> <model_out_dir> "
    echo "                                                                                   "
    echo "Train the infinite phone-loop model.                                               "
    echo "                                                                                   "
    exit 0 
fi

setup="$1"
parallel_opts="$2"
niter="$3"
keys="$4"
init_model="$5/model.bin"
labels_dir="$6"
out_dir="$7"

source $setup || exit 1

if [ ! -e $out_dir/.done ]; then
    mkdir -p "$out_dir"
    
    # First, we copy the inital model to the iteration 0 directory.
    if [ ! -e "$out_dir"/iter0/.done ]; then
        mkdir "$out_dir"/iter0

        cp "$init_model" "$out_dir/iter0/model.bin" || exit 1 

        date > "$out_dir"/iter0/.done
    else
        echo "The initial model has already been set. Skipping."
    fi

    # Now start to train the model. 
    for i in $(seq "$niter") ; do
        utils/phone_loop_vb_iter_1best.sh \
            "$setup" \
            "$parallel_opts" \
            "$keys" \
            "$out_dir/iter$((i - 1))" \
            "$labels_dir" \
            "$out_dir/iter$i" || exit 1

        echo "iteration: $i log-likelihood >= $(cat $out_dir/iter$i/llh.txt)"|| exit 1
    done

    # Copy the model of the last iteration to the output directory.
    cp  "$out_dir/iter$niter/model.bin" "$out_dir/model.bin" || exit 1

    date > "$out_dir/.done"
else
    echo "The model is already trained. Skipping."
fi

