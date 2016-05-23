#
# Description: Gets the Satellite 6 organization ID to be used in other REST calls
#

begin
  # ====================================
  # set gem requirements
  # ====================================

  require_relative 'call_rest.rb'
  require 'yaml'

  # ====================================
  # log beginning of method
  # ====================================

  # set method variables and log entering method
  @method = 'get_org_id.rb'
  @debug = true

  # log entering method
  log(:info, "Entering sub-method <#{@method}>")

  # ====================================
  # set variables
  # ====================================

  # log setting variables
  log(:info, "Setting variables for method: <#{@method}>")

  # get organization
  @org_name = YAML::load_file('../conf/org.yml')[:organization]
  raise 'Unable to determine org_name' if @org_name.nil?

  # ====================================
  # begin main method
  # ====================================

  # log entering main method
  log(:info, "Running main portion of ruby code on method: <#{@method}>")

  # create the get_org_id method which uses a REST call to get the organization id
  rest_response = build_rest('organizations', :get, { :search => @org_name })
  @org_id = rest_response['results'].first['id']
  log(:info, "Found Organization #{@org_name} with ID: #{@org_id}") if @debug == true

  # ====================================
  # log end of method
  # ====================================

  # log exiting method and let the parent instance know we succeeded
  log(:info, "Exiting sub-method <#{@method}>")

# set ruby rescue behavior
rescue => err
  # set error message
  message = "Error in method <#{@method}>: #{err}"

  # log what we failed
  log(:error, message)
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")

  # log exiting method and exit with MIQ_WARN status
  log(:info, "Exiting sub-method <#{@method}>")
end