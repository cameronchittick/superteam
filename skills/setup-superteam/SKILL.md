---
name: setup-superteam
description: Use when your human partner asks to enable agent teams / task tools for superteam - merges the two env entries into ~/.claude/settings.json and shows the diff
---

# Enabling team mode

Team mode needs two env vars that a plugin cannot ship: a plugin's own `settings.json` supports only the `agent` and `subagentStatusLine` keys (plugins-reference, "File locations reference"). They have to live in your human partner's `~/.claude/settings.json`.

**Run this only when your human partner explicitly asks for it.** Never as a side effect of another task.

## Steps

1. Back up the current file so the diff has a left-hand side:

   ```
   cp ~/.claude/settings.json ~/.claude/settings.json.superteam-bak
   ```

   If the file does not exist yet, start from `{}`.

2. Merge the two keys into the existing `env` object, leaving every other key alone:

   ```
   python3 -c 'import json,os,pathlib; p=pathlib.Path(os.path.expanduser("~/.claude/settings.json")); d=json.loads(p.read_text() or "{}") if p.exists() else {}; d.setdefault("env",{}).update({"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS":"1","CLAUDE_CODE_ENABLE_TODO_TOOLS":"1"}); p.parent.mkdir(parents=True,exist_ok=True); p.write_text(json.dumps(d,indent=2)+"\n")'
   ```

   No python3? Edit the file by hand and add, inside the top-level object:

   ```json
   "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1", "CLAUDE_CODE_ENABLE_TODO_TOOLS": "1" }
   ```

3. Show your human partner what changed:

   ```
   diff ~/.claude/settings.json.superteam-bak ~/.claude/settings.json
   ```

4. Tell them the env is read at startup, so the session must be restarted before team mode is available.
