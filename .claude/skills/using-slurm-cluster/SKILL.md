---
name: using-slurm-cluster
description: Reference for submitting and managing GPU training jobs on the RunPod shared Slurm cluster. Use when writing sbatch scripts, managing Slurm jobs, configuring GPU resources, or troubleshooting cluster issues.
---

# Using the RunPod Slurm Cluster

This skill provides reference for submitting and managing GPU training jobs on the RunPod shared Slurm cluster.

## User Context

- SSH alias for the cluster is configured in `~/.ssh/config` (user-specific alias name)
- Username on cluster: `vassilisp`
- Cluster base paths use `$(whoami)` or `${USER}` which resolve to the username
- The user codes remotely via VSCode SSH — all files are on the remote server
- The user uses `uv` exclusively for Python package management

---

## Cluster Architecture

### Nodes

| Nodes | Role | Notes |
|-------|------|-------|
| node-0 | Controller/login (SSH entry) | **NEVER run jobs here** |
| node-1 | Controller | Avoid resource-intensive work |
| node-2–22 | Compute (GPUs) | Available for jobs (14–15 are `dev` partition) |

**Mandatory exclude for ALL jobs:**
```
#SBATCH --exclude=node-[0-1]
```

### Partitions

| Partition | Nodes | Purpose |
|-----------|-------|---------|
| `general` | 1–13 | Production batch jobs |
| `dev` | 14–15 | Interactive debugging |
| `overflow` | All | Flexible placement |

### QoS (Quality of Service)

Only TWO QoS levels for batch jobs: `high` and `low`. `dev` is for interactive `srun` ONLY.

| QoS | Priority | GPU Quota | Preemption | Use For |
|-----|----------|-----------|------------|---------|
| `high` | 200 | ~12–15 GPUs/user | Won't be preempted | Single important experiments |
| `low` | 100 | **No limit** | Can be preempted | Sweeps, batch jobs |
| `dev` | 300 | Varies | Won't be preempted | **Interactive `srun` ONLY** |

**CRITICAL — QOSMaxGRESPerUser:** The `high` QoS has a per-user GPU limit (~12–15). If you hit it, jobs block with reason `QOSMaxGRESPerUser`. Your OWN running high-priority jobs are blocking you. Fix: use `--qos=low` or cancel a running high job.

Check exact quota: `sacctmgr show qos format=name,MaxTRESPerUser%30`

---

## Two-Tier Storage

| Filesystem | Capacity | Speed | Use For |
|------------|----------|-------|---------|
| `/workspace/` | 73TB | Slower (NFS) | Temporary training checkpoints |
| `/workspace-vast/` | 10TB | Fast (NVMe) | Final models, results, code, envs |

### Directory Layout

```
/workspace-vast/<user>/
├── git/            # Code repositories
├── envs/           # Python virtual environments (uv venvs)
├── data/           # Training data
└── exp/
    ├── logs/       # Job stdout/stderr (%x_%j.out)
    ├── models/     # Final trained models (~60GB each)
    ├── results/    # Evaluation outputs (JSON, small)
    ├── jobs/       # Job scripts
    └── configs/    # Generated configs

/workspace/<user>/
└── exp/
    └── training/   # Active training checkpoints (400–450GB each!)
```

### Storage Math

- DeepSpeed ZeRO-3 checkpoint: ~428GB (model shards ~65GB + optimizer ~360GB)
- During training: 2 checkpoints = ~856GB per experiment
- Final merged model: ~60GB
- Results JSON: ~2KB

---

## Environment Setup (One-Time)

```bash
# Create directory structure
ssh CLUSTER "mkdir -p /workspace-vast/\$(whoami)/{git,envs,data} && \
  mkdir -p /workspace-vast/\$(whoami)/exp/{logs,models,results,jobs,configs} && \
  mkdir -p /workspace/\$(whoami)/exp/training"

# Environment variables (add to ~/.bashrc on cluster)
export HF_HOME=/workspace-vast/pretrained_ckpts
export WORKSPACE=/workspace-vast/$(whoami)

# Create Python venv
ssh CLUSTER "cd /workspace-vast/\$(whoami)/envs && \
  uv venv training-env --python 3.11 && \
  source training-env/bin/activate && \
  uv pip install torch transformers accelerate deepspeed wandb"
```

