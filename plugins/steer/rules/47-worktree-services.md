<!-- steer:inject-when=has-compose -->
### Worktree services

Start services only via `mise run ...`, never a bare `docker compose up` or a
hardcoded port, so each worktree keeps its own stack and ports. Clean up with
`mise run docker:clean` before a worktree goes away.
