# Vikunja calendar integration

The calendar reads projects and tasks from Vikunja and can create and complete
tasks. Credentials intentionally live outside this dotfiles repository.

1. In Vikunja, open **Settings → API Tokens** and create a token with permission
   to read projects/tasks and create/update tasks.
2. Copy `vikunja.conf.example` to `~/.config/vikunja-calendar/config`.
3. Fill in the server URL and token, then protect the file:

   ```sh
   chmod 600 ~/.config/vikunja-calendar/config
   ```

The URL may be the instance root or end in `/api/v1`. The integration supports
the current `/tasks` endpoint and falls back to `/tasks/all` for older servers.

`VIKUNJA_DEFAULT_PROJECT_ID` is optional. If it is missing or inaccessible, the
first non-archived project is selected when adding a task.
