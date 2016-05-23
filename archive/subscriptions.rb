#
# Description: Downloads the initial manifest and sets up the subscriptions in Satellite
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
  def parse_response(response)
    log(:info, "Running parse_response...")

    # return the response if it is already a hash
    if response.is_a?(Hash)
      log(:info, "Response <#{response.inspect}> is already a hash.  Returning response.")
      return response
    else
      if @rest_return_type == 'json'
        # attempt to convert the JSON response into a hash
        log(:info, "Response type requested is JSON.  Converting JSON response to hash.")
        response_hash = JSON.parse(response) rescue nil
      elsif @rest_return_type == 'xml'
        # attempt to convert the XML response into a hash
        log(:info, "Response type requested is XML.  Converting XML response to hash.")
        response_hash = Hash.from_xml(response) rescue nil
      else
        # the return_type we have specified is invalid
        raise "Invalid return_type <#{@rest_return_type}> specified"
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
  def execute_rest(rest_url, params)
    log(:info, "Running execute_rest...")

    # log the parameters we are using for the rest call
    log(:info, "Inspecting REST params: #{params.inspect}") if @debug == true

    # execute the rest call and inspect the response
    rest_response = RestClient::Request.new(params).execute

    # convert the rest_response into a usable hash
    rest_hash = parse_response(rest_response)
    log(:info, "Finished running execute_rest...")
    return rest_hash
  end

  # builds the rest call
  def build_rest(rest_resource, rest_action, rest_payload = nil, rest_auth_type = 'basic', rest_verify_ssl = false)
    # set rest url
    rest_url = URI.join(@rest_base_url, rest_resource).to_s
    log(:info, "Used rest_base_url: <#{@rest_base_url}>, and rest_resource: <#{rest_resource}>, to generate rest_url: <#{rest_url}>")

    # set params for api call
    params = {
        :method => rest_action,
        :url => rest_url,
        :verify_ssl => rest_verify_ssl,
        :headers => {
            :content_type => @rest_content_type,
            :accept => @rest_return_type
        }
    }

    # set the authorization header based on the type requested
    if rest_auth_type == 'basic'
      params[:headers][:authorization] = "Basic #{Base64.strict_encode64("#{@rest_api_user}:#{@rest_api_password}")}"
    else
      #
      # code for extra rest_auth_types goes here. currently only supports basic authentication
      #
    end

    # generate payload data
    if @rest_content_type.to_s == 'json'
      # generate our body in JSON format
      params[:payload] = JSON.generate(rest_payload) unless rest_payload.nil?
    else
      # generate our body in XML format
      params[:payload] = Nokogiri::XML(rest_payload) unless rest_payload.nil?
    end

    # get the rest_response and set it on the parent object
    rest_results = execute_rest(rest_url, params)
  end

  # ====================================
  # log beginning of method
  # ====================================

  # set method variables and log entering method
  @method = 'subscriptions.rb'
  @debug = true

  # ====================================
  # set variables
  # ====================================

  # log setting variables
  log(:info, "Setting variables for method: <#{@method}>")



  # get configuration
  subscription_config = YAML::load_file('../conf/subscriptions.yml')
  rhn_base_url = YAML::load_file('../conf/main_config.yml')[:rhn_base_url]
  satellite_uuid = YAML::load_file('../conf/main_config.yml')[:rhn_satellite_uuid]
  raise 'Unable to determine rhn_base_url' if rhn_base_url.nil?
  raise 'Unable to determine satellite_uuid' if satellite_uuid.nil?
  raise 'Unable to determine @org_id from the get_org_id method' if @org_id.nil?

  # get organization
  @org_name = YAML::load_file('../conf/org.yml')[:organization]
  raise 'Unable to determine org_name' if @org_name.nil?

  # inspect the env_config
  log(:info, "Inspecting subscription_config: #{subscription_config.inspect}") if @debug == true

  # ====================================
  # begin main method
  # ====================================

  # log entering main method
  log(:info, "Running main portion of ruby code on method: <#{@method}>")

  # create the get_org_id method which uses a REST call to get the organization id
  rest_response = build_rest('organizations', :get, { :search => @org_name })
  @org_id = rest_response['results'].first['id']
  log(:info, "Found Organization #{@org_name} with ID: #{@org_id}") if @debug == true

  # download the subscription manifest
  rhn_params = {
      :method => :get,
      #:url => "https://subscription.rhn.redhat.com/subscription/consumers/#{satellite_uuid}/export",
      :url => "#{rhn_base_url}#{satellite_uuid}/export",
      :verify_ssl => false,
      :headers => {
          :content_type => @rest_content_type,
          :accept => @rest_return_type
      }
  }
  rest_response = RestClient::Request.new(params).execute
  log(:info, "Inspecting rest_response: #{rest_response.inspect}") if @debug == true

  # upload the subscription manifest
 # payload = {
  #  :content => subscription_config['manifest_file'],
  #  :organization_id => org_id
  #}
  #File.open(subscription_config['manifest_file'], 'r') do |file|
  #  upload_response = build_rest(rest_base_url, "organizations/#{org_id}/subscriptions/upload", :post, rest_content_type, rest_return_type, rest_api_user, rest_api_password, payload )
  #  #upload_response = build_rest(rest_base_url, "organizations/#{org_id}/subscriptions/upload", :post, rest_content_type, rest_return_type, rest_api_user, rest_api_password, { :content => file } )
  #  log(:info, "Inspecting upload_response: #{upload_response.inspect}") if @debug == true
  ##end



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