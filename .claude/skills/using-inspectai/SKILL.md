---
name: using-inspectai
description: Guidance and reference material for working with Inspect AI, an open-source framework for LLM evaluations. Use when writing tasks, solvers, scorers, datasets, or running evaluations with Inspect AI.
---

# Using Inspect AI

This skill provides guidance and reference material for working with Inspect AI, an open-source framework for LLM evaluations.

## Available References

You have access to the following local documentation (read on-demand as needed):

- **Inspect AI source code**: `./inspect-ai-repo/` - Full cloned repository
- **Official documentation**: `./official-docs/` - Downloaded documentation files

Use these references when you need to:
- Understand specific APIs or function signatures
- See implementation patterns and examples
- Debug issues or understand internal behavior
- Find the correct way to implement tasks, solvers, scorers, etc.

## Quick Reference

### Core Concepts

- **Tasks**: Define what to evaluate (dataset + solver + scorer)
- **Solvers**: Define how the model approaches the task (chain of operations)
- **Scorers**: Define how to evaluate the model's output
- **Datasets**: Input samples to evaluate on
- **Tools**: Functions the model can call during evaluation

### Common Patterns

```python
from inspect_ai import Task, task
from inspect_ai.dataset import json_dataset
from inspect_ai.scorer import model_graded_fact
from inspect_ai.solver import generate, system_message

@task
def my_eval():
    return Task(
        dataset=json_dataset("data.json"),
        solver=[
            system_message("You are a helpful assistant."),
            generate(),
        ],
        scorer=model_graded_fact(),
    )
```

### Running Evaluations

```bash
# Run a task
inspect eval my_task.py

# Run with specific model
inspect eval my_task.py --model openai/gpt-4

# View results
inspect view
```

## When Exploring the Codebase

When you need deeper understanding:

1. **For API questions**: Check `./docs/inspect-ai-repo/src/inspect_ai/`
2. **For examples**: Check `./docs/inspect-ai-repo/examples/`
3. **For official docs**: Check `./docs/official-docs/`

Prefer reading the source code directly when documentation is unclear or when you need to understand exact behavior.
