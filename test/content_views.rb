#
# Description: Creates content views in an organization
# TODO: code cleanup...duplicating lots of code when doing composite vs standard views
#

begin
  # ====================================
  # set gem requirements
  # ====================================

  require_relative '../methods/call_rest.rb'
  require_relative '../methods/get_org_id.rb'
  require_relative '../methods/check_task.rb'
  require 'yaml'

  # ====================================
  # log beginning of method
  # ====================================

  # set method variables and log entering method
  @method = 'content_views.rb'
  @debug = true

  # log entering method
  log(:info, "Entering method <#{@method}>")

  # ====================================
  # set variables
  # ====================================

  # log setting variables
  log(:info, "Setting variables for method: <#{@method}>")

  # get configuration
  cv_config = YAML::load_file('../conf/content_views.yml')
  env_config = YAML::load_file('../conf/environments.yml')
  main_config = YAML::load_file('../conf/main_config.yml')

  # inspect the cv_config
  log(:info, "Inspecting cv_config: #{cv_config.inspect}") if @debug == true

  # ====================================
  # begin main method
  # ====================================

  # log entering main method
  log(:info, "Running main portion of ruby code on method: <#{@method}>")

  # get the last environment in the lifecycle enviornment
  # NOTE: it will take too long to promote through the lifecycle, so we are skipping to the last one for initial setup
  env = env_config[:environments].keys.last
  env_id = build_rest("organizations/#{@org_id}/environments", :get, { :name => env } )['results'].first['id']

  # publish and check status of the content views
  cv_config[:content_views].each do |view, attrs|
    # log what we are doing
    log(:info, "Promoting content view <#{view}> to environment <#{env}> (ID: #{env_id})")

    # get appropriate content view information needed for the final rest call
    cv_response = build_rest("content_views", :get, { :name => view, :organization_id => @org_id })
    log(:info, "Inspecting cv_response: #{cv_response.inspect}") if @debug == true
    cv_id = cv_response['results'].first['id']
    cv_version = cv_response['results'].first['versions'].first['id']

    # promote the content view to the final lifecycle environment
    promote_response = build_rest("content_view_versions/#{cv_version}/promote", :post, JSON.generate( { :force => true, :environment_id => env_id } ) ) rescue nil

    # get the task if we have a valid promote response
    unless promote_response.nil?
      task = promote_response['id']
    else
      log(:error, "Error promoting content view: #{view}")
      break
    end

    # keep looping until we have a success response from the task status
    check_task(100, 20, task)
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