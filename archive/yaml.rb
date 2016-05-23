require 'yaml'

hash = YAML::load_file('content_views.yml')
#hash = {
#  :products => {
#    'Red Hat Enterprise Linux Server' => {
#      :repositories => [
#        'Red Hat Enterprise Linux 7 Server (RPMs)',
#        'Red Hat Enterprise Linux 6 Server (RPMs)'
#      ]
#    }
#  }
#}
puts "#{hash.inspect}"
yaml = hash.to_yaml

puts "#{yaml}"

file = YAML::load_file('subscriptions.yml')['manifest_file']
puts File.open(file)
#puts "#{hash[:products]}"

#hash[:products].each do |k,v|
#  puts k
#  puts v[:repositories]
#end
