#
# Description: Creates content views in an organization
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


  # ====================================
  # begin main method
  # ====================================

  # log entering main method
  log(:info, "Running main portion of ruby code on method: <#{@method}>")

  # get organization id
  rest_response = build_rest(rest_base_url, 'organizations', :get, rest_content_type, rest_return_type, rest_api_user, rest_api_password, { :search => org_name })
  org_id = rest_response['results'].first['id']
  log(:info, "Found Organization #{org_name} with ID: #{org_id}") if @debug == true

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
        cv_id = build_rest(rest_base_url, "content_views", :get, rest_content_type, rest_return_type, rest_api_user, rest_api_password, { :name => cv, :organization_id => org_id })['results'].first['id']
        cv_ids.push(cv_id)
      end

      # add component ids and name to the payload data
      payload[:name] = view
      payload[:component_ids] = cv_ids
    else
      # log that we are creating a composite content view
      log(:info, "Creating Composite Content View: <#{view}>")

      # create an array for all repo ids
      repo_ids = []

      # get the repository ids from the yaml file and add them to the repo_ids array
      attrs[:repositories].each do |repo|
        log(:info, "Finding repo_id for repository <#{repo}>")
        repo_id = build_rest(rest_base_url, "repositories", :get, rest_content_type, rest_return_type, rest_api_user, rest_api_password, { :name => repo, :organization_id => org_id })['results'].first['id']
        repo_ids.push(repo_id)
      end

      # add repository ids and name to the payload data
      payload[:name] = view
      payload[:repository_ids] = repo_ids
    end

    # make the rest call to create the content view
    cv_response = build_rest(rest_base_url, "organizations/#{org_id}/content_views", :post, rest_content_type, rest_return_type, rest_api_user, rest_api_password, payload)
    log(:info, "Inspecting cv_response: #{cv_response.inspect}")
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