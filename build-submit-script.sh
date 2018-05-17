#!/bin/bash
# Evan Weinberg, evansweinberg@gmail.com

# Script which builds a Summit submit script.
# Expects nine arguments:
# 1. Number of nodes
# 2-5. Global volume
# 6-9. Grid size
# Computes local volume from there, figures out
# if there should be 4 or 6 GPUs per node,
# does a consistency check between everything.

if [ "$#" -ne "9" ]; then
  echo "ERROR: Illegal number of parameters."
  echo "Expects [nnodes] [global x] ... [global t] [grid x] ... [grid t]"
  exit
fi

# Get info
nnodes=$1
dim=($2 $3 $4 $5)
grid=($6 $7 $8 $9)
localvol=()

# Made sure each grid size divides into dim with an even number
for i in $(seq 0 3); do
  if [ "$((${dim[$i]} % ${grid[$i]}))" -ne "0" ]; then
    echo "ERROR: Direction ${i}: ${grid[$i]} doesn't divide into ${dim[$i]}"
    exit
  fi
  localvol[$i]="$((${dim[$i]} / ${grid[$i]}))"

  if [ "$((${localvol[$i]} % 2))" -ne "0" ]; then
    echo "ERROR: Direction ${i}: Local length ${dim[$i]} / ${grid[$i]} = ${localvol[$i]} isn't even"
    exit
  fi
done

echo "Local volume: ${localvol[*]}"

# Figure out if there's a factor of three. If so, run with 6 GPUs,
# if not, run with 4. Check for the factor of 3 in the T
# and the Z direction.

ngpus=4
if [[ "$((${grid[3]} % 3))" -eq 0 || "$((${grid[2]} % 3))" -eq 0 ]]; then
  ngpus=6
fi

echo "Number of GPUs per node: ${ngpus}"

# Last, do a consistency check: make sure the
# grid volume equals the number of GPUs times 
# the number of nodes

if [ "$((${grid[0]} * ${grid[1]} * ${grid[2]} * ${grid[3]}))" -ne "$(($nnodes * $ngpus))" ]; then
  echo "ERROR: Grid volume $((${grid[0]} * ${grid[1]} * ${grid[2]} * ${grid[3]})) does not equal number of nodes times number of GPUs ${nnodes} x ${ngpus} = $(($nnodes * $ngpus))"
  exit
fi

# Identifier string.
cfgid="${dim[0]}x${dim[1]}x${dim[2]}x${dim[3]}"
cfgid="${cfgid}-n${nnodes}"
cfgid="${cfgid}-${grid[0]}x${grid[1]}x${grid[2]}x${grid[3]}"

# File to write to.
outfile="submit-script-${cfgid}.lsf"

echo "Writing script to: ${outfile}"

sed -e "s/:NNODES:/$nnodes/g" -e "s/:NGPUS:/${ngpus}/g" \
    -e "s/:GRIDX:/${grid[0]}/g" -e "s/:GRIDY:/${grid[1]}/g" \
    -e "s/:GRIDZ:/${grid[2]}/g" -e "s/:GRIDT:/${grid[3]}/g" \
    -e "s/:DIMX:/${dim[0]}/g" -e "s/:DIMY:/${dim[1]}/g" \
    -e "s/:DIMZ:/${dim[2]}/g" -e "s/:DIMT:/${dim[3]}/g" \
    submit-script-base.lsf > ${outfile}

# Tunecache directory
tunecache="tunecache-${cfgid}"

#if [[ ! -d $DIR ]]; then

if [[ -d $tunecache ]]; then
  echo "Tunecache directory ${tunecache} exists."
else
  echo "Making tunecache directory ${tunecache}..."
  mkdir ${tunecache}
fi

echo ""
