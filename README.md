# heroku-buildpack-cacheload

Copy files from cache. Paths are read from `.buildcache` file in your project source code.

You should use this, if your project is pulling a lot of dependencies during each build. If you store them into cache and during build you just check if they haven't changed, your build time will reduce dramatically.

## Usage example

`$ heroku config:add BUILDPACK_URL=https://github.com/ddollar/heroku-buildpack-multi.git`

`.buildpacks`:

```
https://github.com/heroku/heroku-buildpack-nodejs
https://github.com/zakjan/heroku-buildpack-cacheload#1.0.1
https://github.com/kr/heroku-buildpack-inline
https://github.com/zakjan/heroku-buildpack-cachesave#1.0.1
```

`.buildcache`:

```
# Cache dependency directories
code/server/node_modules
code/client/node_modules
code/client/bower_components

# Cache a specific directory (trailing slash is optional)
assets/

# Cache an individual file
config/credentials.json

# Exclude previously listed paths from being cached
!code/client/node_modules
```

### `.buildcache` Syntax

The `.buildcache` file supports a `.gitignore`-like syntax. For performance,
inclusion and negation lines are handled differently:

- **Inclusion** — a literal file or folder path that is added to the restore
  set, e.g. `code/server/node_modules` or `config/credentials.json`. Folders are
  restored recursively. Glob patterns are **not** expanded for inclusion lines;
  list each path you want to restore explicitly. A trailing `/` (e.g. `assets/`)
  is allowed and treated the same as the path without it.
- **Negation** (`!`): `!path/or/glob` — removes already-listed paths from the
  restore set. Negation lines **do** support glob patterns (`*`, `?`, `[...]`),
  and a leading `**/` matches at any depth, e.g. `!**/node_modules`.
- **Comments** (`#`): Lines starting with `#` are ignored.
- **Empty lines** are ignored.

Inclusions are restored in parallel to speed up the cache load.

## Troubleshooting

**How to clear the cache?**

Use `heroku-repo` plugin.

```
$ heroku plugins:install https://github.com/heroku/heroku-repo.git
$ heroku repo:purge_cache -a appname
```
