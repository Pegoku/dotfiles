# Vikunja calendar integration

The calendar reads projects and tasks from Vikunja and can create and complete
tasks. Credentials intentionally live outside this dotfiles repository.

1. In Vikunja, open **Settings → API Tokens** and create a token with permission
   to read projects/tasks and create/update tasks.
2. Open the calendar once. It automatically creates:

   ```sh
   ~/.config/vikunja-calendar/vikunja.conf
   ```

3. Fill in the server URL and token. The file is created with mode `600` so
   only your user can read it.

The URL may be the instance root or end in `/api/v1`. The integration supports
the current `/tasks` endpoint and falls back to `/tasks/all` for older servers.

`VIKUNJA_DEFAULT_PROJECT_ID` is optional. If it is missing or inaccessible, the
first non-archived project is selected when adding a task.

For compatibility, an existing `~/.config/vikunja-calendar/config` file is
still used when `vikunja.conf` has not been created yet.
