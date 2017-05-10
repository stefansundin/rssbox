desc "Print list of middleware"
task :middleware do
  require "./app"
  puts JSON.pretty_generate(Sinatra::Application.instance_variable_get("@middleware"))
end
