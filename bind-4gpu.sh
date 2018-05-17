#!/bin/bash

lrank=$(($PMIX_RANK % 4))

echo $APP

export OMP_NUM_THREADS=10
case ${lrank} in
 [0])
 export PAMI_IBV_DEVICE_NAME=mlx5_0:1
 numactl --physcpubind=0,4,8,12,16,20,24,28,32,36 --membind=0 $APP
 ;;
 
 [1])
 export PAMI_IBV_DEVICE_NAME=mlx5_0:1
 numactl --physcpubind=40,44,48,52,56,60,64,68,72,76 --membind=0 $APP
 ;;
 
 [2])
 export PAMI_IBV_DEVICE_NAME=mlx5_3:1
 numactl --physcpubind=88,92,96,100,104,108,112,116,120,124 --membind=8 $APP
 ;;
 
 [3])
 export PAMI_IBV_DEVICE_NAME=mlx5_3:1
 numactl --physcpubind=128,132,136,140,144,148,152,156,160,164 --membind=8 $APP
 ;;
esac
