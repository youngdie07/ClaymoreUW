# ClaymoreUW Setup Guide (On Update)

## 1. Register TACC Account & Allocation
- Request access from your PI
- Remember your TACC ID/PW and activate **Duo MFA** for future log-in

---

## 2. Download Software (Free Version)
| Software | Download Link |
|----------|--------------|
| Cursor | https://cursor.com/download |
| Cyberduck | https://cyberduck.io/download/ |
| Houdini | https://www.sidefx.com/get/try-houdini/ |

---
## 3. Connecting via SSH

1. Open **Cursor**
2. Open Primary sidebar and Add extensions
   - Menubar > View > Appearance > Primary sidebar' to turn on the file manager siderbar
   - Add extensions at the marketplace in the sidebar such as: 'Remote - SSH', 'WSL', 'Python', etc. 
4. Connect via SSH → Add new SSH host
   - **Hostname (Server):** `ls6.tacc.utexas.edu`
   - **Port:** `22`
   - **Username:** your TACC ID
   - MACs hmac-sha2-256,hmac-sha2-512,hmac-sha1
5. Log in with your TACC password and approve via **Duo App**
6. Click folder settings at the left sidebar and move to /scratch/your_number/[TACCID]
7. Open a Terminal (bash) window in Cursor
   - 'Menubar > Terminal > New Terminal' to open the terminal below
   - Run `pwd` to confirm your current directory
   - Navigate to your scratch directory(if needed):
```bash
     cd /scratch/your_number/[TACCID]
```

---
## 4. Clone & Compile GitHub Repository

### Clone
```bash
git clone https://github.com/youngdie07/ClaymoreUW.git
ls  # Verify that the "ClaymoreUW" folder exists
```

### Set Modules
```bash
module load cmake/3.24.2
module load cuda/12.2
module load gcc/12.2.0
```

### Build
```bash
cd ClaymoreUW
mkdir build
cd build
cmake ..
cmake --build .
```

### Compile
> ⚠️ Compilation generally takes **30+ minutes** and may require troubleshooting depending on your system.

If needed, modify numerical settings in `Settings.h` before compiling.
```bash
cd ..
sh local_build.sh
```

✅ If the output shows **100% compilation**, ClaymoreUW has been successfully compiled.  
> You can ignore any `sudo` password prompts.

---
## 5. Run checkpoint simulation - Submit sbatch Job 
``` bash 
cd ./Projects/OSU_LWF/DigitalTwin/Test
bash submit_checkpoint.sh
```
This allows you to submit simulation run on lonestar6. You should wait for the squeue (usually takes about 0-2 days). Then wait for the simulation time you've requested through .sh file (e.g. 48 hours).

---
## 6-1. Create resume input files 
At the primary sidebar, move on to the Test directory
- Open the 'generate_inputs.py' file editor
- Tab the run button in the top right corner.
- Set a Python Environment and if the run initialized, redo clicking the run botton
- This will automatically open a python terminal and runs the python file. 

When the 'generate_inputs.py' runs, it asks some option to choose.  
- Example answers are
   - Geometry: 'Cylinder'
   - Adding sensors: 'N'
   - Ending number: '128' 

This will create 128 input files of cylinder cases based on the categorized simulations.
Verify that all input file folders have been created within the Test directory.

## 6-2. Run resume simulations - Submit multiple sbatch jobs
```bash
bash submit_all_jobs.sh
```

> You can modify simulation submission settings (e.g., node count, walltime) by editing the `.sh` file directly.

---

## 7. Check Simulation Status

- **Check the queue:** `squeue -u [TACCID]`

The following files are configured in the .sh file.  
- **Check logs while running:** `[TACCID]/tmp/logs/[Date]/[job_name]/claymore.out`  
- **Check errors if job fails:** `[TACCID]/tmp/logs/[Date]/[job_name]/claymore.err`
- **Check GPUs usage in every 30 min while running:** `[TACCID]/tmp/logs/[Date]/[job_name]/gpu_usage.log`

---

## 8. Visualize Results

*(Instructions coming soon)*

---

## Q&A

1. **Troubleshooting during compilation**
2. **How to edit numerical settings**
3. **How to change simulation conditions**
4. **How to run a draft simulation faster than waiting for the sbatch queue**
5. **Any other comments**
   Even though the .sh file is designed to run on 3 GPUs, TACC sometimes offers 2 GPU nodes, which results in a simulation failure. You can see this happen if you check the "gpu_usage.log" file in Step 7. This issue could not be resolved; you will likely need to resubmit the .sh file for the simulation.    
