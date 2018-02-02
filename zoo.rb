#!/usr/bin/env ruby

require 'fileutils'
require 'optparse'
require 'toml'
require 'git'
require 'colorize'

def warn_msg(msg)
    $stderr.puts "warning: #{msg}".yellow
end

def error_msg(msg)
    $stderr.puts "error: #{msg}".red
end

def info_msg(msg)
    puts "#{msg}"
end

def highlighted_msg(prefix, msg, suffix)
    msg = "#{msg}".green
    puts "#{prefix}#{msg}#{suffix}" 
end

def import_template(template_path, dest_path, template_params)
    file = File.open(template_path, "r")
    data = file.read
    file.close
    file = File.new(dest_path, "w")
    file.write(data % template_params)
    file.close
end

def write_toml(hash)
    data = TOML::Generator.new(hash).body
    file = File.new("config.toml", "w")
    file.write(data)
    file.close
end

def get_libs_path(conf)
    lib = { :path => [""], :cc_path => [""], :headers_path => [""] }
    if conf["dependencies"] && !conf["is_lib"]
        conf["dependencies"].each do |dependency|
            begin
                dep_conf = TOML.load_file("./#{@dependencies_directory}/#{dependency[0]}/config.toml")
                lib[:cc_path] << "make -C ./#{@dependencies_directory}/#{dependency[0]}/;"
                lib[:path] << "./#{@dependencies_directory}/#{dependency[0]}/#{dep_conf["name"]}.a"
                lib[:headers_path] << "-I ./#{@dependencies_directory}/#{dependency[0]}/inc/"
            rescue
                warn_msg("#{dependency[0]} is not installed, use --install or remove it from config.toml")
            end
        end
    end
    return lib
end

def freeze_workspace()
    begin
        conf = TOML.load_file("config.toml")
    rescue
        error_msg("no config.toml found")
        return
    end

    src = Dir["./src/*.c"]
    src = src.map { |file| File.basename(file, ".c") }.join(" ")
    if conf["is_lib"]
        import_template(@makefile_lib_template_path, "Makefile", {:name => conf["name"], :src => src})
    else
        libs = get_libs_path(conf)
        import_template(@makefile_bin_template_path, "Makefile", {:name => conf["name"], :src => src, :libs => libs[:path].join(" "), :cc_libs => libs[:cc_path].join(" "), :headers_path => libs[:headers_path].join(" ")})
    end
end

def install_dependencies()
    begin
        conf = TOML.load_file("config.toml")
    rescue
        error_msg("no config.toml found")
        return
    end

    if conf["dependencies"] && !conf["is_lib"]
        FileUtils::mkdir_p "./#{@dependencies_directory}"
        conf["dependencies"].each do |dependency|
            begin
                Git.clone(dependency[1], "./#{@dependencies_directory}/#{dependency[0]}")
                begin
                    dep_conf = TOML.load_file("./#{@dependencies_directory}/#{dependency[0]}/config.toml")
                    if dep_conf["is_lib"]
                        highlighted_msg("", "#{dependency[0]}", " from #{dependency[1]} installed")
                    else
                        FileUtils.rm_r("./#{@dependencies_directory}/#{dependency[0]}")
                        warn_msg("#{dependency[0]} is not a lib, not installed")
                    end
                rescue
                    FileUtils.rm_r("./#{@dependencies_directory}/#{dependency[0]}")
                    warn_msg("#{dependency[0]} has no config.toml, not installed")
                end
            rescue
                print "#{dependency[0]}\n"
            end
        end
        libs = get_libs_path(conf)
        import_template(@makefile_bin_template_path, "Makefile", {:name => conf["name"], :src => "*", :libs => libs[:path].join(" "), :cc_libs => libs[:cc_path].join(" "), :headers_path => libs[:headers_path].join(" ")})
    end
end

def upgrade_dependencies()
    install_dependencies()
    begin
        conf = TOML.load_file("config.toml")
    rescue
        error_msg("no config.toml found")
        return
    end

    if conf["dependencies"] && !conf["is_lib"]
        conf["dependencies"].each do |dependency|
            begin
                g = Git.open("./#{@dependencies_directory}/#{dependency[0]}")
                g.pull
                `make -C "./#{@dependencies_directory}/#{dependency[0]}" fclean`
            rescue
                warn_msg("#{dependency[0]} is not a git repository")
            end
        end
    end
end

def init_workspace(options)
    FileUtils::mkdir_p './src'
    FileUtils::mkdir_p './inc'
    unless options[:is_lib]
        import_template(@makefile_bin_template_path, "Makefile", {:name => options[:init_name], :src => "*", :libs => "", :cc_libs => "", :headers_path => ""})
        import_template(@main_template_path, "src/main.c", {:name => options[:init_name]})
    else
        import_template(@makefile_lib_template_path, "Makefile", {:name => options[:init_name], :src => "*"})
    end
    import_template(@header_template_path, "inc/#{options[:init_name]}.h", {:name => options[:init_name].upcase})

    hash = {
        :name => options[:init_name],
        :is_lib => options[:is_lib] | false,
        :dependencies => {}
    }
    write_toml(hash)
end

def parse()
    options = {}
    OptionParser.new do |opt|
        opt.banner = "Usage: #{@bin_name} [options]"
        opt.on('--init=NAME', "Init a new project") { |o| options[:init_name] = o }
        opt.on('--lib', "Init project as lib, used with --init=NAME") { |o| options[:is_lib] = o }
        opt.on('--freeze', "Replace wildcards by project file name") { |o| options[:freeze] = o }
        opt.on('--install', "Install dependencies") { |o| options[:install] = o }
        opt.on('--upgrade', "Upgrade dependencies") { |o| options[:upgrade] = o }
        opt.on("-h", "--help", "Show help") do
            puts opt
            options = {}
        end
    end.parse!

    return options
end

def is_params_valid?(options)
    if options[:init_name]&& options[:upgrade]
        error_msg("--upgrade and --init are not compatible")
        false
    elsif options[:is_lib] && options[:upgrade]
        error_msg("--upgrade and --lib are not compatible")
        false
    end
    true
end

path = ENV["PM_PATH"]
template_path = "#{path}/template"

@bin_name = "zoo"

# Makefiles Path
makefile_bin_name = "/Makefile_bin.template"
makefile_lib_name = "/Makefile_lib.template"
@makefile_bin_template_path = template_path + makefile_bin_name
@makefile_lib_template_path = template_path + makefile_lib_name

# main path
main_name = "/main.c.template"
@main_template_path = template_path + main_name

# header path
header_name = "/header.h.template"
@header_template_path = template_path + header_name

# dependencies directory name
@dependencies_directory = "dep/"
begin
    options = parse()
rescue Exception => e
    error_msg("#{e.message}")
    exit 1
end
unless is_params_valid? options
    exit 1
end

unless !options[:init_name] || options[:init_name].empty?
    unless File.exist? File.expand_path "./config.toml"
        init_workspace(options)
    else
        error_msg("a config.toml file exist in this directory, remove it before create a new project")
    end
end

unless !options[:install]
    install_dependencies()
end

unless !options[:upgrade]
    upgrade_dependencies()
end

unless !options[:freeze]
    freeze_workspace()
end