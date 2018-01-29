require 'fileutils'
require 'optparse'
require 'toml'

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

def freeze_workspace()
    conf = TOML.load_file("config.toml")

    src = Dir["./src/*.c"]
    src = src.map { |file| File.basename(file, ".c") }.join(" ")
    p conf
    unless conf["is_lib"]
        import_template(@makefile_bin_template_path, "Makefile", {:name => conf["name"], :src => src})
    else
        import_template(@makefile_lib_template_path, "Makefile", {:name => conf["name"], :src => src})
    end
end

def init_workspace(options)
    FileUtils::mkdir_p './src'
    FileUtils::mkdir_p './inc'
    unless options[:is_lib]
        import_template(@makefile_bin_template_path, "Makefile", {:name => options[:init_name], :src => "*"})
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

options = parse()
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