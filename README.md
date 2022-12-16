# Pterodactyl-Script
Installing Pterodactyl in just a few minutes! <br />
Please note this script is meant to be used on fresh installations only. You must run it as root. <br />
<br />
`curl -Ls https://api.github.com/repos/TommyTran732/Pterodactyl-Script/releases/latest | grep -wo "https.*install.sh" | wget -qi -` <br />
<br />
`bash install.sh` <br />
<br />
Visit my Matrix group: https://matrix.to/#/#tommy:arcticfoxes.net
<br />

# Features
- Panel installation
- Panel upgrade
- Daemon installation
- Daemon upgrade
- Basic firewall configuration
- Fail2ban for SSH and Wings
- Automatic LetsEncrypt certificate generation
- MariaDB SSL
- HSTS enabled
- Additional security headers (CSP, Permission Policy, CORP, COOP)
- Database password reset

# Dependency Updates

Currently, PHP, Composer, and Redis are installed from Remi's modular repository. As such, they will only get minor version updates with `dnf upgrade` (PHP 8.1.0 -> PHP 8.1.x for example). For updates between major versions of these dependencies, use `dnf module` to change the appstream for these dependencies.<br />

```bash
dnf module switch-to php:remi-8.1
```

NGINX, MariaDB, and Docker-CE uses upstream repositories and will get the latest version available on there automatically.

# Script updates/Reproducibility
Unfortunately, there is currently not an option to automatically apply new features / fixes I make to the script to an existing installation. The user has to look at the changelog and the code to apply them on their own. Theoratically, I could write a script to automate this process, but I currently don't have enough bandwidth for this and I want to spend my time developing new features. If anyone could help me with this, I would highly appreciate it. <br />

Ideally, we would want everything to be reproducible from the OS to the Pterodactyl installation. I am currently looking at using Fedora CoreOS and Docker-Compose to accomplish this. If you are interested in such setup, please let me know.

# Supported Distributions
Only RHEL 9 and its derivatives (CentOS Stream 9, Rocky Linux 9 , AlmaLinux 9) are supported at the moment. Fedora may get supported in the future if there are interest in it.

Ubuntu, Debian, and openSUSE are unlikely to get supported, due to them not supporting modular repositories which makes dependency updates cumbersome.
