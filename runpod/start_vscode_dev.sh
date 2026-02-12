#!/bin/bash
# Complete dev environment startup script with SLURM resource configuration

# Default values for SLURM resources
GPUS=1
CPUS=8
MEM="32G"
TIME="08:00:00"

# Parse command-line arguments
while getopts "g:c:m:t:h" opt; do
    case $opt in
        g) GPUS="$OPTARG" ;;
        c) CPUS="$OPTARG" ;;
        m) MEM="$OPTARG" ;;
        t) TIME="$OPTARG" ;;
        h)
            echo "Usage: $0 [-g gpus] [-c cpus] [-m mem] [-t time]"
            echo "Starts a SLURM dev job and configures VSCode for debugging."
            echo ""
            echo "Options:"
            echo "  -g <num>     Number of GPUs (default: 1)"
            echo "  -c <num>     Number of CPUs (default: 8)"
            echo "  -m <size>    Memory allocation (default: 32G)"
            echo "  -t <time>    Time allocation (default: 08:00:00)"
            echo "  -h           Show this help message"
            echo ""
            echo "Example: $0 -g 2 -c 16 -m 64G -t 12:00:00"
            echo ""
            echo "Quick reference:"
            echo "  • Attach to tmux: tmux attach -t pydev"
            echo "  • Detach: Ctrl+b, then d"
            echo "  • Kill: tmux kill-session -t pydev"
            exit 0
            ;;
        *)
            echo "Invalid option. Use -h for help"
            exit 1
            ;;
    esac
done

echo "=== Starting Development Environment ==="
echo ""

# Step 1: Start srun session
echo "Step 1: Starting srun session..."
if tmux has-session -t pydev 2>/dev/null; then
    echo "✓ Session 'pydev' already running"
else
    echo "Starting new session with: ${GPUS} GPU(s), ${CPUS} CPU(s), ${MEM} memory, ${TIME} time limit"
    echo ""

    # Create a new tmux session and run the srun command inside it
    tmux new-session -s pydev -d "srun -p dev,overflow \
         --qos=dev \
         --cpus-per-task=${CPUS} \
         --gres=gpu:${GPUS} \
         --mem=${MEM} \
         --time=${TIME} \
         --job-name=D_${USER} \
         --pty zsh -c '
# Activate the uv venv

# Print environment info
echo \"================================================\"
echo \"Dev session started!\"
echo \"================================================\"
echo \"Node: \$(hostname)\"
echo \"GPUs available: \$CUDA_VISIBLE_DEVICES\"
echo \"Working directory: \$(pwd)\"
echo \"Python: \$(which python)\"
echo \"================================================\"
echo \"\"

# Start an interactive zsh with venv activated
cd /workspace-vast/${USER}
exec zsh
'"

    echo "✓ Dev session started in tmux session 'pydev'"
    echo ""
    echo "⏳ Waiting for srun allocation (this takes ~1 minute)..."
    sleep 5
fi

# Step 2: Copy .vscode config to current directory if not present
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Step 2: Syncing .vscode/ config to $(pwd)..."
mkdir -p .vscode
cp -n "${SCRIPT_DIR}"/.vscode/* .vscode/
echo "✓ .vscode/ is up to date (existing files preserved)"

# Step 3: Detect compute node and update VSCode config
echo ""
echo "Step 3: Detecting compute node and updating VSCode config..."
sleep 2  # Give srun time to print node info

COMPUTE_NODE=$(tmux capture-pane -t pydev -p 2>/dev/null | grep -oP 'node-\d+' | head -1)

if [ -z "$COMPUTE_NODE" ]; then
    echo "⚠️  Could not detect compute node yet."
    echo "   The session may still be starting up."
    echo "   Check status with: tmux attach -t pyde and rerun script."
else
    # Update launch.json with the detected node (in current directory)
    sed -i "s/\"host\": \"node-[0-9]\+\"/\"host\": \"$COMPUTE_NODE\"/g" .vscode/launch.json
    echo "✓ VSCode configured for: $COMPUTE_NODE"
    echo ""
    echo "=== Setup Complete! ==="
    echo "Quick reference:"
    echo "  • Attach to tmux: tmux attach -t pydev"
    echo "  • Run current file: Ctrl+Shift+B with tmux session active"
    echo "  • Debug with breakpoints: F5"
    echo "  • End session: tmux kill-session -t pydev"
fi

echo ""
