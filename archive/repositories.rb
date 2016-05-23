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

  require 'rest-client'
  require 'json'
  require 'nokogiri'
  require 'base64'
  require 'yaml'

  # ====================================
  # define methods
  # ====================================

  # define log method
  def log(level, msg)
    puts "#{level}, #{@org} Customization: #{msg}"
  end

  # parse the response and return hash
  def parse_response(response, return_type)
    log(:info, "Running parse_response...")

    # return the response if it is already a hash
    if response.is_a?(Hash)
      log(:info, "Response <#{response.inspect}> is already a hash.  Returning response.")
      return response
    else
      if return_type == 'json'
        # attempt to convert the JSON response into a hash
        log(:info, "Response type requested is JSON.  Converting JSON response to hash.")
        response_hash = JSON.parse(response) rescue nil
      elsif return_type == 'xml'
        # attempt to convert the XML response into a hash
        log(:info, "Response type requested is XML.  Converting XML response to hash.")
        response_hash = Hash.from_xml(response) rescue nil
      else
        # the return_type we have specified is invalid
        raise "Invalid return_type <#{return_type}> specified"
      end
    end

    # raise an exception if we fail to convert response into hash
    raise "Unable to convert response #{response} into hash" if response_hash.nil?

    # log return the hash
    log(:info, "Inspecting response_hash: #{response_hash.inspect}") if @debug == true
    log(:info, "Finished running parse_response...")
    return response_hash
  end

  # executes the rest call with parameters
  def execute_rest(rest_url, params, return_type)
    log(:info, "Running execute_rest...")

    # log the parameters we are using for the rest call
    log(:info, "Inspecting REST params: #{params.inspect}") if @debug == true

    # execute the rest call
    rest_response = RestClient::Request.new(params).execute

    # convert the rest_response into a usable hash
    rest_hash = parse_response(rest_response, return_type)
    log(:info, "Finished running execute_rest...")
    return rest_hash
  end

  # builds the rest call
  def build_rest(rest_base_url, rest_resource, rest_action, rest_content_type, rest_return_type, rest_api_user, rest_api_password, rest_payload = nil, rest_auth_type = 'basic', rest_verify_ssl = false)
    # set rest url
    rest_url = URI.join(rest_base_url, rest_resource).to_s
    log(:info, "Used rest_base_url: <#{rest_base_url}>, and rest_resource: <#{rest_resource}>, to generate rest_url: <#{rest_url}>")

    # set params for api call
    params = {
        :method => rest_action,
        :url => rest_url,
        :verify_ssl => rest_verify_ssl,
        :headers => {
            :content_type => rest_content_type,
            :accept => rest_return_type
        }
    }

    # set the authorization header based on the type requested
    if rest_auth_type == 'basic'
      params[:headers][:authorization] = "Basic #{Base64.strict_encode64("#{rest_api_user}:#{rest_api_password}")}"
    else
      #
      # code for extra rest_auth_types goes here. currently only supports basic authentication
      #
    end

    # generate payload data
    if rest_content_type.to_s == 'json'
      # generate our body in JSON format
      params[:payload] = JSON.generate(rest_payload) unless rest_payload.nil?
    else
      # generate our body in XML format
      params[:payload] = Nokogiri::XML(rest_payload) unless rest_payload.nil?
    end

    # get the rest_response and set it on the parent object
    rest_results = execute_rest(rest_url, params, rest_return_type)
  end

  # ====================================
  # log beginning of method
  # ====================================

  # set method variables and log entering method
  @method = 'call_rest.rb'
  @debug = true

  # ====================================
  # set variables
  # ====================================

  # log setting variables
  log(:info, "Setting variables for method: <#{@method}>")

  # set rest params
  rest_base_url = 'https://192.168.50.130/katello/api/v2/'
  rest_content_type = 'json'
  rest_return_type = 'json'
  rest_api_user = 'admin'
  rest_api_password = 'redhat'

  # get configuration
  repo_config = YAML::load_file('repositories.yml')
  org_name = repo_config[:organization]

  # inspect the repo_config
  log(:info, "Inspecting repo_config: #{repo_config.inspect}") if @debug == true

  # ====================================
  # begin main method
  # ====================================

  # log entering main method
  log(:info, "Running main portion of ruby code on method: <#{@method}>")

  # get organization id
  rest_response = build_rest(rest_base_url, 'organizations', :get, rest_content_type, rest_return_type, rest_api_user, rest_api_password, { :search => org_name })
  org_id = rest_response['results'].first['id']
  log(:info, "Found Organization #{org_name} with ID: #{org_id}") if @debug == true

  # enable the repositories
  repo_config[:products].each do |product, repos|
    # get product id
    log(:info, "Getting product_id for product: #{product}")
    product_id = build_rest(rest_base_url, "organizations/#{org_id}/products", :get, rest_content_type, rest_return_type, rest_api_user, rest_api_password, { :name => product })['results'].first['id']
    raise "Unable to determine product id" if product_id.nil?

    # get the repo id and enable each repository
    repos[:repositories].each do |repo|
      repo.each do |repo_name, attrs|
        # get the repository id for the api call
        repo_id = build_rest(rest_base_url, "products/#{product_id}/repository_sets", :get, rest_content_type, rest_return_type, rest_api_user, rest_api_password, { :name => repo_name } )['results'].first['id']
        raise "Unable to determine repo_id" if repo_id.nil?

        # get the repository attributes from the yaml file so we enable the correct repository
        payload = {
          :basearch => attrs[:basearch],
          :releasever => attrs[:releasever]
        }
        payload.each { |k,v| raise "Unable to determine value for #{k}" if v.nil? }

        # enable the repository
        repo_response = build_rest(rest_base_url, "products/#{product_id}/repository_sets/#{repo_id}/enable", :put, rest_content_type, rest_return_type, rest_api_user, rest_api_password, payload )
        log(:info, "Inspecting repo_response: #{repo_response.inspect}")
      end
    end
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