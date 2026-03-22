#!/bin/bash
#
# submit_all_jobs_env.sh — 경로/SLURM을 환경변수·$SCRATCH·스크립트 위치로 설정하는 버전
# (submit_all_jobs.sh 에 적용했던 소프트 코딩 로직과 동일)
#

# 스크립트가 있는 디렉토리로 이동
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ---------------------------------------------------------------------------
# 경로/SLURM 설정 — 하드코딩 대신 기본값 + 환경변수 오버라이드
#   export CLAYMORE_EXEC=/path/to/osu_lwf
#   export CLAYMORE_LOG_ROOT=$SCRATCH/tmp/logs   # TACC: SCRATCH 자동 설정됨
#   export CLAYMORE_MAIL_USER=you@utexas.edu
#   export CLAYMORE_SLURM_ACCOUNT=Your-Allocation
#   export CLAYMORE_PARTITION=gpu-a100
# ---------------------------------------------------------------------------
OSU_LWF_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EXEC_FILE="${CLAYMORE_EXEC:-$OSU_LWF_ROOT/osu_lwf}"
# 로그 루트: LS6 등에서는 $SCRATCH 권장; 없으면 $HOME/tmp/logs
LOG_ROOT="${CLAYMORE_LOG_ROOT:-${SCRATCH:-$HOME}/tmp/logs}"
MAIL_USER="${CLAYMORE_MAIL_USER:-youngchulchoi@utexas.edu}"
SLURM_ALLOC="${CLAYMORE_SLURM_ACCOUNT:-DS-Jun-Whan-Lee}"
SLURM_PARTITION="${CLAYMORE_PARTITION:-gpu-a100}"

# 사용자로부터 시작 번호와 끝 번호 입력 받기
echo "📁 Available folders:"
echo "in_* folders:"
ls -d in_* 2>/dev/null | sort -V || echo "No in_* folders found"
echo "cyl_in_* folders:"
ls -d cyl_in_* 2>/dev/null | sort -V || echo "No cyl_in_* folders found"

echo ""
read -p "Enter folder prefix (in_ or cyl_in_, or press Enter for 'in_'): " folder_prefix
if [[ -z "$folder_prefix" ]]; then
    folder_prefix="in_"
fi

read -p "Enter starting number (e.g., 1 for ${folder_prefix}001): " start_num
read -p "Enter ending number (e.g., 10 for ${folder_prefix}010, or press Enter for all): " end_num

# 입력값 검증
if [[ "$folder_prefix" != "in_" ]] && [[ "$folder_prefix" != "cyl_in_" ]]; then
    echo "❌ Invalid folder prefix! Must be 'in_' or 'cyl_in_'"
    exit 1
fi

if ! [[ "$start_num" =~ ^[0-9]+$ ]]; then
    echo "❌ Invalid starting number!"
    exit 1
fi

if [[ -n "$end_num" ]] && ! [[ "$end_num" =~ ^[0-9]+$ ]]; then
    echo "❌ Invalid ending number!"
    exit 1
fi

# 시작/끝 폴더명 생성
start_folder="${folder_prefix}$(printf "%03d" $start_num)"
if [[ -n "$end_num" ]]; then
    end_folder="${folder_prefix}$(printf "%03d" $end_num)"
    echo "🚀 Will submit jobs from $start_folder to $end_folder"
else
    echo "🚀 Will submit jobs from $start_folder onwards"
fi

# 제출할 폴더 목록 생성
folders_to_submit=()
for folder in ${folder_prefix}*; do
    if [ -d "$folder" ]; then
        folder_num=$(echo "$folder" | sed "s/${folder_prefix}//" | sed 's/^0*//')
        if [[ "$folder_num" -ge "$start_num" ]]; then
            if [[ -z "$end_num" ]] || [[ "$folder_num" -le "$end_num" ]]; then
                folders_to_submit+=("$folder")
            fi
        fi
    fi
done

