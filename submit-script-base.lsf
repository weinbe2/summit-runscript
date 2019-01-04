#!/bin/bash
# Job submission script
#
## One node
#BSUB -nnodes :NNODES:
#
## Queue
#BSUB -q batch
#
## Wall time in MINUTES
#BSUB -W 30
#
## Other flags: enable gpumps, for oversubscribing
#               MPI ranks to GPUs via MPS
#BSUB -alloc_flags gpumps
#
## Project name.
#BSUB -P LGT104
#
## Job name
#BSUB -J stag_profile
#
## Output file, %J refers to the job id
#BSUB -o stag_profile.:DIMX:x:DIMY:x:DIMZ:x:DIMT:.n:NNODES:.:GRIDX:x:GRIDY:x:GRIDZ:x:GRIDT:.%J

# Evan Weinberg, evansweinberg@gmail.com
# `jsrun` command loosely based on a command given to me by Kate, which I believe came from Chulwoo. 

# By default, environment variables get passed through.
# Exclude them with:
# -D (or) --env_no_propagate=<var>
#export APP="./jsrun_layout"

NNODES=:NNODES:

GRIDX=:GRIDX:
GRIDY=:GRIDY:
GRIDZ=:GRIDZ:
GRIDT=:GRIDT:

DIMX=:DIMX:
DIMY=:DIMY:
DIMZ=:DIMZ:
DIMT=:DIMT:

LOCALDIMX=$(( $DIMX / $GRIDX ))
LOCALDIMY=$(( $DIMY / $GRIDY ))
LOCALDIMZ=$(( $DIMZ / $GRIDZ ))
LOCALDIMT=$(( $DIMT / $GRIDT ))


GRIDSIZE="$GRIDX $GRIDY $GRIDZ $GRIDT"
LOCALSIZE="$LOCALDIMX $LOCALDIMY $LOCALDIMZ $LOCALDIMT"

export EXE="./staggered_invert_test"
export ARGS="--gridsize ${GRIDSIZE} --dim ${LOCALSIZE} --dslash-type staggered --recon 12 --recon-sloppy 12 --niter 10000 --tol 1e-5  --pipeline 1 "
export APP="$EXE $ARGS"

export QUDA_RESOURCE_PATH="${LS_SUBCWD}/tunecache-${DIMX}x${DIMY}x${DIMZ}x${DIMT}-n${NNODES}-${GRIDX}x${GRIDY}x${GRIDZ}x${GRIDT}/"

# Number of GPUs per node
NGPUS=:NGPUS:

# Build command
COMMAND="jsrun"
if [ "$NGPUS" -eq 4 ];
then
  export CUDA_VISIBLE_DEVICES=0,1,3,4
  export OMP_NUM_THREADS=10
  COMMAND="${COMMAND} --nrs ${NNODES} -a4 -g6 -c40 -dpacked -b packed:10 --latency_priority gpu-cpu --smpiargs=\"-gpu\" ./bind-4gpu.sh";
else # NGPUS -eq 6, guaranteed by script that builds this.
  export OMP_NUM_THREADS=7
  COMMAND="${COMMAND} --nrs ${NNODES} -a6 -g6 -c42 -dpacked -b packed:7 --latency_priority gpu-cpu --smpiargs=\"-gpu\" ./bind-6gpu.sh";
fi

# Execute command
echo "${COMMAND}"

${COMMAND}