### Required Environment Variables in Job Scripts

```bash
# NCCL networking fix (MANDATORY for multi-GPU jobs)
export NCCL_SOCKET_IFNAME="=vxlan0"
export NCCL_NVLS_ENABLE=0
export PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True"

# Model/data access
export HF_HOME=/workspace-vast/pretrained_ckpts
# export HUGGING_FACE_TOKEN="..."   # For gated models
# export WANDB_API_KEY="..."        # For experiment tracking
```

---

## Job Submission

### Batch Job Template (sbatch)

```bash
#!/bin/bash
#SBATCH --job-name=<EXPERIMENT_NAME>
#SBATCH --partition=general,overflow
#SBATCH --qos=high                              # or low for sweeps
#SBATCH --gres=gpu:5                            # Number of GPUs
#SBATCH --cpus-per-task=40
#SBATCH --mem=200G
#SBATCH --time=10:00:00
#SBATCH --signal=B:SIGTERM@900                  # 15 min grace for checkpoint save
#SBATCH --output=/workspace-vast/%u/exp/logs/%x_%j.out
#SBATCH --mail-user=your@email.com
#SBATCH --mail-type=FAIL,REQUEUE
#SBATCH --exclude=node-[0-1]

source /workspace-vast/${USER}/envs/training-env/bin/activate
export HF_HOME=/workspace-vast/pretrained_ckpts
export NCCL_SOCKET_IFNAME="=vxlan0"
export NCCL_NVLS_ENABLE=0
export PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True"

# Training on /workspace/ (temporary, large)
TRAINING_DIR="/workspace/${USER}/exp/training/<EXPERIMENT_NAME>"
# Final output on /workspace-vast/ (permanent, fast)
MODEL_DIR="/workspace-vast/${USER}/exp/models/<EXPERIMENT_NAME>"
RESULTS_DIR="/workspace-vast/${USER}/exp/results"

mkdir -p "${TRAINING_DIR}" "${MODEL_DIR}" "${RESULTS_DIR}"

# Phase 1: Train
accelerate launch --num_processes 5 train.py \
    --model "Qwen/Qwen3-32B" \
    --output "${TRAINING_DIR}" \
    ...

# Phase 2: Copy model to permanent storage
rm -rf "${TRAINING_DIR}"/checkpoint-*/
rsync -a "${TRAINING_DIR}/" "${MODEL_DIR}/"

# Phase 3: Evaluate
python evaluate.py --model-dir "${MODEL_DIR}" --output-dir "${RESULTS_DIR}"

# Phase 4: Cleanup
rm -rf "${TRAINING_DIR}"
```

**Submit:** `sbatch job_script.sh`

### Slurm Placeholder Variables

| Variable | Context | Expands To |
|----------|---------|------------|
| `%u` | `#SBATCH` directives ONLY | Username |
| `%j` | `#SBATCH` directives ONLY | Job ID |
| `%x` | `#SBATCH` directives ONLY | Job name |
| `${USER}` | Inside shell script body | Username |
| `$(whoami)` | Interactive shell commands | Username |

**Common mistake:** Using `%u` outside `#SBATCH` lines creates a literal `%u` directory!

### Interactive Session (srun)

```bash
srun -p dev,overflow --qos=dev --cpus-per-task=8 --gres=gpu:1 \
     --mem=32G --time=4:00:00 --job-name=D_${USER} --pty bash
```

Recommended alias: `alias sint="srun -p dev,overflow --qos=dev --cpus-per-task=8 --gres=gpu:1 --mem=32G --time=4:00:00 --job-name=D_\${USER} --pty bash"`

