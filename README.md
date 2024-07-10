# TreeFiddyGit

## Overview
**TreeFiddyGit** is a Neovim plugin designed to make managing git worktrees as seamless as using regular branches. It aims to simplify your workflow by providing a 1:1 relationship between branches and worktrees. This means that every branch you create or check out will exist in its own worktree, giving you an isolated environment for each branch.

**This plugin is very much still in development**

Key features include:
- **1:1 Branch to Worktree Relationship**: Every branch you create or check out will be in a new worktree, ensuring clean and isolated development environments.
- **Telescope Integration**: Move between worktrees using a handy Telescope picker.
- **Branch-Based Worktree Creation**: When creating a new branch, the new branch and its corresponding worktree are based on the branch you currently have checked out.
- **[Custom Hooks](#hooks) for Enhanced Functionality**: TreeFiddyGit supports custom hooks that allow you to add your own functionality before and after key actions. (More details below).

TreeFiddyGit simplifies the complexity of worktree management, letting you focus on coding rather than juggling multiple git environments.

## Installation
You can install **TreeFiddyGit** using various package managers. Below are instructions for some common ones:


### LazyVim
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

### Packer
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

### Vim-Plug
To install with Vim-Plug, add the following to your `init.vim`:
```vim
Plug 'nvim-telescope/telescope.nvim'
Plug 'DarkBones/TreeFiddyGit'

lua << EOF
require("TreeFiddyGit").setup()
EOF
```

## Usage
| Command                            | Description                      |
|------------------------------------|----------------------------------|
| `:Telescope tree_fiddy_git get_worktrees` | List and switch between worktrees |
| `:Telescope tree_fiddy_git create_worktree` | Create a new worktree and switch to it |
| `:Telescope tree_fiddy_git create_worktree_stash` | Stash current changes, create a new worktree, switch to the new worktree, and apply the stashed changes |
| `:lua require('TreeFiddyGit').checkout_branch()` | Checkout a (remote) branch in a new worktree |

These commands can be mapped to your preferred keybindings.

You can delete a worktree by bringing up the telescope window with `:Telescope tree_fiddy_git get_worktrees` and pressing `C-d` on the highlighted tree.

### Hooks
TreeFiddyGit provides a robust hooks system that allows you to execute custom functionality before and after key actions. Hooks are called with two parameters: `action` and `data`.

- **`action`**: A string representing the action that just occurred.
- **`data`**: Additional data related to the action (details vary by action).

The available action values are:
| Action Value                     | Description                                               |
|----------------------------------|-----------------------------------------------------------|
| `pre-checkout`                   | Before checking out a branch                              |
| `post-checkout`                  | After checking out a branch                               |
| `pre-create`                     | Before creating a new worktree                            |
| `post-create`                    | After creating a new worktree                             |
| `pre-move`                       | Before moving to an existing worktree                     |
| `post-move`                      | After moving to an existing worktree                      |
| `pre-delete`                     | Before deleting a worktree                                |
| `post-delete`                    | After deleting a worktree                                 |
| `create.pre-move`                | Before moving to the new worktree right after creating it |
| `create.post-move`               | After moving to the new worktree right after creating it  |
| `checkout.create.pre-move`       | Before moving to the new worktree right after checking out a branch |
| `checkout.create.post-move`      | After moving to the new worktree right after checking out a branch  |

#### Example Hook
Here’s an example of how you can set up a hook in the plugin configuration:
```lua
require("TreeFiddyGit").setup({
    hook = function(action, data)
        if action == "post-create" then
            print("A new worktree has been created: " .. data.path)
        elseif action == "pre-checkout" then
            print("About to check out branch: " .. data.new_branch)
        end
    end,
})
```

This setup will print a message whenever a new worktree is created or a branch is about to be checked out. You can customize the `hook` function to suit your specific needs.

### Remote Branch Configuration
If you need to pull remote branches, make sure to add the following line to the `[remote "origin"]` section of your Git configuration:
```ini
fetch = +refs/heads/*:refs/remotes/origin/*
```

Here’s an example configuration file:
```ini
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
This ensures that all branches are fetched from the remote repository, allowing you to work seamlessly with TreeFiddyGit.
