# System files

Files in here live outside `$HOME` and need root to install. They are kept in
the repo so the machine-level tweaks are versioned alongside the rest of the
config.

| Repo path | Install to |
| --- | --- |
| `udev/rules.d/99-fingerprint-no-autosuspend.rules` | `/etc/udev/rules.d/` |
| `tlp.d/10-fingerprint.conf` | `/etc/tlp.d/` |

Install with:

```sh
sudo system/install.sh
```
