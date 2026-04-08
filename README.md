# ClaymoreUW — Hands-on User Guide

This repository contains a practical, step-by-step guide for **building and running ClaymoreUW** on **TACC (LS6)**, with notes on common customization points (compile-time settings, JSON inputs, job scripts) and typical failure modes.

- **Theory/background (MPM, modeling choices)**: see Justin Bonus’ materials and dissertation.
  - Justin’s repo: [JustinBonus/claymore](https://github.com/JustinBonus/claymore)
  - Bonus, 2023 (dissertation): [Evaluation of Fluid-Driven Debris Impacts in High-Velocity Flows (ProQuest)](https://ezproxy.lib.utexas.edu/login?url=https://www.proquest.com/dissertations-theses/evaluation-fluid-driven-debris-impacts-high/docview/2915819774/se-2?accountid=7118)
- **Related UI tool**: SimCenter **HydroUQ** (in development) combines water-borne simulation tooling (incl. ClaymoreUW) with uncertainty modeling: [https://simcenter.designsafe-ci.org/research-tools/hydro-uq/](https://simcenter.designsafe-ci.org/research-tools/hydro-uq/)
- Previous tutorial materials: https://utexas.box.com/s/o6crp5ntpmnb5engtial675l5rp14mby

## Typical workflow

1. **Setup**
   - Choose module versions and (optionally) adjust `Settings.h` for hardware limits.
2. **Prepare inputs**
   - Configure object setup and JSON parameters.
   - Generate numerous batched input folders with Python as needed.
3. **Run**
   - Submit SLURM jobs (often via bash wrappers/loops).
4. **Review results**
   - Check logs, sensor results(CSV), object files, bgeo files
   - post-process (often with Python), visualize (e.g., animations).

## 1. Setup (TACC / LS6)

### 1.1 Register a TACC account & allocation

- Request access from your PI.
- Enable **Duo MFA** for logins.

### 1.2 Install recommended tools (free)

| Tool      | Link                                  | Description                                                  |
|-----------|---------------------------------------|--------------------------------------------------------------|
| Cursor ai | `https://cursor.com/download`         | VScode Based AI code editor with SSH support; useful for remote development.  |
| Cyberduck | `https://cyberduck.io/download/`      | GUI-based file transfer tool for SFTP/FTP/cloud connections.  |
| Houdini   | `https://www.sidefx.com/get/try-houdini/` | 3D animation and VFX software; used for bgeo file visualization. |

### 1.3 Connect via SSH 

1. Open **Cursor** (or VScode)
2. Connect via SSH → Add new SSH host
   - **Host**: `ls6.tacc.utexas.edu`
   - **Port**: `22`
   - **Username**: your TACC ID
3. Log in with your TACC password and approve via **Duo**
4. Open a Terminal (bash) and confirm your location:

```bash
pwd
cd /scratch/<your_number>/<TACCID>
```

### 1.4 Clone and build

#### Clone

```bash
git clone https://github.com/youngdie07/ClaymoreUW.git
ls  # Verify that the "claymoreUW" folder exists
```

#### Load modules

Module versions may vary by environment. The combination below is a known working baseline for LS6.

```bash
module load cmake/3.24.2
module load cuda/12.2
module load gcc/12.2.0
```

#### Configure and build (CMake)

```bash
cd ClaymoreUW
mkdir -p build
cd build
cmake ..
cmake --build .
```

#### Compile via helper script

> Compilation often takes **30+ minutes** and may require troubleshooting depending on the node type and module versions.

If needed, adjust numerical settings in `Settings.h` *before* compiling.

```bash
cd ..
sh local_build.sh
```

If you see **100% compilation**, the build completed successfully.

## 2. Inputs (overview)

ClaymoreUW inputs are typically configured via:

- **JSON files** (simulation conditions / material parameters / numerical options)
- **Auxiliary assets** (object/geometry setup depending on project)
- **Python scripts** to generate parameter sweeps and input folder structures

> Detailed parameter meaning is project-dependent. For a deeper explanation of core modeling parameters, see Ch. 4 in [Bonus (2023)](https://ezproxy.lib.utexas.edu/login?url=https://www.proquest.com/dissertations-theses/evaluation-fluid-driven-debris-impacts-high/docview/2915819774/se-2?accountid=7118) or spreadsheet: https://utexas.box.com/s/bha49hqqh9xfiapuupxdpzoivz4jx0r6


## 3. Running (SLURM overview)

Most runs are submitted to the queue using `sbatch`, often wrapped by bash scripts that:

- set node/GPU layout
- run a loop over cases
- manage logs and output directories

Useful status commands:

```bash
squeue -u <TACCID>
```


## 4. Results (overview)

Outputs commonly include:

- **SLURM logs**: `.out` and `.err`
- **Result tables** (CSV formats)
- **Artifacts for visualization/animation** (obj, bgeo)

> For a deeper explanation of core modeling parameters, see Ch. 4 in [Bonus (2023)](https://ezproxy.lib.utexas.edu/login?url=https://www.proquest.com/dissertations-theses/evaluation-fluid-driven-debris-impacts-high/docview/2915819774/se-2?accountid=7118) or spreadsheet: https://utexas.box.com/s/bha49hqqh9xfiapuupxdpzoivz4jx0r6

## 5. Example: Flume experiment (checkpoint → resume)

The example below runs a checkpoint simulation and then resumes from it across multiple cases.

### 5.1 Submit checkpoint job
``` bash 
cd ./Projects/OSU_LWF/DigitalTwin/Test
bash submit_checkpoint.sh
```

### 5.2 Generate resume inputs

```bash
cd ./Projects/OSU_LWF/DigitalTwin/Test
python generate_inputs.py
```

Verify that input folders were created:

```bash
ls
```

### 5.3 Submit resume jobs

```bash
bash submit_all_jobs.sh
```

> You can modify submission settings (e.g., node count, walltime) by editing the `.sh` scripts directly.

### 5.4 Monitor jobs and inspect logs

```bash
squeue -u <TACCID>
cat logs/<job_name>.out
cat logs/<job_name>.err
```

### 5.5 Visualize

First, download the bgeo files to your local folder. 
You can open Bgeo files in Houdini using the 'object' feature.

For more detailed visualization settings in Houdini, refer to online resources or use generative AI tools for further guides.

---

## Troubleshooting / FAQ

### 1) Build errors (CMake/CUDA/GCC mismatch)

Most compile failures are caused by one of the following:

- **Incompatible module versions** across `cmake`, `cuda`, and `gcc`
- CUDA architecture flags that do not match the target GPUs

If the build system uses `setup_cuda.cmake`, check and align:

- `TARGET_CUDA_ARCH`
- `CMAKE_CUDA_ARCHITECTURES`

### 2) Quick reference: `Settings.h`
#### GPU configuration

| Variable | Meaning |
|----------|---------|
| `g_device_cnt` | Number of GPUs the build targets (must match hardware and job layout). |
| `g_models_per_gpu` | Maximum distinct particle models per GPU. |
| `g_model_cnt` | Total model slots: `g_device_cnt * g_models_per_gpu`. |

#### When you hit GPU / host memory limits

| Variable | What it controls |
|----------|------------------|
| `DOMAIN_BITS` | Grid resolution along an axis (\(2^{DOMAIN\_BITS}\) nodes). Lower → fewer grid nodes → less grid memory. |
| `g_length_x`, `g_length_y`, `g_length_z` | Active domain extent ratios vs `g_length`. Smaller ratios → fewer active grid blocks in that direction. |
| `g_max_active_block` | Cap on active grid blocks (preallocated). Lower → less reserved grid-block memory. |
| `MAX_PPC` | Max particles per cell (power of two). Lower → less particle memory per cell/block. |
| `g_max_particle_num` | Global particle count cap (preallocated). Lower → less particle buffer memory. |

### 3) Changing simulation conditions

Simulation conditions are typically set via **JSON** input files. If your project provides an accompanying spreadsheet, use it as the primary parameter reference; for detailed modeling context, see Bonus (2023).

### 4) Essential Settings for High-Resolution, Thin-Flow (e.g., Flow through Column), and Debris-Laden Flow Simulations
   1. `Setting.h` (see the default values in setting.h)
      1. DOMAIN_BITS 
      2. `g_length_x`, `g_length_y`, `g_length_z`
      3. MAX_PPC
      4. g_max_active_block, g_max_particle_num
      > These might be calibrated to optimize the numerical capacity. 

   2. JSON Parameters (see the example JSON file or see Ch. 4 in [Bonus (2023)](https://ezproxy.lib.utexas.edu/login?url=https://www.proquest.com/dissertations-theses/evaluation-fluid-driven-debris-impacts-high/docview/2915819774/se-2?accountid=7118))
      1. default_dt
      2. default_dx
      3. CFL (likely less than 0.5)     
      4. Bulk modulus 
      5. ASFLIP 
      6. Young's modulus
      > These might be calibrated & validated to optimize the behavior of particles (fluids or solids). 

   3. Checkpoint and Resume (see the example JSON file)
      1. output_attribs : '
               "J",
               "Velocity_X",
               "Velocity_Y",
               "Velocity_Z",
               "JBar",
               "ID" '
      2.  upload checkpoint file, such as:
               "object": "file",
               "operation": "Add",
               "file": "../cp/model[0]_dev[0]_frame[40].bgeo",
      
### 5) How to Run a Draft Simulation Faster than Waiting in the sbatch Queue

To quickly run a draft simulation, follow these steps:

1. Change to the `tmp` directory:
   ```bash
   cd tmp
   ```
2. Submit the allocation script:
   ```bash
   sbatch alloc.script
   ```

**Notes:**
- Edit `alloc.script` before submitting to set the simulation time and adjust any necessary details.
- The allocation script initially runs a placeholder Python file. Once you receive a GPU allocation:
    - Access the allocated node, for example:
      ```bash
      ssh c303-003
      ```
    - Start your simulation and monitor its progress live on the GPU.
    - To check GPU status, use:
      ```bash
      nvidia-smi
      ```
    - Set: 
      module load cmake/3.24.2
      module load cuda/12.2
      module load gcc/12.2.0
    - Run simulation:
      srun --pty -A [BCS23016] --nodes=1 --ntasks=1 --time=48:00:00 --partition=gpu-a100 /bin/bash

### 6) Useful File Transfer Tools
- **Cyberduck** (or FileZilla): Commonly used for managing and downloading files.
- **Globus**: Recommended for transferring large datasets, as it reduces the need for repeated authentication during login.

### 7) Known issue: node GPU count mismatch
Some job scripts are written for **3 GPUs**, but LS6 allocations can sometimes land on nodes offering **2 GPUs**, causing failures.

- Check `gpu_usage.log` (if present in your workflow) to confirm the mismatch.
- Workaround: **resubmit** until an appropriate node is assigned, or adjust the job script to match the available GPU layout.

### 8) Model Capacity and Memory Considerations

The current example is set up to fully utilize 3 GPUs on LS6. If your simulation involves a fluid particle or grid domain larger than this example, you are likely to encounter GPU memory issues. In such cases, consider one of the following:

- Utilize more capable HPC resources with greater memory/GPU capacity.
- Use a smaller simulation domain.
- Adjust your simulation settings to be coarser—such as lowering the grid resolution or reducing the maximum particles-per-cell (PPC).

Carefully managing model size and settings is essential to avoid memory-related failures on the current hardware.