if [ ${#folders_to_submit[@]} -eq 0 ]; then
    echo "❌ No folders found in the specified range!"
    exit 1
fi

echo "📋 Found ${#folders_to_submit[@]} folders to submit:"
printf '%s\n' "${folders_to_submit[@]}"
echo ""

echo "⚙️  Using (override with env: CLAYMORE_EXEC, CLAYMORE_LOG_ROOT, CLAYMORE_MAIL_USER, …):"
echo "    EXEC_FILE=$EXEC_FILE"
echo "    LOG_ROOT=$LOG_ROOT"
echo "    MAIL_USER=$MAIL_USER"
echo "    SLURM_ACCOUNT=$SLURM_ALLOC  PARTITION=$SLURM_PARTITION"
echo ""

# 확인 메시지
read -p "Continue with job submission? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "❌ Job submission cancelled."
    exit 0
fi

# 모든 폴더에 대해 SLURM 작업 제출
for folder in "${folders_to_submit[@]}"; do
    json_file="$folder/$folder.json"
    
    if [ -f "$json_file" ]; then
        echo "🚀 Submitting job for $folder..."
        
        # SLURM 작업 제출 (간단한 방식)
        sbatch << EOF
#!/bin/bash
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -J $folder
#SBATCH -p $SLURM_PARTITION
#SBATCH -t 48:00:00
#SBATCH --mail-user=$MAIL_USER
#SBATCH --mail-type=ALL
#SBATCH -A $SLURM_ALLOC
#SBATCH --output=/dev/null
#SBATCH --error=/dev/null

# 날짜 변수 설정
TODAY=\$(date +"%m%d%Y")
LOG_BASE="$LOG_ROOT/\$TODAY/\$SLURM_JOB_ID/$folder"

# 실행파일/JSON 파일 절대경로 설정
EXEC_FILE="$EXEC_FILE"
JSON_FILE="\$(pwd)/$json_file"

# 필요한 디렉토리 생성
mkdir -p \$LOG_BASE

# 표준 출력, 에러 리디렉션 설정
exec > \$LOG_BASE/claymore.out 2> \$LOG_BASE/claymore.err

# 모듈 로드
module load cuda/12.2
module load gcc/12.2.0

# 실행파일/입력파일 존재 확인
if [ ! -f "\$EXEC_FILE" ]; then
  echo "Error: Executable not found at \$EXEC_FILE"
  exit 1
fi

if [ ! -f "\$JSON_FILE" ]; then
  echo "Error: JSON input not found at \$JSON_FILE"
  exit 1
fi

# 환경 정보 출력
echo "SLURM Job ID: \$SLURM_JOB_ID"
echo "Working Directory: \$(pwd)"
echo "JSON File: \$JSON_FILE"
nvidia-smi

# GPU 사용량 로깅 (1시간 간격 무한루프)
(
    while true; do
        echo "=== nvidia-smi at \$(date) ===" >> \$LOG_BASE/gpu_usage.log
        nvidia-smi >> \$LOG_BASE/gpu_usage.log
        sleep 3600
    done
) &
GPU_LOGGER_PID=\$!

# --- 시뮬레이션 실행 ---
cd "\$(dirname "\$JSON_FILE")"
CUDA_VISIBLE_DEVICES=0,1,2 ibrun -n 1 \$EXEC_FILE -f "\$(basename "\$JSON_FILE")" &
SIM_PID=\$!

# --- watchdog은 시뮬레이션 시작 후에 감시 ---
(
    while true; do
        if find "\$LOG_BASE/claymore.out" -mmin +30 | grep -q claymore.out; then
            echo "⚠️ Log file not updated for 30 minutes. Assuming simulation is stuck." | \\
            mail -s "⚠️ [JobID: \$SLURM_JOB_ID] $folder Stuck" $MAIL_USER

            kill \$SIM_PID
            scancel \$SLURM_JOB_ID
            break
        fi
        sleep 1800  # 30분 주기 체크
    done
) &
WATCHDOG_PID=\$!

# 시뮬레이션 기다리기
wait \$SIM_PID
RUN_STATUS=\$?

# 시뮬레이션 끝나면 백그라운드 프로세스 정리
kill \$GPU_LOGGER_PID
kill \$WATCHDOG_PID

# 성공/실패 결과에 따라 메일 전송
if [ \$RUN_STATUS -eq 0 ]; then
    echo "✅ Claymore Simulation completed successfully at \$(date)" | mail -s "✅ [JobID: \$SLURM_JOB_ID] $folder Success" $MAIL_USER
else
    echo "❌ Claymore Simulation FAILED at \$(date). See attached error log." | mail -s "❌ [JobID: \$SLURM_JOB_ID] $folder Error" -a \$LOG_BASE/claymore.err $MAIL_USER
fi
EOF
        
        echo "✅ Job submitted for $folder"
    else
        echo "⚠️  JSON file not found: $json_file"
    fi
done

echo "🎉 All jobs submitted!"
echo "📊 Check job status with: squeue -u \$USER"
