#!/bin/bash

# ==== CONFIGURATION ====
BASE_PORT=30000
BASE_TM_PORT=50000
IS_BENCH2DRIVE=True

# Path to the base route XML file (do NOT add .xml)
BASE_ROUTES=leaderboard/data/bench2drive220

# Team Agent (your inference script)
TEAM_AGENT=leaderboard/team_code/vad_b2d_agent.py

# Config + Checkpoint
TEAM_CONFIG=tools/vad_model/VAD_base_e2e_b2d.py+tools/vad_model/vad_b2d_base.pth

# Output JSON files and logs
BASE_CHECKPOINT_ENDPOINT=eval_bench2drive220
PLANNER_TYPE=traj
ALGO=vad
SAVE_PATH=./eval_bench2drive220_${ALGO}_${PLANNER_TYPE}

# ==== ROUTE SPLIT ====
if [ ! -d "${ALGO}_b2d_${PLANNER_TYPE}" ]; then
    mkdir ${ALGO}_b2d_${PLANNER_TYPE}
    echo -e "\033[32m Directory ${ALGO}_b2d_${PLANNER_TYPE} created. \033[0m"
else
    echo -e "\033[32m Directory ${ALGO}_b2d_${PLANNER_TYPE} already exists. \033[0m"
fi

if [ ! -f "${BASE_ROUTES}_${ALGO}_${PLANNER_TYPE}_split_done.flag" ]; then
    echo -e "****************************\033[33m Splitting Routes \033[0m****************************"
    TASK_NUM=4  # Update this based on how many CARLA instances/GPU you want to run
    python tools/split_xml.py $BASE_ROUTES $TASK_NUM $ALGO $PLANNER_TYPE
    touch "${BASE_ROUTES}_${ALGO}_${PLANNER_TYPE}_split_done.flag"
    echo -e "\033[32m Splitting complete. Flag file created. \033[0m"
else
    echo -e "\033[32m Splitting already done. \033[0m"
fi

# ==== GPU Assignment ====
GPU_RANK_LIST=(0 1 2 3)
TASK_LIST=(0 1 2 3)

length=${#GPU_RANK_LIST[@]}
for ((i=0; i<$length; i++ )); do
    PORT=$((BASE_PORT + i * 150))
    TM_PORT=$((BASE_TM_PORT + i * 150))
    ROUTES="${BASE_ROUTES}_${TASK_LIST[$i]}_${ALGO}_${PLANNER_TYPE}.xml"
    CHECKPOINT_ENDPOINT="${ALGO}_b2d_${PLANNER_TYPE}/${BASE_CHECKPOINT_ENDPOINT}_${TASK_LIST[$i]}.json"
    GPU_RANK=${GPU_RANK_LIST[$i]}

    echo -e "\033[32m TASK_ID: $i | PORT: $PORT | GPU: $GPU_RANK\033[0m"
    bash -e leaderboard/scripts/run_evaluation.sh \
        $PORT \
        $TM_PORT \
        $IS_BENCH2DRIVE \
        $ROUTES \
        $TEAM_AGENT \
        $TEAM_CONFIG \
        $CHECKPOINT_ENDPOINT \
        $SAVE_PATH \
        $PLANNER_TYPE \
        $GPU_RANK \
        2>&1 > ${BASE_ROUTES}_${TASK_LIST[$i]}_${ALGO}_${PLANNER_TYPE}.log &

    sleep 5

done
wait
