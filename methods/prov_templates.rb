#
# Description: Creates Provisioning Templates
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
  @method = 'prov_templates.rb'
  @debug = true

  # log entering method
  log(:info, "Entering method <#{@method}>")

  # ====================================
  # set variables
  # ====================================

  # log setting variables
  log(:info, "Setting variables for method: <#{@method}>")

  # get configuration
  prov_config = YAML::load_file('../conf/prov_templates.yml')
  main_config = YAML::load_file('../conf/main_config.yml')

  # inspect the prov_config
  log(:info, "Inspecting prov_config: #{prov_config.inspect}") if @debug == true

  # ====================================
  # begin main method
  # ====================================

  # log entering main method
  log(:info, "Running main portion of ruby code on method: <#{@method}>")

  # create a container for the provisioning template ids to update the organization when we are done
  prov_ids = []

  # change the rest base url
  @rest_base_url = "https://#{main_config[:rest_sat_server]}/api/v2/"

  # get the operating system id
  os_id = build_rest('operatingsystems', :get, { :name => prov_config[:operating_system] } )['results'].first['id']

  # create the provisioning templates
  prov_config[:templates].each do |type, values|
    # ====================================
    # create snippets
    # ====================================
    if type.to_s == 'snippets'
      values.each do |snippet|
        # generate the payload
        payload = {
          :provisioning_template => {
            :name => snippet,
            :snippet => true,
            :template => File.open("../conf/snippets/#{snippet}").read,
            :operatingsystem_ids => [ os_id ]
          }
        }

        # make the rest call to create the snippet and push the id to the prov_ids array
        snippet_response = build_rest("provisioning_templates", :post, payload)
        prov_ids.push(snippet_response['id'])
      end
    # ====================================
    # create kickstarts
    # ====================================
    elsif type.to_s == 'kickstarts'
      values.each do |kickstart|
        # generate the payload
        payload = {
          :provisioning_template => {
            :name => kickstart,
            :snippet => false,
            :template => File.open("../conf/kickstarts/#{kickstart}").read,
            :operatingsystem_ids => [ os_id ],
            :template_kind_name => 'provision'
          }
        }

        # make the rest call to create the snippet and push the id to the prov_ids array
        ks_response = build_rest("provisioning_templates", :post, payload)
        prov_ids.push(ks_response['id'])
      end
    end
  end

  # reset the rest_base_url to default
  @rest_base_url = "https://#{main_config[:rest_sat_server]}#{main_config[:rest_sat_default_suffix]}"

  # update the organization with the new provisioning templates
  org_update({ :organization => { :provisioning_template_ids => prov_ids } })

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


