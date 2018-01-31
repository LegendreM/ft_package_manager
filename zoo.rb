require 'fileutils'
require 'optparse'
require 'toml'
require 'git'

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
    lib = { :path => [""], :cc_path => [""] }
    if conf["dependencies"] && !conf["is_lib"]
        conf["dependencies"].each do |dependency|
            begin
                dep_conf = TOML.load_file("./#{@dependencies_directory}/#{dependency[0]}/config.toml")
                lib[:cc_path] << "make -C ./#{@dependencies_directory}/#{dependency[0]}/;"
                lib[:path] << "./#{@dependencies_directory}/#{dependency[0]}/#{dep_conf["name"]}.a"
            rescue
                print "warning: #{dependency[0]} is not installed, use --install or remove it from config.toml\n"
            end
        end
    end
    return lib
end

def freeze_workspace()
    begin
        conf = TOML.load_file("config.toml")
    rescue
        print "error: no config.toml found\n"
        return
    end

    src = Dir["./src/*.c"]
    src = src.map { |file| File.basename(file, ".c") }.join(" ")
    p conf
    if conf["is_lib"]
        import_template(@makefile_lib_template_path, "Makefile", {:name => conf["name"], :src => src})
    else
        libs = get_libs_path(conf)
        import_template(@makefile_bin_template_path, "Makefile", {:name => conf["name"], :src => src, :libs => libs[:path].join(" "), :cc_libs => libs[:cc_path].join(" ")})
    end
end

def install_dependencies()
    begin
        conf = TOML.load_file("config.toml")
    rescue
        print "error: no config.toml found\n"
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
                        print "#{dependency[0]} from #{dependency[1]} installed\n"
                    else
                        FileUtils.rm_r("./#{@dependencies_directory}/#{dependency[0]}")
                        print "warning: #{dependency[0]} is not a lib, not installed\n"
                    end
                rescue
                    FileUtils.rm_r("./#{@dependencies_directory}/#{dependency[0]}")
                    print "warning: #{dependency[0]} has no config.toml, not installed\n"
                end
            rescue
                print "#{dependency[0]}\n"
            end
        end
        libs = get_libs_path(conf)
        p libs
        import_template(@makefile_bin_template_path, "Makefile", {:name => conf["name"], :src => "*", :libs => libs[:path].join(" "), :cc_libs => libs[:cc_path].join(" ")})
    end
end

def upgrade_dependencies()
    install_dependencies()
    begin
        conf = TOML.load_file("config.toml")
    rescue
        print "error: no config.toml found\n"
        return
    end

    p "gaspard"
    if conf["dependencies"] && !conf["is_lib"]
        conf["dependencies"].each do |dependency|
            begin
                g = Git.open("./#{@dependencies_directory}/#{dependency[0]}")
                g.pull
                `make -C "./#{@dependencies_directory}/#{dependency[0]}" fclean`
                p "coucou"
            rescue
                print "warning: #{dependency[0]} is not a git repository\n"
            end
        end
    end
end

def init_workspace(options)
    FileUtils::mkdir_p './src'
    FileUtils::mkdir_p './inc'
    unless options[:is_lib]
        import_template(@makefile_bin_template_path, "Makefile", {:name => options[:init_name], :src => "*", :libs => "", :cc_libs => ""})
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
        opt.on('-i', '--init NAME') { |o| options[:init_name] = o }
        opt.on('--freeze') { |o| options[:freeze] = o }
        opt.on('-l', '--lib') { |o| options[:is_lib] = o }
        opt.on('--install') { |o| options[:install] = o }
        opt.on('--upgrade') { |o| options[:upgrade] = o }
    end.parse!

    return options
end

def is_params_valid?(options)
    if options[:init_name]&& options[:freeze]
        $stderr.puts "--freeze and --init are not compatible"
        false
    elsif options[:is_lib] && options[:freeze]
        $stderr.puts "--freeze and --lib are not compatible"
        false
    end
    true
end

path = ENV["PM_PATH"]
template_path = "#{path}/template"

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
    print "#{e.message}\n"
    exit 1
end
unless is_params_valid? options
    exit 1
end

puts options

unless !options[:init_name] || options[:init_name].empty?
    init_workspace(options)
end

unless !options[:freeze]
    freeze_workspace()
end

unless !options[:install]
    install_dependencies()
end

unless !options[:upgrade]
    upgrade_dependencies()
end