## Installation

### Vundle

```vim
Plugin 'puuuuh/compe-crates'
```

### Packer

```lua
use 'puuuuh/compe-crates'
```

## Configuration
```lua
vim.g.cargo_compe_path = "PATH_FOR_INDEX_FILES" -- "~/.local/share/cargo-compe/" by default

require'compe'.setup {
  source = {
    crates = true;
  };
}

```

## Dependencies
* Neovim 0.5 with lua support
* nvim-compe

## Commands
* :CompeCratesUpdate
