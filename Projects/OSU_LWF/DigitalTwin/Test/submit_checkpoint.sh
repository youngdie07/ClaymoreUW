#!/bin/bash
#
# submit_checkpoint_v2.sh — checkpoint.json 단일 작업 제출 (경로/SLURM 소프트 코딩)
# submit_all_jobs_v2.sh 와 동일한 환경변수 패턴
#
#   export CLAYMORE_EXEC=/path/to/osu_lwf
#   export CLAYMORE_LOG_ROOT=$SCRATCH/tmp/logs
#   export CLAYMORE_MAIL_USER=you@utexas.edu
#   export CLAYMORE_SLURM_ACCOUNT=Your-Allocation
#   export CLAYMORE_PARTITION=gpu-a100
#   export CLAYMORE_CHECKPOINT_JSON=cp/checkpoint.json   # 스크립트 디렉 기준 상대 또는 절대경로
#   export CLAYMORE_CHECKPOINT_JOB_NAME=cp_checkpoint
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ---------------------------------------------------------------------------
OSU_LWF_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EXEC_FILE="${CLAYMORE_EXEC:-$OSU_LWF_ROOT/osu_lwf}"
LOG_ROOT="${CLAYMORE_LOG_ROOT:-${SCRATCH:-$HOME}/tmp/logs}"
MAIL_USER="${CLAYMORE_MAIL_USER:-youngchulchoi@utexas.edu}"
SLURM_ALLOC="${CLAYMORE_SLURM_ACCOUNT:-DS-Jun-Whan-Lee}"
SLURM_PARTITION="${CLAYMORE_PARTITION:-gpu-a100}"
JOB_NAME="${CLAYMORE_CHECKPOINT_JOB_NAME:-cp_checkpoint}"

CKPT_REL="${CLAYMORE_CHECKPOINT_JSON:-cp/checkpoint.json}"
if [[ "$CKPT_REL" = /* ]]; then
    CHECKPOINT_JSON="$CKPT_REL"
else
    CHECKPOINT_JSON="$SCRIPT_DIR/$CKPT_REL"
fi

if [ ! -f "$CHECKPOINT_JSON" ]; then
    echo "❌ checkpoint.json not found: $CHECKPOINT_JSON"
    exit 1
fi

echo "📁 Checkpoint JSON: $CHECKPOINT_JSON"
echo "⚙️  Using (override with env: CLAYMORE_EXEC, CLAYMORE_LOG_ROOT, CLAYMORE_MAIL_USER, …):"
echo "    EXEC_FILE=$EXEC_FILE"
echo "    LOG_ROOT=$LOG_ROOT"
echo "    MAIL_USER=$MAIL_USER"
echo "    SLURM_ACCOUNT=$SLURM_ALLOC  PARTITION=$SLURM_PARTITION"
echo "    JOB_NAME=$JOB_NAME"
echo ""
echo "🚀 Submitting single job for checkpoint..."
read -p "Continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "❌ Job submission cancelled."
    exit 0
fi

sbatch << EOF
#!/bin/bash
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -J $JOB_NAME
#SBATCH -p $SLURM_PARTITION
#SBATCH -t 48:00:00
#SBATCH --mail-user=$MAIL_USER
#SBATCH --mail-type=ALL
#SBATCH -A $SLURM_ALLOC
#SBATCH --output=/dev/null
#SBATCH --error=/dev/null

TODAY=\$(date +"%m%d%Y")
LOG_BASE="$LOG_ROOT/\$TODAY/\$SLURM_JOB_ID/$JOB_NAME"

EXEC_FILE="$EXEC_FILE"
JSON_FILE="$CHECKPOINT_JSON"

mkdir -p \$LOG_BASE
exec > \$LOG_BASE/claymore.out 2> \$LOG_BASE/claymore.err

module load cuda/12.2
module load gcc/12.2.0

if [ ! -f "\$EXEC_FILE" ]; then
  echo "Error: Executable not found at \$EXEC_FILE"
  exit 1
fi

if [ ! -f "\$JSON_FILE" ]; then
  echo "Error: JSON input not found at \$JSON_FILE"
  exit 1
fi

echo "SLURM Job ID: \$SLURM_JOB_ID"
echo "Working Directory: \$(pwd)"
echo "JSON File: \$JSON_FILE"
nvidia-smi

(
    while true; do
        echo "=== nvidia-smi at \$(date) ===" >> \$LOG_BASE/gpu_usage.log
        nvidia-smi >> \$LOG_BASE/gpu_usage.log
        sleep 3600
    done
) &
GPU_LOGGER_PID=\$!

cd "\$(dirname "\$JSON_FILE")"
CUDA_VISIBLE_DEVICES=0,1,2 ibrun -n 1 \$EXEC_FILE -f "\$(basename "\$JSON_FILE")" &
SIM_PID=\$!

(
    while true; do
        if find "\$LOG_BASE/claymore.out" -mmin +30 | grep -q claymore.out; then
            echo "⚠️ Log file not updated for 30 minutes. Assuming simulation is stuck." | \\
            mail -s "⚠️ [JobID: \$SLURM_JOB_ID] $JOB_NAME Stuck" $MAIL_USER

            kill \$SIM_PID 2>/dev/null
            scancel \$SLURM_JOB_ID
            break
        fi
        sleep 1800
    done
) &
WATCHDOG_PID=\$!

wait \$SIM_PID
RUN_STATUS=\$?

kill \$GPU_LOGGER_PID 2>/dev/null
kill \$WATCHDOG_PID 2>/dev/null

if [ \$RUN_STATUS -eq 0 ]; then
    echo "✅ Claymore Simulation (checkpoint) completed successfully at \$(date)" | mail -s "✅ [JobID: \$SLURM_JOB_ID] $JOB_NAME Success" $MAIL_USER
else
    echo "❌ Claymore Simulation (checkpoint) FAILED at \$(date). See attached error log." | mail -s "❌ [JobID: \$SLURM_JOB_ID] $JOB_NAME Error" -a \$LOG_BASE/claymore.err $MAIL_USER
fi
EOF

echo "✅ Job submitted for checkpoint.json"
echo "📊 Check job status with: squeue -u \$USER"
