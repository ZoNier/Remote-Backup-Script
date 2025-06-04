# 🔐 SCP Backup Script

A flexible Bash script for remote backups over SSH using `tar` and `scp`.
Supports custom directory selection, remote `sudo`, retention policy, and logging with rotation.

---

## 🚀 Features

* 🔁 Backup top-level directories (`/etc`, `/home`, `/var`, etc.)
* 🎯 Backup specific subdirectories (`/var/log/nginx`, `/home/user1`, etc.)
* 📦 Remote archive creation using `tar`
* 🔐 Optional `sudo` on the remote host
* 📥 Download `.tar` archives via `scp`
* 🧹 Automatic log rotation
* ♻️ Retention policy for local backups
* 🕒 Timestamped archive and log entries

---

## 📋 Requirements

* Bash **4+**
* SSH access to the remote host
* The remote user must:

  * Be able to run `tar` on required directories
  * Have **passwordless `sudo` access** if `-a` is used
* Local execution **must be done as root** (especially in automation)

---

## 🧪 Usage

```bash
./scp-backup.sh -r <remote_ip> -p <port> -u <user> [-d <dirs_comma_separated>] [-Sd <subdirs_comma_separated>] [-a] [-s <local_save_dir>] [-m <max_copies>]
```

### 📌 Parameters

| Flag  | Description                                                            |
| ----- | ---------------------------------------------------------------------- |
| `-r`  | Remote server IP or hostname (**required**)                            |
| `-p`  | SSH port (**required**)                                                |
| `-u`  | SSH username (**required**)                                            |
| `-d`  | Top-level directories to back up (e.g. `etc,home,var`)                 |
| `-Sd` | Specific subdirectories to include (e.g. `/home/user1,/var/log/nginx`) |
| `-a`  | Prompt for remote `sudo` password (interactive use only)               |
| `-s`  | Local backup directory (default: current working directory)            |
| `-m`  | Max number of backup copies to retain (oldest are deleted)             |

> ⚠️ **At least one of `-d` or `-Sd` must be specified.**

---

## 🔐 Notes on `-a` (Ask for Remote Sudo)

Use `-a` **only for manual runs**, if your remote user requires a password for `sudo`.
This flag prompts you to enter the password for archive creation via:

```bash
sudo tar czf ...
```

> ❌ Avoid `-a` in `cron` or automation — it requires interactive input.

---

## 💡 Example

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

✅ This command will:

* Connect to `192.168.0.100` via port `2222` as user `webdev`
* Create remote tar archives of:

  * `/etc`
  * `/home`
  * `/home/user1`
  * `/var/log/nginx`
* Save the archives locally to: `/mnt/backup/192.168.0.100/`
* Retain **only the 3 most recent** backups
* Log all actions to: `/var/log/scp-backup/192.168.0.100.log`

---

## ⏰ Automate with Cron

Add this to root's crontab to run daily at **2:00 AM**:

```cron
0 2 * * * root /opt/scp-backup.sh -r 192.168.0.100 -p 2222 -u webdev -d etc,home -s /mnt/backup -m 7
```

### 📌 Notes:

* Ensure the script is **executable**:

  ```bash
  chmod +x /opt/scp-backup.sh
  ```
* Remote user should not require `sudo` password in cron use cases.

---

## 📄 Logs

* 📍 Log files: `/var/log/scp-backup/<remote_ip>.log`
* 📜 Automatic rotation: logs trimmed to **last 1000 lines**

---

## 📜 License

This project is licensed under the [MIT License](LICENSE).