- **`D_` prefix = auto-deleted at midnight PT** (ALWAYS use for interactive jobs)
- `dev` QoS is for `srun` ONLY — cannot use with `sbatch`
- Max ~4 hours, 1–2 GPUs

---

## GPU Requirements by Model Size

| Model | Params | GPUs (Inference) | GPUs (Fine-tune) | Mem/GPU |
|-------|--------|------------------|-------------------|---------|
| 7–8B | 7–8B | 1 | 1 | ~40GB |
| 14B | 14B | 1 | 2 | ~60GB |
| 30B MoE | 30B (3B active) | 2 | 4 | ~60GB |
| 32B | 32B | 2 | 5 | ~60GB |
| 70B | 70B | 4 | 8+ | ~70GB |

**Rule of thumb:** Fine-tuning needs 1.5–2x more GPUs than inference.

**Effective Batch Size** = `batch_size * gradient_accumulation_steps * num_gpus`

---

## Monitoring & Management

### Queue Commands

```bash
squeue -u $(whoami)                          # Your jobs
squeue                                       # All jobs
watch -n 2 'squeue -u $(whoami)'             # Live updates

# Formatted output
squeue -u $(whoami) -o "%.10i %.25j %.8T %.10M %.6D %R %b"
```

### Job States

| Code | Name | Meaning |
|------|------|---------|
| `PD` | PENDING | Waiting for resources |
| `R` | RUNNING | Executing |
| `CG` | COMPLETING | Finishing up |
| `CD` | COMPLETED | Done (disappears from squeue) |
| `F` | FAILED | Crashed (disappears from squeue) |

### Job Details & History

```bash
scontrol show job <JOB_ID>                   # Full details
scontrol show job <JOB_ID> | grep Reason     # Why pending
sacct -u $(whoami) --starttime=today --format=JobID,JobName,Elapsed,State,ExitCode
```

### Log Monitoring

```bash
# Tail live output
tail -f /workspace-vast/$(whoami)/exp/logs/<name>_<jobid>.out

# Find latest log by experiment name
ls -t /workspace-vast/$(whoami)/exp/logs/*<name>*.out | head -1

# Search for errors
grep -i 'error\|fail\|exception' /workspace-vast/$(whoami)/exp/logs/*.out
```

### Canceling Jobs

```bash
scancel <JOB_ID>                             # Specific job
scancel --name <NAME>                        # By name
scancel -u $(whoami)                         # ALL your jobs
# Cancel pattern (e.g., all sweep jobs):
squeue -u $(whoami) -o "%i %j" --noheader | grep "sweep_" | awk '{print $1}' | xargs scancel
```

### Useful Aliases (for ~/.bashrc on cluster)

```bash
alias q='squeue -o "%.18i %.9P %.8j %.8u %.2t %.10M %.6D %N %.10b"'
alias qq='squeue -u $(whoami) -o "%.18i %.9P %.8j %.8u %.2t %.10M %.6D %N %.10b"'
alias qw='watch -n 2 squeue -u $(whoami)'
alias qdel='scancel'
alias qclear='scancel -u $(whoami)'
alias sint="srun -p dev,overflow --qos=dev --cpus-per-task=8 --gres=gpu:1 --mem=32G --time=4:00:00 --job-name=D_\${USER} --pty bash"
```

---

## Hyperparameter Sweeps

A sweep = submitting many single jobs with different hyperparameters. No magic.

### Strategy

- Use `--qos=low` for most sweep jobs (bypasses ~12–15 GPU quota on `high`)
- Optional: mix 25% `high` + 75% `low`
- Use `--qos=low` because: no quota limit, can run many concurrent jobs
- Downside of `low`: can be preempted (job re-queued automatically)

### Naming Convention

Encode hyperparams in job name: `{lr}_eb{batch}_wd{decay}_wr{warmup}`
Example: `2em05_eb40_wd0p05_wr0p1`

### Monitoring Sweep Progress

```bash
# Count completed results
ls /workspace-vast/$(whoami)/exp/sweep_results/*.json 2>/dev/null | wc -l

# Running/pending jobs
squeue -u $(whoami) | grep sweep_ | wc -l
```

