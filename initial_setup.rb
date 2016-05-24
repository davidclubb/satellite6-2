#
# Description: runs the initial setup
# NOTE: this will only kickoff an initial repo sync (will have to manually wait
# TODO: logic to loop and retry until sync is complete
#

require_relative 'methods/subscriptions.rb'
require_relative 'methods/locations.rb'
require_relative 'methods/repositories.rb'
require_relative 'methods/content_views.rb'
require_relative 'methods/activation_keys.rb'
