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

# Cache all .jar files at any depth
**/*.jar

# Cache assets directory (trailing slash = directories only)
assets/

# Exclude a specific path from being cached
!code/client/node_modules/tmp
```

### `.buildcache` Syntax

The `.buildcache` file supports a `.gitignore`-like syntax:

- **Literal paths**: `code/server/node_modules` — matches the exact path.
- **Glob patterns**: `*.js`, `**/*.jar` — shell-style wildcards. `**` matches any depth.
- **Directory-only** (trailing `/`): `assets/` — only matches directories.
- **Negation** (`!`): `!path/to/exclude` — removes previously matched paths from the restore set.
- **Comments** (`#`): Lines starting with `#` are ignored.
- **Empty lines** are ignored.

## Troubleshooting

**How to clear the cache?**

Use `heroku-repo` plugin.

```
$ heroku plugins:install https://github.com/heroku/heroku-repo.git
$ heroku repo:purge_cache -a appname
```
