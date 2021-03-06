def in_project_folder(&block)
  project_folder = @active_project_folder || @tmp_root
  FileUtils.chdir(project_folder, &block)
end

def in_home_folder(&block)
  FileUtils.chdir(@home_path, &block)
end

Given %r{^a safe folder} do
  FileUtils.rm_rf   @tmp_root = File.dirname(__FILE__) + "/../../tmp"
  FileUtils.mkdir_p @tmp_root
  FileUtils.mkdir_p @home_path = File.expand_path(File.join(@tmp_root, "home"))
  @lib_path = File.expand_path(File.dirname(__FILE__) + '/../../lib')
  Given "env variable $HOME set to '#{@home_path}'"
end

Given %r{^this project is active project folder} do
  Given "a safe folder"
  @active_project_folder = File.expand_path(File.dirname(__FILE__) + "/../..")
end

Given %r{^env variable \$([\w_]+) set to '(.*)'} do |env_var, value|
  ENV[env_var] = value
end

def prepend_to_file(filename, text)
  file = File.read(filename)
  File.open(filename, "w+") do |f|
    f << text + "\n"
    f << file
  end
end

def append_to_file(filename, text)
  File.open(filename, "a") do |f|
    f << text + "\n"
  end
end

def setup_active_project_folder project_name
  @active_project_folder = File.join(@tmp_root, project_name)
  FileUtils.mkdir_p @active_project_folder
  @project_name = project_name
end

Given %r{'(.*)' folder is deleted} do |folder|
  in_project_folder do
    FileUtils.rm_rf folder
  end
end

Given %r{file '(.*)' is deleted} do |file|
  in_project_folder do
    FileUtils.rm_rf file
  end
end

When %r{^'(.*)' generator is invoked with arguments '(.*)'$} do |generator, arguments|
  @stdout = StringIO.new
  FileUtils.chdir(@active_project_folder) do
    if Object.const_defined?("APP_ROOT")
      APP_ROOT.replace(FileUtils.pwd)
    else 
      APP_ROOT = FileUtils.pwd
    end
    run_generator(generator, arguments.split(' '), SOURCES, :stdout => @stdout)
  end
  File.open(File.join(@tmp_root, "generator.out"), "w") do |f|
    @stdout.rewind
    f << @stdout.read
  end
end

When %r{run executable '(.*)' with arguments '(.*)'} do |executable, arguments|
  @stdout = File.expand_path(File.join(@tmp_root, "executable.out"))
  in_project_folder do
    system "#{executable} #{arguments} > #{@stdout} 2> #{@stdout}"
  end
end

When %r{run project executable '(.*)' with arguments '(.*)'} do |executable, arguments|
  @stdout = File.expand_path(File.join(@tmp_root, "executable.out"))
  in_project_folder do
    system "ruby #{executable} #{arguments} > #{@stdout} 2> #{@stdout}"
  end
end

When %r{run local executable '(.*)' with arguments '(.*)'} do |executable, arguments|
  @stdout = File.expand_path(File.join(@tmp_root, "executable.out"))
  executable = File.expand_path(File.join(File.dirname(__FILE__), "/../../bin", executable))
  in_project_folder do
    system "ruby #{executable} #{arguments} > #{@stdout} 2> #{@stdout}"
  end
end

When %r{^task 'rake (.*)' is invoked$} do |task|
  @stdout = File.expand_path(File.join(@tmp_root, "tests.out"))
  FileUtils.chdir(@active_project_folder) do
    system "rake #{task} --trace > #{@stdout} 2> #{@stdout}"
  end
end

Then %r{^folder '(.*)' (is|is not) created} do |folder, is|
  in_project_folder do
    File.exists?(folder).should(is == 'is' ? be_true : be_false)
  end
end

Then %r{^file '(.*)' (is|is not) created} do |file, is|
  in_project_folder do
    File.exists?(file).should(is == 'is' ? be_true : be_false)
  end
end

Then %r{^file with name matching '(.*)' is created} do |pattern|
  in_project_folder do
    Dir[pattern].should_not be_empty
  end
end

Then %r{gem file '(.*)' and generated file '(.*)' should be the same} do |gem_file, project_file|
  File.exists?(gem_file).should be_true
  File.exists?(project_file).should be_true
  gem_file_contents = File.read(File.dirname(__FILE__) + "/../../#{gem_file}")
  project_file_contents = File.read(File.join(@active_project_folder, project_file))
  project_file_contents.should == gem_file_contents
