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
        "samsze0/utils.nvim",
        "samsze0/jumplist.nvim",
        "samsze0/terminal-filetype.nvim",
        "samsze0/notifier.nvim",
        "samsze0/websocket.nvim"  -- Optional
    }
}
```

## License

MIT