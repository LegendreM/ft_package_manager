
require 'fileutils'
require 'optparse'

def import_template(template_path, dest_path, template_params)
    file = File.open(template_path, "r")
    data = file.read
    file.close
    file = File.new(dest_path, "w")
    file.write(data % template_params)
    file.close
end

def init_workspace(options)
    FileUtils::mkdir_p './src'
    FileUtils::mkdir_p './inc'
    unless options[:is_lib]
        FileUtils::mkdir_p './lib'
        import_template(@makefile_bin_template_path, "Makefile", {:name => options[:init_name], :src => "*"})
        import_template(@main_template_path, "src/main.c", {:name => options[:init_name]})
    else
        import_template(@makefile_lib_template_path, "Makefile", {:name => options[:init_name], :src => "*"})
    end
    import_template(@header_template_path, "inc/#{options[:init_name]}.h", {:name => options[:init_name].upcase})
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


options = {}
OptionParser.new do |opt|
  opt.on('-i', '--init NAME') { |o| options[:init_name] = o }
  opt.on('-l', '--lib') { |o| options[:is_lib] = o }
end.parse!

puts options

unless options[:init_name].empty?
    init_workspace(options)
end