end

Then %r{^output same as contents of '(.*)'$} do |file|
  expected_output = File.read(File.join(File.dirname(__FILE__) + "/../expected_outputs", file))
  actual_output = File.read(@stdout)
  actual_output.should == expected_output
end

Then %r{^(does|does not) invoke generator '(.*)'$} do |does_invoke, generator|
  actual_output = File.read(@stdout)
  does_invoke == "does" ?
    actual_output.should(match(/dependency\s+#{generator}/)) :
    actual_output.should_not(match(/dependency\s+#{generator}/))
end

Then %r{help options '(.*)' and '(.*)' are displayed} do |opt1, opt2|
  actual_output = File.read(@stdout)
  actual_output.should match(/#{opt1}/)
  actual_output.should match(/#{opt2}/)
end

Then %r{^output (does|does not) match \/(.*)\/} do |does, regex|
  actual_output = File.read(@stdout)
  (does == 'does') ?
    actual_output.should(match(/#{regex}/)) :
    actual_output.should_not(match(/#{regex}/)) 
end

Then %r{^contents of file '(.*)' (does|does not) match \/(.*)\/} do |file, does, regex|
  in_project_folder do
    actual_output = File.read(file)
    (does == 'does') ?
      actual_output.should(match(/#{regex}/)) :
      actual_output.should_not(match(/#{regex}/))
  end
end

Then %r{^all (\d+) tests pass} do |expected_test_count|
  expected = %r{^#{expected_test_count} tests, \d+ assertions, 0 failures, 0 errors}
  actual_output = File.read(@stdout)
  actual_output.should match(expected)
end

Then %r{^all (\d+) examples pass} do |expected_test_count|
  expected = %r{^#{expected_test_count} examples?, 0 failures}
  actual_output = File.read(@stdout)
  actual_output.should match(expected)
end

Then %r{^yaml file '(.*)' contains (\{.*\})} do |file, yaml|
  in_project_folder do
    yaml = eval yaml
    YAML.load(File.read(file)).should == yaml
  end
end

Then %r{^Rakefile can display tasks successfully} do
  @stdout = File.expand_path(File.join(@tmp_root, "rakefile.out"))
  FileUtils.chdir(@active_project_folder) do
    system "rake -T > #{@stdout} 2> #{@stdout}"
  end
  actual_output = File.read(@stdout)
  actual_output.should match(/^rake\s+\w+\s+#\s.*/)
end

Then %r{^task 'rake (.*)' is executed successfully} do |task|
  @stdout.should_not be_nil
  actual_output = File.read(@stdout)
  actual_output.should_not match(/^Don't know how to build task '#{task}'/)
  actual_output.should_not match(/Error/i)
end

Then %r{^gem spec key '(.*)' contains \/(.*)\/} do |key, regex|
  in_project_folder do
    gem_file = Dir["pkg/*.gem"].first
    gem_spec = Gem::Specification.from_yaml(`gem spec #{gem_file}`)
    spec_value = gem_spec.send(key.to_sym)
    spec_value.to_s.should match(/#{regex}/)
  end
end

Given /^file '(.*)' timestamp remembered$/ do |file|
  in_project_folder do
    @timestamp = File.new(file).mtime
  end
end

Then /^file '(.*)' is unchanged$/ do |file|
  raise %Q{ERROR: need to use "Given file '#{file}' timestamp remembered" to set the timestamp} unless @timestamp
  in_project_folder do
    File.new(file).mtime.should == @timestamp
  end
end

Then /^file '(.*)' is modified$/ do |file|
  raise %Q{ERROR: need to use "Given file '#{file}' timestamp remembered" to set the timestamp} unless @timestamp
  in_project_folder do
    File.new(file).mtime.should_not == @timestamp
  end
end

When %r{^in file '(.*)' replace /(.*)/ with '(.*)'$} do |file, from, to|
  in_project_folder do
    contents = File.read(file)
    File.open(file, "w") do |f|
      f << contents.gsub(/#{from}/, to)
    end
  end
end

Then /^file '(.*)' (is|is not) invisible$/ do |file, is|
  `GetFileInfo -aV '#{file}'`.to_i.should_not == (is == 'is' ? 0 : 1)
end

Then /^file '(.*)' is a symlink to '(.*)'$/ do |path, target_path|
  in_project_folder do
    stdout = `ls -al #{path}`
    stdout =~ /\s([^\s]+)\s->\s(.+)$/
    target_path.should == $2
  end
end
