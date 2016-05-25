#
# Description: Creates Satellite Locations
# TODO: code cleanup...lots of duplicate code
# TODO: domains added to appropriate organizations
#

begin
  # ====================================
  # set gem requirements
  # ====================================

  require_relative 'call_rest.rb'
  require_relative 'get_org_id.rb'
  require_relative 'org_update.rb'
  require 'yaml'

  # ====================================
  # log beginning of method
  # ====================================

  # set method variables and log entering method
  @method = 'locations.rb'
  @debug = false

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

  # create a container with our domain ids so that we can update the organization with the domain ids after we finish
  dom_ids = []

  loc_config[:locations].each do |key, attrs|
    # ====================================
    # create domains first
    # ====================================
    unless attrs[:domain].nil?
      # log domain creation
      log(:info, "Creating domain #{attrs[:domain]}")

      # point the rest url to the domains resource
      params[:url] = "#{rest_url}domains"

      # create the payload data
      payload = {
        :domain => {
          :name => attrs[:domain],
          :fullname => attrs[:domain]
        }
      }

      # make the rest call to create the domain
      params[:method] = :post
      params[:payload] = JSON.generate(payload)
      dom_response = JSON.parse(RestClient::Request.new(params).execute) rescue nil
      log(:info, "Inspecting dom_response: #{dom_response.inspect}") if dom_response

      # log an error if our location rest call failed
      log(:error, "Unable to create domain: #{attrs[:domain]}") if dom_response.nil?

      # get the domain id for use in location creation and organization update
      dom_id = dom_response['id']
      dom_ids.push(dom_id)
    end

    # ====================================
    # create locations last
    # ====================================

    # initial logging
    log(:info, "Creating Location <#{key}>, with attributes <#{attrs}>")

    # point the rest url to the locations resource
    params[:url] = "#{rest_url}locations"

    # create the payload data
    payload = {
      :location => {
        :name => key,
        :description => attrs[:description],
        :domain_ids => [ dom_id ]
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

  # update the organization with the new domain ids
  org_update({ :organization => { :domain_ids => dom_ids } })

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