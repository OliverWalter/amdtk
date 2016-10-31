#!/usr/bin/env bash

set -e

# 
# Acoustic Unit Discovery based on infinite phone-loop model.
#

if [ $# -ne 1 ]; then
    echo "usage: $0 <setup.sh>"
    exit 1
fi

setup=$1

source $setup

# Copy setup.sh to the experiment directory so that it can be re-run.
if [ -e $root/$model_type/setup.sh ]; then
    diff $setup $root/$model_type/setup.sh >/dev/null \
        || echo "Warning: $model_type/setup.sh differs; not overwriting" >&2
else
    mkdir -p $root/$model_type
    cp $setup $root/$model_type/setup.sh
fi

n=0 

echo "===================================================="
echo "($((++n))) Data preparation..."
echo "===================================================="
local/prepare_data.sh \
    $setup
echo done

echo "===================================================="
echo "($((++n))) Features extraction..."
echo "===================================================="
utils/extract_features_db.sh \
    $setup \
    "$fea_parallel_opts"
echo done

echo "===================================================="
echo "($((++n))) Creating the model..."
echo "===================================================="
utils/phone_loop_create.sh \
    $setup \
    $train_keys \
    $root/$model_type/initial_model
echo done

echo "===================================================="
echo "($((++n))) Training the model with unigram LM..."
echo "===================================================="
utils/phone_loop_train.sh \
    $setup \
    "$train_parallel_opts" \
    20 \
    $train_keys \
    $root/$model_type/initial_model \
    $root/$model_type/unigram
echo done

exit 0

(
    echo "($((++n))) Labeling the unigram model..."
    utils/phone_loop_label.sh $setup  $root/$model_type/unigram \
        $root/$model_type/unigram_labels || exit 1
    echo done
    
    echo "($((++n))) Scoring the unigram  model..."
    mkdir -p $root/$model_type/unigram_labels_nmi || exit 1
    amdtk_concat --htk --keyfile data/eval.keys \
        --directory $root/$model_type/unigram_labels \
        --fname_format '{0}_timed.lab' \
        $root/$model_type/unigram_labels_nmi/unigram.mlf || exit 1
    sed -i 's/_timed.lab/.lab/g' \
        $root/$model_type/unigram_labels_nmi/unigram.mlf || exit 1
    amdtk_score_labels -s data/xitsonga.split data/xitsonga_phn.mlf \
        $root/$model_type/unigram_labels_nmi/unigram.mlf \
        > $root/$model_type/unigram_labels_nmi/scores || exit 1
    echo done
) &

(
    echo "($((++n))) Generating hmm state posteriors in text format..."
    mkdir -p $root/$model_type/unigram_posts_txt || exit 1
    cp data/sil_va.keys $root/$model_type/unigram_posts_txt/post.keys || exit 1
    utils/phone_loop_post.sh $setup $root/$model_type/unigram \
        $root/$model_type/unigram_posts_txt --as_text --hmm_states &
    echo done

    echo "($((++n))) Generating unit posteriors in text format..."
    mkdir -p $root/$model_type/unigram_unit_posts_txt || exit 1
    cp data/sil_va.keys $root/$model_type/unigram_unit_posts_txt/post.keys || exit 1
    utils/phone_loop_post.sh $setup $root/$model_type/unigram \
        $root/$model_type/unigram_unit_posts_txt --as_text || exit 1
    echo done
    
    wait || exit 1

    echo "($((++n))) Scoring hmm state and unit posteriors..."
    mkdir -p $root/$model_type/unigram_eval1 || exit 1
    echo $root/$model_type/unigram_posts_txt \
        > $root/$model_type/unigram_eval1/list || exit 1
    echo $root/$model_type/unigram_unit_posts_txt \
        >> $root/$model_type/unigram_eval1/list || exit 1
    utils/score_eval1_db.sh $setup $root/$model_type/unigram_eval1 || exit 1
    echo done
) &

(
    echo "($((++n))) Generating hmm state posteriors in htk format..."
    utils/phone_loop_post.sh $setup $root/$model_type/unigram \
        $root/$model_type/unigram_posts_va || exit 1
    echo done

    echo "($((++n))) Generating lattices..."
    utils/create_lattices_db.sh $setup $root/$model_type/unigram_posts_va \
        $root/$model_type/unigram_lattices_va || exit 1
    echo done

    echo "($((++n))) Scoring the unigram model..."
    mkdir -p $root/$model_type/unigram_lattices_va_nmi || exit 1
    amdtk_concat --htk --keyfile data/eval.keys \
        --directory $root/$model_type/unigram_lattices_va \
        --fname_format '{0}_timed.lab' \
        $root/$model_type/unigram_lattices_va_nmi/unigram.mlf || exit 1
    sed -i 's/_timed.lab/.lab/g' \
        $root/$model_type/unigram_lattices_va_nmi/unigram.mlf || exit 1
    amdtk_score_labels -s data/xitsonga.split data/xitsonga_phn.mlf \
        $root/$model_type/unigram_lattices_va_nmi/unigram.mlf \
        > $root/$model_type/unigram_lattices_va_nmi/scores || exit 1
    echo done
) &

echo "($((++n))) Training bigram model..."
utils/phone_loop_retrain.sh $setup 20 5 $root/$model_type/unigram \
    $root/$model_type/bigram || exit 1
echo done

(
    echo "($((++n))) Labeling the bigram model..."
    utils/phone_loop_label.sh $setup  $root/$model_type/bigram \
        $root/$model_type/bigram_labels || exit 1
    echo done

    echo "($((++n))) Scoring the bigram model..."
    mkdir -p $root/$model_type/bigram_labels_nmi || exit 1
    amdtk_concat --htk --keyfile data/eval.keys \
        --directory $root/$model_type/bigram_labels \
        --fname_format '{0}_timed.lab' \
        $root/$model_type/bigram_labels_nmi/bigram.mlf || exit 1
    sed -i 's/_timed.lab/.lab/g' \
        $root/$model_type/bigram_labels_nmi/bigram.mlf || exit 1
    amdtk_score_labels -s data/xitsonga.split data/xitsonga_phn.mlf \
        $root/$model_type/bigram_labels_nmi/bigram.mlf \
        > $root/$model_type/bigram_labels_nmi/scores || exit 1
    echo done
) &

(
    echo "($((++n))) Generating hmm state posteriors in text format..."
    mkdir -p $root/$model_type/bigram_posts_txt || exit 1
    cp data/sil_va.keys $root/$model_type/bigram_posts_txt/post.keys || exit 1
    utils/phone_loop_post.sh $setup $root/$model_type/bigram \
        $root/$model_type/bigram_posts_txt --as_text --hmm_states &
    echo done

    echo "($((++n))) Generating unit posteriors in text format..."
    mkdir -p $root/$model_type/bigram_unit_posts_txt || exit 1
    cp data/sil_va.keys $root/$model_type/bigram_unit_posts_txt/post.keys || exit 1
    utils/phone_loop_post.sh $setup $root/$model_type/bigram \
        $root/$model_type/bigram_unit_posts_txt --as_text || exit 1
    echo done
    
    wait || exit 1

    echo "($((++n))) Scoring hmm state and unit posteriors..."
    mkdir -p $root/$model_type/bigram_eval1 || exit 1
    echo $root/$model_type/bigram_posts_txt \
        > $root/$model_type/bigram_eval1/list || exit 1
    echo $root/$model_type/bigram_unit_posts_txt \
        >> $root/$model_type/bigram_eval1/list || exit 1
    utils/score_eval1_db.sh $setup $root/$model_type/bigram_eval1 || exit 1
    echo done
) &

echo "($((++n))) Generating hmm state posteriors in htk format..."
utils/phone_loop_post.sh $setup $root/$model_type/bigram \
    $root/$model_type/bigram_posts_va || exit 1
echo done

echo "($((++n))) Generating lattices..."
utils/create_lattices_db.sh $setup $root/$model_type/bigram_posts_va \
    $root/$model_type/bigram_lattices_va || exit 1
echo done

(
    echo "($((++n))) Scoring the bigram model..."
    mkdir -p $root/$model_type/bigram_lattices_va_nmi || exit 1
    amdtk_concat --htk --keyfile data/eval.keys \
        --directory $root/$model_type/bigram_lattices_va \
        --fname_format '{0}_timed.lab' \
        $root/$model_type/bigram_lattices_va_nmi/bigram.mlf || exit 1
    sed -i 's/_timed.lab/.lab/g' \
        $root/$model_type/bigram_lattices_va_nmi/bigram.mlf || exit 1
    amdtk_score_labels -s data/xitsonga.split data/xitsonga_phn.mlf \
        $root/$model_type/bigram_lattices_va_nmi/bigram.mlf \
        > $root/$model_type/bigram_lattices_va_nmi/scores || exit 1
    echo done
) &

exit 0

echo "($((++n))) Running LatticeWordSegmentation..."
utils/run_latticewordsegmentation_db.sh $setup \
    ${root}/${model_type}/bigram_lattices_va \
    ${root}/${model_type}/bigram_ws || exit 1
echo done

(
    echo "($((++n))) Scoring word segmentation result..."
    mkdir -p ${root}/${model_type}/bigram_ws_eval2 || exit 1
    find $root/$model_type/bigram_ws/Results/ -type f \
        -name TimedSentences_Iter_150 \
        > ${root}/${model_type}/bigram_ws_eval2/score.list || exit 1
    utils/score_eval2_db.sh $setup ${root}/${model_type}/bigram_ws_eval2 \
        data/xitsonga.split || exit 1
    echo done
) &

echo "($((++n))) Converting segmentation result to unit sequence..."
mkdir -p $root/$model_type/bigram_ws_1best || exit 1
find $root/$model_type/bigram_ws/Results/ -type f \
    -name TimedSentences_Iter_150 \
    > $root/$model_type/bigram_ws_1best/convert.list || exit 1
utils/convert_segmentations_db.sh $setup \
    $root/$model_type/bigram_ws_1best || exit 1
echo done

echo "($((++n))) Retraining with unit sequence..."
for label_dir in $(find $root/$model_type/bigram_ws_1best -type d \
                   -name TimedSentences_Iter_*_1best)
do
    utils/phone_loop_retrain_1best.sh $setup 10 $root/$model_type/bigram \
        ${label_dir} ${label_dir}_model &
done || exit 1
wait || exit 1
echo done

(
    echo "($((++n))) Generating unit posteriors in text format..."
    for model_dir in $(find $root/$model_type/bigram_ws_1best -type d \
                      -name TimedSentences_Iter_*_1best_model)
    do
        post_txt_dir=$(echo ${model_dir}|sed 's/_model$/_posts_txt/') || exit 1
        mkdir -p ${post_txt_dir} || exit 1
        cp data/sil_va.keys ${post_txt_dir}/post.keys || exit 1
        utils/phone_loop_post.sh $setup ${model_dir} ${post_txt_dir} --as_text &
    done || exit 1
    wait || exit 1
    echo done

    echo "($((++n))) Scoring posteriors in text format..."
    mkdir -p $root/$model_type/bigram_ws_eval1 || exit 1
    find $root/$model_type/bigram_ws_1best -type d \
        -name TimedSentences_Iter_*_posts_txt \
        > $root/$model_type/bigram_ws_eval1/list || exit 1
    utils/score_eval1_db.sh $setup $root/$model_type/bigram_ws_eval1 || exit 1
    echo done
) &

(
    echo "($((++n))) Labeling the unigram model..."
    for model_dir in $(find $root/$model_type/bigram_ws_1best -type d \
                           -name TimedSentences_Iter_*_1best_model)
    do
        utils/phone_loop_label.sh $setup ${model_dir} \
            $(echo ${model_dir}|sed 's/_model$/_labels/') &
    done || exit 1
    wait || exit 1
    echo done

    echo "($((++n))) Scoring the unigram model..."
    for label_dir in $(find $root/$model_type/bigram_ws_1best -type d \
                           -name TimedSentences_Iter_*_1best_labels)
    do
        (
            nmi_dir=$(echo ${label_dir}|sed 's/_labels$/_nmi/') || exit 1
            mkdir -p ${nmi_dir} || exit 1
            amdtk_concat --htk --keyfile data/eval.keys --directory ${label_dir} \
                --fname_format '{0}_timed.lab' ${nmi_dir}/unigram.mlf || exit 1
            sed -i 's/_timed.lab/.lab/g' ${nmi_dir}/unigram.mlf || exit 1
            amdtk_score_labels -s data/xitsonga.split data/xitsonga_phn.mlf \
                ${nmi_dir}/unigram.mlf > ${nmi_dir}/scores || exit 1
        ) &
    done || exit 1
    wait || exit 1
    echo done
) &

(
    echo "($((++n))) Generating hmm state posteriors in htk format, Generating lattices and scoring the unigram model..."
    for model_dir in $(find $root/$model_type/bigram_ws_1best -type d \
                          -name TimedSentences_Iter_*_1best_model)
    do
      (
          post_dir=$(echo ${model_dir}|sed 's/_model$/_posts_va/') || exit 1
          utils/phone_loop_post.sh $setup ${model_dir} \
              ${post_dir} || exit 1

          lattices_dir=$(echo ${model_dir}|sed 's/_model$/_lattices_va/')
          utils/create_lattices_db.sh $setup ${post_dir} \
              ${lattices_dir} || exit 1

          nmi_dir=$(echo ${model_dir}|sed 's/_model$/_va_nmi/') || exit 1
          mkdir -p ${nmi_dir}
          amdtk_concat --htk --keyfile data/eval.keys \
              --directory ${lattices_dir} \
              --fname_format '{0}_timed.lab' ${nmi_dir}/unigram.mlf || exit 1
          sed -i 's/_timed.lab/.lab/g' ${nmi_dir}/unigram.mlf || exit 1
          amdtk_score_labels -s data/xitsonga.split data/xitsonga_phn.mlf \
              ${nmi_dir}/unigram.mlf > ${nmi_dir}/scores || exit 1
      ) &
    done || exit 1
    wait || exit 1
    echo done
) &
