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
  require_relative 'check_task.rb'
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

  # create content views
  cv_config[:content_views].each do |view, attrs|
    log(:info, "Content View: #{view}")
    log(:info, "Attrs: #{attrs.inspect}")

    # create the payload data
    payload = {
        :label => attrs[:label],
        :description => attrs[:description]
    }

    if attrs[:composite] == ('true' || true)
      # log that we are creating a composite view
      log(:info, "Creating Composite Content View: <#{view}>")

      # create an array for all content view ids
      cv_ids = []

      # get the content view ids from the yaml file and add them to the cv_ids array
      attrs[:content_views].each do |cv|
        cv_id = build_rest("content_views", :get, { :name => cv, :organization_id => @org_id })['results'].first['id']
        cv_ids.push(cv_id)
      end

      # add component ids and name to the payload data
      payload[:name] = view
      payload[:component_ids] = cv_ids
    else
      # log that we are creating a standard content view
      log(:info, "Creating Standard Content View: <#{view}>")

      # create an array for all repo ids
      repo_ids = []

      # get the repository ids from the yaml file and add them to the repo_ids array
      attrs[:repositories].each do |repo|
        log(:info, "Finding repo_id for repository <#{repo}>")
        repo_id = build_rest("repositories", :get, { :name => repo, :organization_id => @org_id })['results'].first['id']
        repo_ids.push(repo_id)
      end

      # add repository ids and name to the payload data
      payload[:name] = view
      payload[:repository_ids] = repo_ids
    end

    # make the rest call to create the content view
    cv_response = build_rest("organizations/#{@org_id}/content_views", :post, payload) rescue nil
    cv_id = cv_response['id']
    log(:info, "Inspecting cv_response: #{cv_response.inspect}") if @debug == true
    log(:error, "Unable to create content view <#{view}>") if cv_response.nil?

    # publish the content view
    pub_response = build_rest("content_views/#{cv_id}/publish", :post) rescue nil
    log(:error, "Unable to publish content view <#{view}>") if pub_response.nil?
    task = pub_response['id']

    # check the status until the publish finishes
    check_task(200, 20, task)

    # get appropriate content view information needed for the final rest call
    cv_ver = build_rest("content_views", :get, { :name => view, :organization_id => @org_id })['results'].first['versions'].first['id']

    # promote the content view to the final lifecycle environment
    promote_response = build_rest("content_view_versions/#{cv_ver}/promote", :post, { :force => true, :environment_id => env_id } ) rescue nil

    # get the task if we have a valid promote response
    unless promote_response.nil?
      task = promote_response['id']
    else
      log(:error, "Error promoting content view: #{view}")
      break
    end

    # check the status until the promote finishes
    check_task(200, 20, task)
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