# Pterodactyl-Script
Installing Pterodactyl in just a few minutes! <br />
Please note this script is meant to be used on fresh installations only. You must run it as root. <br />
<br />
`curl -Ls https://api.github.com/repos/TommyTran732/Pterodactyl-Script/releases/latest | grep -wo "https.*install.sh" | wget -qi -` <br />
<br /> 
`bash install.sh` <br />
<br />
Visit my Matrix group: https://matrix.to/#/#tommytran732:matrix.org
<br />

# Features
- Panel installation
- Panel upgrade
- Daemon installation
- Daemon upgrade
- phpMyAdmin installation (on nodes with the panel only - optional)
- Automatic LetsEncrypt certificate generation
- HSTS enabled
- MariaDB SSL
- Fail2ban sshd & phpMyAdmin-syslog jails
- Basic firewall configuration
- Database password reset

# Dependency updates
Currently, Pterodactyl's dependencies (PHP, MariaDB) will only recieve minor version updates (e.g. PHP 8.0.1 -> PHP 8.0.x). Dependency upgrade scripts for major version changes (e.g. PHP 8.0.x -> PHP 8.1.0) are planned, but they are not yet available. For now, changing between major versions of Pterodactyl's depdencies are the user's own responsibility. <br />

I expect that a script for Fedora-based distributions to be relatively clean and simple, thanks to dnf's modular repositories. The same cannot be said for Debian-based distributions however, as we have to remove all of the old versions of the dependencies with apt, install the new ones, then apply reconfigurations. Please take this into account when choosing your distribution.

# Script updates/Reproducibility
Unfortunately, there is currently not an option to automatically apply new features / fixes I make to the script to an existing installation. The user has to look at the changelog and the code to apply it on their own. Theoratically, I could write a script to automate this process, but I currently don't have enough bandwidth for this and I want to spend my time developing new features. If anyone could help me with this, I would highly appreciate it. <br />

Ideally, we would want everything to be reproducible from the OS to the Pterodactyl installation. I am currently looking at using Fedora CoreOS and Docker-Compose to accomplish this. If you are interested in such setup, please let me know.

# Supported Distributions
Fedora, CentOS Stream, RHEL, Rocky Linux, AlmaLinux, Ubuntu, and Debian are currently supported distributions. <br />

As it currently stands, RHEL is the best distribution for a production system. RHEL and its derivatives have much longer life cycle support (10 years) than Ubuntu LTS (5 years) and Debian (roughly 3 years - not counting Debian LTS), a much better Mandatory Access Control system, and a superior package manager. CentOS Stream is slightly (~1 minor version) ahead of RHEL, so you could expect it to be ever so slightly less stable. Rocky and AlmaLinux are RHEL rebuilds, so they are likely to get security patches after RHEL, just like how the old CentOS was. Red Hat now offers 16 licenses for free for production use, which also comes with Red Hat Insights, and I highly recommend that you choose RHEL over other distributions if possible. I am using RHEL on my personal Pterodactyl instance as well.<br />

If you live on the edge and don't mind doing a major OS upgrade every 6 months, then Fedora may be a perfect choice. However, I am not recommending it at the moment as it is probably not what people are looking for and I do not have enough energy to help with issues that may arise from doing in-place OS upgrades. <br />

As for Ubuntu, it is simply supported because it is a popular distribution and a lot of people might feel comfortable with it. That being said, I am not quite sure what the best practices are with Ubuntu at the moment - they seem to be pushing snaps very heavily, to the point where even Certbot and Docker are shipped and recommended as snaps. For simplicity, the script currently uses .deb packages just like it does with Debian, but this might change in the future if thoose .debs packages are neglected in favor of snaps. I personally would not use Ubuntu unless I have no other choices.

| Operating System  | Version  | Supported            | Recommended        | Notes                                |
| ----------------- | -------- | -------------------- | ------------------ | ------------------------------------ |
| Fedora            | 35       | :heavy_check_mark:   | 🔴                 |                                      |
| CentOS            | Stream 8 | :heavy_check_mark:   | ✔️                  |                                      |
| RHEL              | 8        | :heavy_check_mark:   | ✔️                  |                                      |
| Rocky Linux       | 8        | :heavy_check_mark:   | ✔️                  |                                      |
| Alma Linux        | 8        | :heavy_check_mark:   | ✔️                  |                                      |
| Ubuntu            | 20.04    | :heavy_check_mark:   | 🔴                 |                                      |
| Debian            | 11       | :heavy_check_mark:   | 🔴                 |                                      |
