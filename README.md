# SCP Backup Script

A Bash script for creating remote backups over SSH using `tar` and `scp`.  
Supports selecting root directories, custom subdirectories, remote sudo access, local retention policies, and logging.

## Features

- Backup of standard directories (e.g. `/etc`, `/home`, `/var`)
- Backup of specific subdirectories
- Remote archive creation using `tar`
- Optional `sudo` support for remote archive creation
- Download of archives via `scp`
- Automatic log rotation
- Retention policy for old backups
- Timestamped logs and archive names

## Requirements

- Bash 4+
- SSH access to the remote host
- The remote user must:
  - Have passwordless sudo access (if used in automation), or
  - Be able to run `tar` without `sudo`
- Local script execution should be done by `root` (especially when automated)

## Usage

```bash
./scp-backup.sh -r <remote_ip> -p <port> -u <user> [-d <dirs_comma_separated>] [-Sd <subdirs_comma_separated>] [-a] [-s <local_save_dir>] [-m <max_copies>]
```

### Parameters

| Flag       | Description |
|------------|-------------|
| `-r`       | Remote server IP address (**required**) |
| `-p`       | SSH port (**required**) |
| `-u`       | SSH username (**required**) |
| `-d`       | Comma-separated list of top-level directories to back up (e.g. `etc,home,var`) |
| `-Sd`      | Comma-separated list of full paths to specific subdirectories (e.g. `/home/user1,/var/log/nginx`) |
| `-a`       | **Ask for remote `sudo` password manually** (for interactive use only) |
| `-s`       | Local directory to save backups (default: current working directory) |
| `-m`       | Maximum number of local backup copies to keep (old ones will be deleted) |

> You must specify at least one of `-d` or `-Sd`.

---

### Notes on `-a` (ask for sudo password)

The `-a` flag is intended **only for manual usage** when the remote user is part of the `sudo` group and `sudo` access requires a password.  
This allows `tar` to be run with `sudo` for directories requiring elevated permissions.

**Do not use `-a` in cron jobs or other automated systems**, as it prompts for input.

For automated backups:
- Run the script locally as `root`
- Use a remote user that can run `tar` on the desired paths **without needing `sudo` or a password**

---

## Example

```bash
sudo ./scp-backup.sh \
  -r 192.168.0.100 \
  -p 2222 \
  -u webdev \
  -d etc,home \
  -Sd /home/user1,/var/log/nginx \
  -s /mnt/backup \
  -m 3
```

This command will:
- Connect to `192.168.0.100` on port `2222` as user `webdev`
- Create and download backups of `/etc`, `/home`, `/home/user1`, and `/var/log/nginx`
- Save them under `/mnt/backup/192.168.0.100/`
- Keep the last 3 backup folders, deleting older ones
- Log all operations under `/var/log/scp-backup/192.168.0.100.log`

---

## Cron Example

Run a daily backup at 2:00 AM:

```cron
0 2 * * * root /path/to/scp-backup.sh -r 192.168.0.100 -p 2222 -u webdev -d etc,home -s /mnt/backup -m 7
```

Make sure:
- The script is executable: `chmod +x scp-backup.sh`
- You run it as `root` (or configure passwordless `sudo` access on the remote side if needed)

---

## Logs

Logs are stored in `/var/log/scp-backup/<remote_ip>.log`  
Each log is rotated to keep only the last 1000 lines.

---

## License

MIT License
