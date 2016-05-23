#
# Description: runs the initial setup
# NOTE: this will only kickoff an initial repo sync (will have to manually wait
# TODO: logic to loop and retry until sync is complete
#

require_relative 'methods/subscriptions'
require_relative 'methods/repositories'
require_relative 'methods/environments'
require_relative 'methods/locations'