---

## Evaluation-Only Jobs

Much lighter than training — typically 1 GPU, <2 hours.

```bash
#SBATCH --qos=high            # High priority OK (fast, 1 GPU)
#SBATCH --gres=gpu:1
#SBATCH --mem=100G
#SBATCH --time=02:00:00
```

---

## Troubleshooting Quick Reference

### PENDING Jobs

| Reason | Meaning | Fix |
|--------|---------|-----|
| `QOSMaxGRESPerUser` | Hit GPU quota | Use `--qos=low` or cancel a high job |
| `Resources` | No free GPUs | Wait or reduce GPU count |
| `Priority` | Other jobs ahead | Wait |
| `ReqNodeNotAvail` | Node unavailable | Check exclude list |

### Common Failures

| Error | Cause | Fix |
|-------|-------|-----|
| `NCCL Bootstrap: no socket interface` | Missing NCCL env var | Add `NCCL_SOCKET_IFNAME="=vxlan0"` |
| `Permission denied: /workspace/` | Bad node | Check `sinfo -N -l` and exclude the problematic node |
| `CUDA out of memory` | Batch too large / not enough GPUs | Reduce batch size or request more GPUs |
| `ModuleNotFoundError` | Env not activated | Check `source` line in job script |
| YAML `2e-05` parsed as string | YAML type coercion | Use `float(config["learning_rate"])` in Python |
| Incomplete checkpoint (no `trainer_state.json`) | Job killed mid-save | Increase `--signal=B:SIGTERM@900` and `--time` |
| Package API errors | Version conflicts | Install ALL packages at once, never individually |

### SIGTERM Warning Times

| Scenario | Warning | Controlled By |
|----------|---------|---------------|
| Preemption (high-priority needs GPU) | ~3 min | Cluster config (not changeable) |
| Time limit (`--time` exceeded) | Your `@N` value | `#SBATCH --signal=B:SIGTERM@900` |

---

## Storage Cleanup

**Safety rules:** Always check `squeue` first. Never delete dirs for running jobs. Verify timestamps.

```bash
# Check usage
du -sh /workspace-vast/$(whoami)/exp/* | sort -hr
du -sh /workspace/$(whoami)/exp/* | sort -hr

# Safe to delete: training dirs for completed jobs (results JSON exists)
for d in /workspace/$(whoami)/exp/training/*/; do
    name=$(basename "$d")
    if [ -f "/workspace-vast/$(whoami)/exp/results/${name}.json" ]; then
        echo "SAFE: $name ($(du -sh "$d" | cut -f1))"
    fi
done
```

---

## Code Sync & Development

### Rsync (recommended)

```bash
# Upload code (from local)
rsync -avzP ./project/ CLUSTER:/workspace-vast/$(whoami)/git/project/

# Download results
rsync -avzP CLUSTER:/workspace-vast/$(whoami)/exp/results/ ./results/
```

### Editable Install (for active development)

```bash
ssh CLUSTER "source /workspace-vast/\$(whoami)/envs/training-env/bin/activate && \
  cd /workspace-vast/\$(whoami)/git/project && uv pip install -e ."
```

---

## Best Practices

- **ALWAYS** use `D_username` prefix for interactive jobs (auto-deleted at midnight PT)
- **ALWAYS** exclude node-[0-1] (controllers) in job scripts
- **ALWAYS** set NCCL env vars for multi-GPU jobs
- **NEVER** manually set `CUDA_VISIBLE_DEVICES` (Slurm handles this)
- **NEVER** use `--qos=dev` with `sbatch` (dev is for `srun` only)
- **Test with 1–2 jobs** before launching large sweeps
- **Use `--qos=low`** for sweeps to avoid self-blocking on GPU quota
- **Clean up** `/workspace/` training dirs after jobs complete
- **Don't upgrade packages individually** — install all at once to avoid version conflicts
- **Check coordination channels** before launching large sweeps
