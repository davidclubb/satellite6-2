#
# Description: Creates Lifecycle Environments
#

begin
  # ====================================
  # set gem requirements
  # ====================================

  require_relative 'call_rest.rb'
  require_relative 'get_org_id.rb'
  require 'yaml'

  # ====================================
  # log beginning of method
  # ====================================

  # set method variables and log entering method
  @method = 'environments.rb'
  @debug = true

  # log entering method
  log(:info, "Entering method <#{@method}>")

  # ====================================
  # set variables
  # ====================================

  # log setting variables
  log(:info, "Setting variables for method: <#{@method}>")

  # get configuration
  env_config = YAML::load_file('../conf/environments.yml')

  # inspect the env_config
  log(:info, "Inspecting env_config: #{env_config.inspect}") if @debug == true

  # ====================================
  # begin main method
  # ====================================

  # log entering main method
  log(:info, "Running main portion of ruby code on method: <#{@method}>")

  # create lifecycle environments
  env_config[:environments].each do |key, values|
    # create a hash for payload data
    payload = {}

    # set our resource url
    resource = "organizations/#{@org_id}/environments"
    prior_id = build_rest(resource, :get, { :name => values[:prior]})['results'].first['id']
    log(:info, "Inspecting prior_id: #{prior_id.inspect}")
    values.each { |k,v| payload[k.to_sym] = v }
    payload[:name] = key
    payload[:prior] = prior_id
    log(:info, "Inspecting payload: #{payload.inspect}") if @debug == true

    # make the rest call to create the environment
    env_response = build_rest(resource, :post, payload)
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


