# fzf.nvim

An extensible neovim plugin that integrates fzf into the editor

## Usage

[lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "samsze0/fzf.nvim",
    config = function()
        require("fzf").setup({})
    end,
    dependencies = {
        "samsze0/tui.nvim",
        "samsze0/utils.nvim",
        "samsze0/jumplist.nvim",
        "samsze0/terminal-filetype.nvim",
        "samsze0/notifier.nvim",
        "samsze0/websocket.nvim"  -- Optional
    }
}
```

## TODO

- Remote scrolling should scroll whichever buffer is "longer"
- True "workspace" diagnostics
- Keep only the most recent controller stack and destroy the others when they go stale
- Add support for shell command entries getter
- TODO comments selector
- Backups selector (integrate with persist.nvim)
- Integration with syncthing & tailscale
- Migrate to the "job system"
- Integrate with watchman to watch for filetree / gittree changes
- Support entry streaming (`reload` asynchronously)
- Integrate with linux commands e.g. `lsof`, `lsblk`
- Integrate with homebrew
- Integrate with k8s
- Integrate with git worktree
- Error handling and reporting. Error occured in "fast lane" is slienced?
- Add options to not change focus when invoking `refresh`

## License

MIT
