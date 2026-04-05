# AGENTS.md

## Project purpose
SeaTurtleOS is the platform and device runtime for a browser-first marine appliance.

## Rules
- Prefer simple, production-oriented solutions.
- Keep services containerized.
- Assume local-network-first operation.
- Prioritize reliability, persistence, and clean recovery after power loss.
- Avoid unnecessary abstraction.
- Document architecture decisions in `docs/adr/`.
- Do not add GUI-first desktop dependencies unless explicitly required.
- Favor Docker Compose for early orchestration.
