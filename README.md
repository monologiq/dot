# Dotfiles

Personal dotfiles configuration managed with GNU Stow and age.

## Machines
- odinoko: MacBook Pro M1 2020

 ```sh
 key=1234
 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/monologiq/dot/refs/heads/master/init.sh)" -- --key "$key"
 ```
 
## TODO

- [ ] Use `ln` for symlinks.
- [ ] Move `XDG_*` to `~/.zshenv`.
- [ ] QoL: implement `dot pre-commit` and `dot stow`.
- [ ] QoL: extract function to `lib` folder.