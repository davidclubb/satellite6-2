#
# Description: Makes a REST Call
#
# Input Requirements:
#  - rest_action: HTTP actions (GET, POST, PUT, DELETE)
#  - rest_base_url: base URL without the resource
#  - rest_resource: the resource to perform the action on
#  - rest_api_user: the api user to perform the REST call
#  - rest_api_password: the password of the api user making the REST call
#
# Other Inputs (Optional):
#  - rest_debug: configures debug logging behavior (Defaults to false)
#  - rest_auth_type: authentication type for REST (Defaults to Basic, which is the only supported method as of now)
#  - rest_content_type: valid values are XML or JSON (defaults to JSON)
#  - rest_return_type: valid values are XML or JSON (defaults to JSON)
#  - rest_verify_ssl: tells the rest call to verify the SSL connection or ignore (defaults to true)
#  - rest_payload: the payload data to use when executing the REST call (must be in rest_content_type format - defaults to 'default')
#    NOTE: rest_payload must be passed in as a string due to inability in this version (4.1) to pass objects as inputs
#
# Notes:
#  - XML is currently untested
#
# Usage:
#   - Can be called as follows:
#
# rest_instance_path = "/System/CommonMethods/REST/CallRest"
# rest_query = {
#   :rest_action => :get,
#   :rest_base_url => 'https://resturl.example.com/api',
#   :rest_resource => :resource_for_rest_call,
#   :rest_api_user => 'admin',
#   :rest_api_password => 'admin',
#   :rest_verify_ssl => false,
#   :rest_debug => true
# }.to_query
# $evm.instantiate(rest_instance_path + '?' + rest_query)
#
# Return Values (set on the $evm.parent_object):
#   - rest_status: returns true on success, false on failure
#   - rest_results: returns the results of the REST call (in an array format; can be converted to a hash)
#
# Author: Dustin Scott, Red Hat
# Created On: June 22, 2016
#

begin
  # ====================================
  # set gem requirements
  # ====================================

  require_relative 'call_rest.rb'

  # ====================================
  # log beginning of method
  # ====================================

  # set method variables and log entering method
  @method = 'env.rb'
  @debug = true

  # ====================================
  # set variables
  # ====================================

  # log setting variables
  log(:info, "Setting variables for method: <#{@method}>")

  # get configuration
  env_config = YAML::load_file('env.yml')

  # inspect the env_config
  log(:info, "Inspecting env_config: #{env_config.inspect}") if @debug == true

  # ====================================
  # begin main method
  # ====================================

  # log entering main method
  log(:info, "Running main portion of ruby code on method: <#{@method}>")

  # create lifecycle environments
  env_config['environments'].each do |key, values|
    # create a hash for payload data
    payload = {}

    # set our resource url
    resource = "organizations/#{@org_id}/environments"
    prior_id = build_rest(@rest_base_url, resource, :get, @rest_content_type, @rest_return_type, @rest_api_user, @rest_api_password, { :name => values['prior']})['results'].first['id']
    log(:info, "Inspecting prior_id: #{prior_id.inspect}")
    values.each { |k,v| payload[k.to_sym] = v }
    payload[:name] = key
    payload[:prior] = prior_id
    log(:info, "Inspecting payload: #{payload.inspect}") if @debug == true

    # make the rest call to create the environment
    env_response = build_rest(@rest_base_url, resource, :post, @rest_content_type, @rest_return_type, @rest_api_user, @rest_api_password, payload)
    log(:info, "Inspecting env_response: #{env_response.inspect}")
  end

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


