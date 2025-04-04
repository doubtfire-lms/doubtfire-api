desc 'List all grape routes'
task grape_routes: :environment do
  puts "-> Listing all grape routes"
  puts "-> Routes:"
  puts(ApiRoot.routes.map{ |route| "#{route.request_method.ljust(10)} - #{route.path}" })
  puts "!"
end
