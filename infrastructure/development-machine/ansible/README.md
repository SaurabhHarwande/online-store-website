# Development Machine Ansible Configuration

Ansible playbooks and roles to configure the development machine with required software.

## Prerequisites

- Ansible installed on your local machine
- SSH access to the development machine
- The development machine IP address

## Setup

1. Set the development machine IP address:
   ```bash
   export DEV_MACHINE_IP=<your-instance-ip>
   ```

   Or manually edit `inventory.yml` and replace `REPLACE_WITH_IP` with your instance IP.

2. Set up GitHub authentication (for automatic SSH key addition):
   ```bash
   export GITHUB_TOKEN=<your-github-personal-access-token>
   export GIT_USER_NAME="Your Name"
   export GIT_USER_EMAIL="your.email@example.com"
   ```

   To create a GitHub token:
   - Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Generate new token with `admin:public_key` permission
   - Copy the token

3. Test connectivity:
   ```bash
   ansible all -m ping
   ```

## Run Playbook

Execute the setup playbook:
```bash
ansible-playbook playbooks/setup-dev-machine.yml
```

**Note:** If you don't provide `GITHUB_TOKEN`, the SSH key will be generated and displayed, but you'll need to manually add it to GitHub.

## What Gets Installed

- **Common packages**: curl, wget, git, vim, htop, build-essential
- **.NET 10 SDK**: Latest .NET 10 SDK from Microsoft
- **Java 25**: Oracle JDK 25
- **GitHub CLI**: GitHub command-line tool
- **Git Configuration**: SSH key generation and GitHub integration
- **VS Code Server**: Extensions pre-installed for Remote SSH

## Roles

### common
Installs basic development tools and updates system packages.

### dotnet
Installs .NET 10 SDK from Microsoft's official repository.

### java
Downloads and installs Oracle JDK 25, sets JAVA_HOME and updates alternatives.

### git-setup
- Installs GitHub CLI
- Generates SSH key (ed25519)
- Automatically adds SSH key to GitHub (if token provided)
- Configures git user.name and user.email
- Adds github.com to known_hosts

### vscode-server
Pre-installs VS Code extensions for Remote SSH:
- C# extension (ms-dotnettools.csharp)
- Extension Pack for Java (vscjava.vscode-java-pack)

## Testing

After running the playbook, verify installations:
```bash
ansible dev-machine -m shell -a "dotnet --version"
ansible dev-machine -m shell -a "java --version"
```
