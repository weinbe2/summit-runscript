# summit-runscript
Reference scripts to run QUDA test utilities on Summit. Not guaranteed to be optimal.

## Top level summary
To run these scripts as-is, clone this repository, make a static link (`ln -s`) to `./staggered_invert_test` in this directory, build a submit script using `./build-submit-script.sh` (run it without any arguments to get an error message telling you what to do), and submit the built script using `bsub`. 

## All the details

These scripts aren't specifically set up to be run in any organized directory structure; they are a base that should be customized for any user's specific needs. Currently, the scripts assume that a job will be submitted from the same directory that these scripts run it (but again, it should be clear and easy to see how to change that). The scripts are currently hard-coded to assume the QUDA test executable "staggered\_invert\_test" also lives in the same directory, either copied there or statically linked (i.e., you called `ln -s [QUDA test directory]/staggered_invert_test` in this directory. I'll document how to modify this below.

These scripts have only been tested with the `feature/p2p-zero-copy` branch of QUDA (though I don't see any reason why it wouldn't work with any modern branch) with the QMP interface. These scripts assume `t` is the fast direction, i.e., it's preferentially split within a node, which can be verified with the output from the `feature/p2p-zero-copy` branch. I don't see why using a different (modern) repository, or using MPI instead of QMP when building QUDA, should make a difference. _Please tell me if you find any issues._

I'm not sure if it makes a difference, but to be complete, my `~/.profile` file contains (and contained when I built QMP, QIO, and QUDA):

```
module load cmake/3.9.2
module load git/2.13.0
module load makedepend/1.0.5
module load screen/4.3.1
module load cuda/9.2.64
```

The description of the files is as follows:
* `bind-4gpu.sh`: The `numactl` script when you only use 4 GPUs per node. This only gets used if there isn't a factor of 3 in the `T` or `Z` direction. (This choice is based on the assumption that the _global_ dimension in the `X`, `Y`, and `Z` directions are all equal. I'm sure with some topologies this will break.) _This may not be ideal: I'm looking for feedback on this._
* `bind-6gpu.sh`: The `numactl` script when you use the full 6 GPUs per node. This gets used if my scripts can detect a factor of 3 in the `T` or `Z` direction. _This may not be ideal: I'm looking for feedback on this._
* `build-submit-script.sh`: The script that writes submit scripts by modifying `submit-script-base.lsf`, which is described below. The script also creates a directory where a QUDA tunecache gets saved (if it does not already exist).
  * The script takes 9 arguments: `./build-submit-script.sh [nnodes] [global x] ... [global t] [grid x] ... [grid t]`, where `global` refers to the global volume, and `grid` refers to the breakdown of the topology, i.e., a topology of `1 1 1 6` refers to not breaking up the x, y, and z directions, and splitting the t direction 6 ways.
    * This is technically an overcomplete description: the number of nodes is implied by the global volume and topology, but the extra information is used as a consistency check within the script.
  * Lines 24 through 35 make sure the local volumes divide into the global volume (lines 25 through 28), and further that each local volume is even (lines 31 through 34).
  * Lines 43 through 46 determine if there's a factor of 3. If so, all 6 GPUs per node are used, otherwise 4 GPUs per node are used.
  * Lines 53 through 57 perform a consistency check between the topology and the number of nodes times number of GPUs used per node.
  * Lines 60 through 62 build a unique identifier string for the number of nodes, global volume, and topology, which enters the name of the submit script and tuning directory.
    * The string gives, in order, the global dimensions, the number of nodes, and the local topology, which should give a unique description for the topology.
      * Of course, there's no reason why a single tunecache file can't be shared between multiple volumes/topologies/etc. This was just a design choice, and the submit script itself assumes a tunecache directory with the structure defined below. This is obviously easy to modify.
    * To make the convention more explicit: a `48^3 x 96` volume being run on 8 nodes (48 GPUs) with a topology `1 x 2 x 4 x 6` will generate the identifier string `48x48x48x96-n8-1x2x4x6`
  * Lines 69 through 75 builds an appropriate submit script by doing `sed` global find-replaces on the base file `submit-script-base.lsf`, saving to a useable submit script (given the example above) of `submit-script-48x48x48x96-n8-1x2x4x6.lsf`. There are 10 replacements:
    * `:NNODES:` - the number of nodes.
    * `:NGPUS:` - the number of GPUs
    * `:GRIDX:`, `:GRIDY:`, ... - the topology.
    * `:DIMX:`, `:DIMY:`, ... - the global volume.
    * The choice of passing in the topology versus the local volume is arbitrary (though, the way I wrote the base submit script, is necessary to specify the output filename). This is easy to change.
  * Lines 81 through 86 creates a tunecache directory (if it does not already exist) of the format (given the example above) of `tunecache-48x48x48x96-n8-1x2x4x6`.
