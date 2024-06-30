# TreeFiddyGit

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
