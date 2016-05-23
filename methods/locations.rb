#
# Description: Creates Satellite Locations
#

begin
  # ====================================
  # set gem requirements
  # ====================================

  require_relative 'get_org_id.rb'
  require 'yaml'

  # ====================================
  # log beginning of method
  # ====================================

  # set method variables and log entering method
  @method = 'locations.rb'
  @debug = true

  # log entering method
  log(:info, "Entering method <#{@method}>")

  # ====================================
  # set variables
  # ====================================

  # log setting variables
  log(:info, "Setting variables for method: <#{@method}>")

  # get configuration
  loc_config = YAML::load_file('../conf/locations.yml')
  main_config = YAML::load_file('../conf/main_config.yml')

  # generate a url for location rest calls
  # NOTE: this is different because we arne't using katello in the url
  rest_url = "https://#{main_config[:rest_sat_server]}/api/v2/"

  # set params for api call
  params = {
    :url => "#{rest_url}locations",
    :verify_ssl => false,
    :headers => {
      :content_type => main_config[:rest_content_type],
      :accept => main_config[:rest_return_type],
      :authorization => "Basic #{Base64.strict_encode64("#{main_config[:rest_api_user]}:#{main_config[:rest_api_password]}")}"
    }
  }

  # inspect the loc_config
  log(:info, "Inspecting loc_config: #{loc_config.inspect}") if @debug == true

  # ====================================
  # begin main method
  # ====================================

  # log entering main method
  log(:info, "Running main portion of ruby code on method: <#{@method}>")

  # create locations
  loc_config[:locations].each do |key, attrs|
    # initial logging
    log(:info, "Creating Location <#{key}>, with attributes <#{attrs}>")

    # create the payload data
    payload = {
      :location => {
        :name => key,
        :description => attrs[:description]
      }
    }

    # add the parent id to the payload if we have it
    unless attrs[:parent].nil?
      # set the method action to get
      params[:method] = :get

      # add a search payload to the rest params
      params[:payload] = JSON.generate({ :search => attrs[:parent] })

      # return the rest response
      parent_response = JSON.parse(RestClient::Request.new(params).execute)
      log(:info, "Inspecting parent_response: #{parent_response.inspect}")

      # get the id from the response and add it to the payload
      parent_id = parent_response['results'].first['id']
      log(:info, "Found parent id: #{parent_id}")
      payload[:location][:parent_id] = parent_id
    end

    # make the rest call to create the location
    params[:method] = :post
    params[:payload] = JSON.generate(payload)
    loc_response = RestClient::Request.new(params).execute rescue nil
    log(:info, "Inspecting loc_response: #{loc_response.inspect}") if loc_response

    # log an error if our location rest call failed
    log(:error, "Unable to create location: #{key}") if loc_response.nil?
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