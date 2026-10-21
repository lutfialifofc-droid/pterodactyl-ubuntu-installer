# Contributing to Pterodactyl Auto-Installer

Contributions are welcome! Please follow these guidelines:

## Code Style & Testing
- Ensure your shell scripts follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html).
- Run `shellcheck` on all scripts before submitting a pull request:
  ```bash
  shellcheck -x install.sh
  ```
- Test changes on a fresh Ubuntu 24.04 LTS instance (or a Docker/Multipass/LXD container).

## Submitting Pull Requests
1. Fork the repository.
2. Create your feature branch (`git checkout -b feature/awesome-feature`).
3. Commit your changes (`git commit -m 'Add awesome feature'`).
4. Push to the branch (`git push origin feature/awesome-feature`).
5. Open a Pull Request.
