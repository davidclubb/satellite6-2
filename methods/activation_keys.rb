#
# Description: Creates content views in an organization
# TODO: code cleanup...duplicating lots of code when doing composite vs standard views
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
  @method = 'activation_keys.rb'
  @debug = true

  # ====================================
  # set variables
  # ====================================

  # log setting variables
  log(:info, "Setting variables for method: <#{@method}>")

  # get configuration
  ak_config = YAML::load_file('../conf/activation_keys.yml')
  env_config = YAML::load_file('../conf/environments.yml')

  # inspect the configs
  log(:info, "Inspecting ak_config: #{ak_config.inspect}") if @debug == true
  log(:info, "Inspecting env_config: #{env_config.inspect}") if @debug == true

  # ====================================
  # begin main method
  # ====================================

  # log entering main method
  log(:info, "Running main portion of ruby code on method: <#{@method}>")

  # get the last environment in the lifecycle enviornment
  # NOTE: it will take too long to promote through the lifecycle, so we are skipping to the last one for initial setup
  env = env_config[:environments].keys.last
  env_id = build_rest("organizations/#{@org_id}/environments", :get, { :name => env } )['results'].first['id']

  # create activation keys
  ak_config[:keys].each do |key, attrs|
    log(:info, "Activation Key: #{key}")
    log(:info, "Attrs: #{attrs.inspect}")
    puts attrs[:content_view]

    # get the content view id
    cv_id = build_rest("content_views", :get, { :name => attrs[:content_view], :organization_id => @org_id })['results'].first['id']
    log(:info, "Found cv_id #{cv_id} for content view #{attrs[:content_view]}")

    # create the payload data
    payload = {
      :name => key,
      :description => attrs[:description],
      :organization_id => @org_id,
      :environment_id => env_id,
      :content_view_id => cv_id
    }

    # make the rest call to create the activation key
    # NOTE: content views must be available in lifecycle environments of the activation key for this to work
    # TODO: put in logic for the above NOTE
    ak_response = build_rest("activation_keys", :post, payload)
    log(:info, "Inspecting ak_response: #{ak_response.inspect}")

    # TODO: put in logic to update repos and subscriptions for newly created activation key
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