* `submit-script-base.lsf`: The base submit script that gets modified by `build-submit-script.sh`. _This script will not run as is._ The relevant lines each person could want to modify are noted below.
  * Line 5: The number of nodes. This gets set by `build-submit-script.sh`.
  * Line 11: The walltime in minutes. Hardcoded to 30.
  * Line 18: The project name.
  * Line 21: The job name.
  * Line 24: The output filename, components of which get set by `build-submit-script.sh`. The output name as written breaks the convention of using `-` within the identifier string, using `.` instead, because the job submit parser complains about the "`-n`" that lives within the identifier string. I should fix it so a consistent character is used everywhere (maybe `_`?), I just haven't gotten around to it.
  * Lines 32 through 47: Defines useful `bash` variables based on what's set by `build-submit-script.sh`. As written, the topology and the global volume is passed in (living in the variables `GRIDX`, ..., `GRIDT`, `DIMX`, ..., `DIMT`), and the per-GPU volume is reconstructed (`LOCALDIMX`, ..., `LOCALDIMT`). The consistency checks in `build-submit-script.sh` guarantees the integer division will be safe.
    * These lines should be modified if you want to pass in, for ex, the global and local volumes instead.
  * Line 53: Defines the QUDA test executable to call. Currently hard coded to `staggered_invert_test`. This assumes the executable, or a static link to it, lives in the same directory.
  * Line 54: Defines the topology and local volume (per the convention of the `--gridsize` and `--dim` flags passed to QUDA test executable), as well as any additional flags. 
    * The existing flags assume reconstruct-12 is used (`--recon 12 --recon-sloppy 12`), and the inversion is run to a maximum iterations of 10000 or a tolerance of 1e-5 (`--niter 10000 --tol 1e-5`).
  * Line 55: Builds the total execution string and stores it into the variable `$APP`. The `numactl` scripts `bind-4gpu.sh` and `bind-6gpu.sh` _assume_ this variable is set.
    * You can replace this with `export APP=./jsrun_layout`, the utility given [here](https://code.ornl.gov/t4p/Hello_jsrun), to understand how the `jsrun` command described below works.
  * Line 57: Sets the QUDA tunecache directory `QUDA_RESOURCE_PATH`, consistent with the directory created in `build-submit-script.sh`.
  * Line 60 through 74: Builds the `jsrun` command, using the 4 or 6 GPU binding scripts as appropriate. The way I build the command is "consistent" with the binding scripts, in so far as they work. _This may not be ideal: I'm looking for feedback on this._ Description of the command:
    * `--nrs ${NNODES}`: Request `${NNODES}` "resource sets", in the parlance of the resource manager on Summit. The convention of the number of resource sets equalling the number of nodes is consistent with how I defined the subsequent flags.
    * The subsequent flags depend on if you're using 4 or 6 GPUs:
      * 6 GPU case: `-a6 -g6 -c42 -dpacked -b packed:7`: request 6 MPI ranks per resource set/node, 6 GPUs (such that each rank can see all 6 GPUs, QUDA takes advantage of assigning them), 42 cores (the bind script binds CPUs to GPUs so far as I can tell appropriately). So far as I understand `-dpacked` and `-b packed:7` specify how ranks are ordered among multiple nodes, and assign 7 _hardware cores_ to each rank (if I remember correctly). The explicit `export OMP_NUM_THREADS=7` may not be needed in all case, for example, in the case of `QDPJIT` where there should only be one launching thread. _This probably isn't ideal, and I'd love corrections or a better explanation._
      * 4 GPU case: `-a4 -g6 -c40 -dpacked -b packed:10`: request 4 MPI ranks per resource set/node, 6 GPUs (this, combined with the line `export CUDA_VISIBLE_DEVICES=0,1,3,4`, ensures that pairs of GPUs connected by NVLINK are used, as opposed to an asymmetric setup of 3 GPUs connected by NVLINK, and another on its own within a node), and 40 cores, where the `-dpacked` and `-b packed:10` specifies the ordering of ranks and assigns 10 _hardware cores_ to each rank. See the above comment about the `export OMP_NUM_THREADS` line. _This probably isn't ideal, and I'd love corrections or a better explanation._
    * `--latency_priority gpu-cpu`: This probably gets ignored due to specifying bindings via `numactl`, but in principle when you trust `jsrun` to assign a layout for you it preferentially assigns it to minimize GPU to CPU latencies as opposed to CPU to CPU latencies (`cpu-cpu`). 
    * `--bind-4gpu.sh` or `--bind-6gpu.sh`, using the correct `numactl` script as appropriate.
  * Line 77: Print the final `jsrun` command.
  * Line 79: Execute the `jsrun` command. You can comment this out for testing: I believe you can run `./build-submit-script.sh` to build a submit script, then run the built script _without_ bsub to investigate the generated `jsrun` command.

After generating a submit script, you can submit it as-is using `bsub [submit script]` without any further flags (unless you want to, of course).

A few example commands:
* `48^3 x 96`, topology `1x2x4x12`, so 16 nodes:
  * `./build-submit-script 16 48 48 48 96 1 2 4 12` creates the submit script `submit-script-48x48x48x96-n16-1x2x4x12.lsf` and the tunecache directory `tunecache-48x48x48x96-n16-1x2x4x12`, using the 6 GPU binding script because there's a factor of 3.
* `64^3 x 128`, topology `1x4x4x16`, so 64 nodes:
  * `./build-submit-script 64 64 64 64 128 1 4 4 16` creates the submit script `submit-script-64x64x64x64-n64-1x4x4x16.lsf` and the tunecache directory `tunecache-48x48x48x96-n16-1x2x4x12`, using the 4 GPU binding script because there are no factors of 3.
* `96^3 x 196`, topology `4x8x8x48`, so 2048 (!) nodes:
  * `./build-submit-script 2048 96 96 96 196 4 8 8 48` creates the submit script `submit-script-96x96x96x192-n2048-4x8x8x48.lsf` and the tunecache directory `tunecache-96x96x96x192-n2048-4x8x8x48`, using the 6 GPU binding script because there is a factor of 3.

I hope this is a sufficient description of the scripts and how to use them. If there's anything unclear, please send me a message at evansweinberg \[at\] gmail.com. Alternatively, I'm happy to give anyone access to the repo to make edits or submit a pull request, similarly send me a message. 

_Most importantly:_ If there's anything that's sub-optimal, misguided, or wrong, PLEASE let me know!

Cheers!
 - Evan Weinberg, evansweinberg \[at\] gmail.com
