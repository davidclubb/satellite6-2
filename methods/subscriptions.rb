#
# Description: Gets the Satellite 6 organization ID to be used in other REST calls
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
  @method = 'subscriptions.rb'
  @debug = true

  # log entering method
  log(:info, "Entering method <#{@method}>")

  # ====================================
  # set variables
  # ====================================

  # log setting variables
  log(:info, "Setting variables for method: <#{@method}>")

  # get configuration
  subscription_config = YAML::load_file('../conf/subscriptions.yml')
  rhn_base_url = YAML::load_file('../conf/main_config.yml')[:rhn_base_url]
  rhn_username = YAML::load_file('../conf/main_config.yml')[:rhn_username]
  rhn_password = YAML::load_file('../conf/main_config.yml')[:rhn_password]
  satellite_uuid = YAML::load_file('../conf/main_config.yml')[:rhn_satellite_uuid]
  raise 'Unable to determine rhn_base_url' if rhn_base_url.nil?
  raise 'Unable to determine satellite_uuid' if satellite_uuid.nil?
  raise 'Unable to determine @org_id from the get_org_id method' if @org_id.nil?
  raise 'Unable to determine rhn_username' if rhn_username.nil?
  raise 'Unable to determine rhn_password' if rhn_password.nil?

  # inspect the subscription_config
  log(:info, "Inspecting subscription_config: #{subscription_config.inspect}") if @debug == true

  # ====================================
  # begin main method
  # ====================================

  # log entering main method
  log(:info, "Running main portion of ruby code on method: <#{@method}>")

  # setup parameters to download the subscription manifest
  rhn_params = {
      :method => :get,
      :url => "#{rhn_base_url}#{satellite_uuid}/export",
      :verify_ssl => false,
      :headers => {
          :authorization => "Basic #{Base64.strict_encode64("#{rhn_username}:#{rhn_password}")}"
      }
  }

  # download the manifest
  log(:info, "Downloading manifest from url <#{rhn_params[:url]}>")
  File.open(subscription_config[:manifest_file], 'w') {|manifest|
    download_response = RestClient::Request.new(rhn_params).execute do |string|
      manifest.write string
    end
  }

  # upload the manifest to satellite server
  sat_params = {
      :method => :post,
      :url => "#{@rest_base_url}organizations/#{@org_id}/subscriptions/upload",
      :verify_ssl => false,
      :headers => {
          :authorization => "Basic #{Base64.strict_encode64("#{@rest_api_user}:#{@rest_api_password}")}"
      },
      :payload => {
        :multipart => true,
        :file => File.new(subscription_config[:manifest_file], 'rb')
      }
  }

  #upload_response = RestClient.post(
  #  "#{@rest_base_url}/organizations/#{@org_id}/subscriptions/upload",
  #  :upload => {
  #    :file => File.new(subscription_config[:manifest_file], 'rb')
  #  }
  #)
  #upload_response = build_rest("organizations/#{@org_id}/subscriptions/upload", :post, { :file => File.new(subscription_config[:manifest_file], 'rb') })
  upload_response = RestClient::Request.new(sat_params).execute
  log(:info, "Inspecting upload_response: #{upload_response.inspect}") if @debug == true

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