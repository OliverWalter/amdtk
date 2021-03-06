#!/usr/bin/env bash

det_annealing="no"
while [[ $# > 6 ]]
do
    key="$1"
    
    case $key in
	--det_annealing)
	    det_annealing="yes"
	    ;;
	*)
        # unknown option
	    ;;
    esac
    shift # past argument or value
done

if [ $# -ne 6 ]; then
    echo "usage: $0 <setup.sh> <parallel_opts> <niter> <keys> <model_in_dir> <model_out_dir> "
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
out_dir="$6"

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
        utils/phone_loop_vb_iter.sh \
            "$setup" \
            "$parallel_opts" \
            "$keys" \
            "$unigram_ac_weight" \
            "$out_dir/iter$((i - 1))" \
            "$out_dir/iter$i" || exit 1

        echo "iteration: $i log-likelihood >= $(cat $out_dir/iter$i/llh.txt)"|| exit 1
    done

    # Copy the model of the last iteration to the output directory.
    cp  "$out_dir/iter$niter/model.bin" "$out_dir/model.bin" || exit 1

    date > "$out_dir/.done"
else
    echo "The model is already trained. Skipping."
fi

