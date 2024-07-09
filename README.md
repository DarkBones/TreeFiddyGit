# TreeFiddyGit

# Overview
**TreeFiddyGit** is a Neovim plugin designed to make managing git worktrees as seamless as using regular branches. It aims to simplify your workflow by providing a 1:1 relationship between branches and worktrees. This means that every branch you create or check out will exist in its own worktree, giving you an isolated environment for each branch.

Key features include:
- **1:1 Branch to Worktree Relationship**: Every branch you create or check out will be in a new worktree, ensuring clean and isolated development environments.
- **Telescope Integration**: Move between worktrees using a handy Telescope picker.
- **Branch-Based Worktree Creation**: When creating a new branch, the new branch and its corresponding worktree are based on the branch you currently have checked out.
- **[Custom Hooks](#hooks) for Enhanced Functionality**: TreeFiddyGit supports custom hooks that allow you to add your own functionality before and after key actions. (More details below, and examples in the wiki).

[comment]: <> (TODO: Link examples)

TreeFiddyGit simplifies the complexity of worktree management, letting you focus on coding rather than juggling multiple git environments.

# Installation
You can install **TreeFiddyGit** using various package managers. Below are instructions for some common ones:


## LazyVim
To install with LazyVim, add the following to your LazyVim configuration:
```lua
return {
    "DarkBones/TreeFiddyGit",
    dependencies = {
        "nvim-telescope/telescope.nvim",
    },
    config = function()
        require("TreeFiddyGit").setup()
    end,
}
```

## Packer
To install with Packer, add the following to your `init.lua` or `plugins.lua`:
```lua
use {
    "DarkBones/TreeFiddyGit",
    requires = { "nvim-telescope/telescope.nvim" },
    config = function()
        require("TreeFiddyGit").setup()
    end,
}
```

## Vim-Plug
To install with Vim-Plug, add the following to your `init.vim`:
```vim
Plug 'nvim-telescope/telescope.nvim'
Plug 'DarkBones/TreeFiddyGit'

lua << EOF
require("TreeFiddyGit").setup()
EOF
```

# Usage
| Command                            | Description                      |
|------------------------------------|----------------------------------|
| `:Telescope tree_fiddy_git get_worktrees` | List and switch between worktrees |
| `:Telescope tree_fiddy_git create_worktree` | Create a new worktree and switch to it |
| `:Telescope tree_fiddy_git create_worktree_stash` | Stash current changes, create a new worktree, switch to the new worktree, and apply the stashed changes |
| `:lua require('TreeFiddyGit').checkout_branch()` | Checkout a (remote) branch in a new worktree |

These commands can be mapped to your preferred keybindings.


############################################

If you need to pull remote branches, don't forget to add this line to the config under `[remote "origin"]`:
`fetch = +refs/heads/*:refs/remotes/origin/*`

Example config:
```
[core]
	repositoryformatversion = 0
	filemode = true
	bare = true
	ignorecase = true
	precomposeunicode = true
[remote "origin"]
	url = git@github.com:username/repo.git
	fetch = +refs/heads/*:refs/remotes/origin/*
[branch "main"]
	remote = origin
	merge = refs/heads/main
```
