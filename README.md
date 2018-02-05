# Zoo project manager

## PRE

you need to install `ruby`

## Install

`git clone -b 'v2.0' --single-branch --depth 1 https://github.com/LegendreM/ft_package_manager.git $HOME/.zoo; cd $HOME/.zoo; make install; export PM_PATH=$HOME/.zoo ; export PATH=$HOME/.zoo:$PATH ; cd -`

## Usage

### Structure
Dependencies and project need to have a `config.toml` file

exemple
```
# boolean to know if the compiled file is a '.a' or binary file
is_lib = false

# name of compiled object, if object is a '.a' file don't add the extension
name = "ft_project"

# all dependencies of the project (need to be on a git repository)
[dependencies]
libft = "http://github.com/ft_name/libft"
```

Each dependencies may have an header directory named 'inc/'

Dependencies directory structure
```
|- config.toml
|- Makefile
|- src/
    |- src1.c
    |- src2.c
    |- ...
|- inc/
    |- source.h
```


### Commands

`zoo --help`: write usage

`zoo --init=NAME [-l]`: create a new project named `NAME` in the current drectory,
if `-l` option is added the project will be compiled as lib (`.a` file)

`zoo --install`: install all dependencies specified in main `config.toml`,
recurcively if dependencies have sub-dependencies

`zoo --upgrade`: upgrade all dependencies specified in main `config.toml`,
recurcively if dependencies have sub-dependencies

`zoo --freeze`: replace `*.c` in main makefile by all sources name in `src/`
