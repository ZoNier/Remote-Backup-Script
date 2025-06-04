# Remote Backup Script via SSH (scp & tar)

This is a bash script for backing up directories and subdirectories from a remote Linux server via SSH. The script creates compressed tar archives on the remote server and securely downloads them to the local machine. It supports backing up multiple root directories or arbitrary full-path subdirectories.

## Features

- Runs as root on the local machine for full control and logging.
- Supports passwordless SSH authentication (recommended).
- Optionally requests sudo password for remote archive creation.
- Creates compressed `.tar.gz` archives on the remote server.
- Downloads archives with `scp`.
- Cleans up temporary archives on the remote server.
- Maintains local backup directories with timestamp.
- Limits number of saved backup copies locally.
- Rotates logs (max 1000 lines).

## Requirements

- SSH access to the remote server.
- `tar` installed on the remote server.
- `scp` and `ssh` on the local machine.
- Optional: sudo access on the remote server if backing up directories requiring elevated permissions.

## Usage

```bash
./backup_script.sh -r <remote_ip> -p <ssh_port> -u <ssh_user> [-d <dirs_comma_separated>] [-Sd <subdirs_comma_separated>] [-a] [-s <local_save_dir>] [-m <max_copies>]
```

### Parameters

- `-r` Remote server IP address.
- `-p` SSH port (usually 22).
- `-u` SSH username.
- `-d` Comma-separated list of root directories to backup (e.g., `etc,home,var`).
- `-Sd` Comma-separated list of full-path subdirectories to backup (e.g., `/home/user1,/var/log/nginx`).
- `-a` Ask for sudo password on remote server (optional).
- `-s` Local directory to save backups (optional, defaults to current directory).
- `-m` Maximum number of saved backup copies locally (optional, no limit by default).

### Example

```bash
./backup_script.sh -r 192.168.0.100 -p 2222 -u webdev -d etc,home -Sd /home/user1,/var/log/nginx -a -s /mnt/backup -m 3
```

---

## Automating with Cron

You can automate backups by scheduling this script with `cron`.

Example `crontab` entry to run backup every day at 2:30 AM:

```cron
30 2 * * * /path/to/backup_script.sh -r 192.168.0.100 -p 22 -u webdev -d etc,home -Sd /home/user1,/var/log/nginx -a -s /mnt/backup -m 7 >> /var/log/scp-backup/cron_backup.log 2>&1
```

- Make sure your SSH keys are set up for passwordless authentication or handle password prompts accordingly.
- Redirecting output to a log file helps track backup activity and errors.

---

## License

MIT License

---

## Notes

- This script assumes the remote user has permission to read the specified directories.
- For directories requiring root privileges on the remote host, use the `-a` flag and provide sudo password.
- Logs are saved under `/var/log/scp-backup/` by default.
