# AI Orchestration Overview

This section describes how to use AI in the repository for planning, documentation, and task refinement.

## Approaches

- **Island-Driven Workflow**
  - a simpler, repo-aligned approach for splitting work by island
  - best when you want to start rough and refine documentation and implementation tasks step by step

- **Supply Chain Workflow Prompt**
  - a ready-to-use, end-to-end agent prompt that walks through the full coffee supply chain (Farm → Factory → Distributor → Coffee House) in one session
  - covers ERPNext, Node-RED, Hyperledger Fabric, Dobot robots, TurtleBot4, VROOM, InfluxDB, and the Coffee House Traceability Display
  - best when you want an agent to execute or document the complete workflow rather than a single island

## Recommended path for this repo

1. Start with the **Island-Driven Workflow** to understand individual islands.
2. Use the **Supply Chain Workflow Prompt** to run or document the end-to-end flow.
3. Refine each island incrementally and verify the concept step by step.

## Links

- [Island-Driven Workflow](island-driven-workflow.md)
- [Supply Chain Workflow Prompt](supply-chain-workflow-prompt.md)
