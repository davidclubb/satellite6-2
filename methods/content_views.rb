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

  # inspect the cv_config
  log(:info, "Inspecting cv_config: #{cv_config.inspect}") if @debug == true

  # ====================================
  # begin main method
  # ====================================

  # log entering main method
  log(:info, "Running main portion of ruby code on method: <#{@method}>")

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
    log(:info, "Inspecting cv_response: #{cv_response.inspect}") if @debug == true
    log(:error, "Unable to create content view <#{view}>") if cv_response.nil?
    cv_id = cv_response['id']

    # publish the content view
    pub_response = build_rest("content_views/#{cv_id}/publish", :post) rescue nil
    log(:error, "Unable to publish content view <#{view}>") if pub_response.nil?
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