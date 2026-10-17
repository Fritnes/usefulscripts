# Useful Scripts

Small shell scripts for Linux server setup, monitoring, and Grafana administration.

> **Review before running:** These scripts can create users, change SSH and sudo configuration, install system packages, write systemd services, and modify Grafana dashboards. Read the relevant script first and make sure you have a recovery path before applying system-level changes.

## Scripts

| Script | Purpose | Requirements |
| --- | --- | --- |
| [`add_user.sh`](add_user.sh) | Create a user and optionally configure a password, SSH key, or sudo access. | Linux, root access; `curl` when fetching keys from GitHub. |
| [`first_install.sh`](first_install.sh) | Apply initial server settings, configure SSH and the `wheel` sudo group, and install `net-tools`. | Debian-like Linux, root access, `sudo`, `visudo`, and systemd. |
| [`install_docker.sh`](install_docker.sh) | Install Docker Engine and the Compose plugin from Docker's apt repository. | Debian/Ubuntu-based system, `sudo`, `lsb_release`, and systemd. |
| [`install_node_exporter.sh`](install_node_exporter.sh) | Install or update Prometheus Node Exporter and register a systemd service. | Linux (amd64, arm64, or armv7), root access, `curl`, `tar`, and systemd. |
| [`migrate_grafana_dashboards.sh`](migrate_grafana_dashboards.sh) | Export dashboards from one Grafana instance and import them to another. | Bash, `curl`, and `jq`; API keys for both instances. |

## Usage

Clone the repository and inspect a script before running it:

```bash
git clone https://github.com/Fritnes/usefulscripts.git
cd usefulscripts
```

### Add a user

```bash
curl -s https://raw.githubusercontent.com/Fritnes/usefulscripts/refs/heads/main/add_user.sh | sudo bash -s -- -u myuser -pw "mypassword" [-s]
```

Choose one of these authentication options. Leave out `-pw` to be prompted securely for a password:

```bash
curl -s https://raw.githubusercontent.com/Fritnes/usefulscripts/refs/heads/main/add_user.sh | sudo bash -s -- -u myuser -pkey "ssh-rsa AAAA..." [-s]
curl -s https://raw.githubusercontent.com/Fritnes/usefulscripts/refs/heads/main/add_user.sh | sudo bash -s -- -u myuser -gh githubuser [-s]
curl -s https://raw.githubusercontent.com/Fritnes/usefulscripts/refs/heads/main/add_user.sh | sudo bash -s -- -u myuser [-s]
```

`-s` adds the new user to the sudo or wheel group. Avoid using `-pw` with a real password: command-line arguments may be visible to other local users or retained in shell history.

### First-time server setup

```bash
curl -s https://raw.githubusercontent.com/Fritnes/usefulscripts/refs/heads/main/first_install.sh | sudo bash
```

### Install Docker

```bash
curl -s https://raw.githubusercontent.com/Fritnes/usefulscripts/refs/heads/main/install_docker.sh | sudo bash
```

### Install Node Exporter

```bash
curl -s https://raw.githubusercontent.com/Fritnes/usefulscripts/refs/heads/main/install_node_exporter.sh | sudo bash
```

To install under a custom base directory, provide an absolute path:

```bash
curl -s https://raw.githubusercontent.com/Fritnes/usefulscripts/refs/heads/main/install_node_exporter.sh | sudo bash -s -- /opt/monitoring_tools
```

The default base directory is `/opt/monitoring_tools`.

### Migrate Grafana dashboards

```bash
./migrate_grafana_dashboards.sh http://old_url OLD_API_KEY http://new_url NEW_API_KEY ./staging false
```

Arguments are source URL, source API key, destination URL, destination API key, staging directory, and dry-run flag. The staging directory defaults to `./tmp/staging`; dry-run defaults to `true`. Keep the final argument `true` to preview the migration, and use `false` only after reviewing the exported dashboards and confirming the destination. The script writes `grafana_migration.log` in the current directory.

## Important notes

- `first_install.sh` disables SSH password authentication and root login, then restarts `sshd`. Confirm key-based access works before running it, or you may lose remote access.
- `first_install.sh` grants members of `wheel` passwordless sudo and edits `/etc/sudoers` directly. Keep console or out-of-band access available in case the SSH or sudo configuration needs recovery.
- The setup and install scripts make system-wide changes and should be run only on systems you administer.
- Avoid putting API keys or passwords into shared command history, logs, or screenshots.
- The `curl | bash` examples above are convenient, but downloading and inspecting a script before execution is safer.

## License

No license is currently specified. Unless a license is added, others may not have permission to reuse or redistribute this code.