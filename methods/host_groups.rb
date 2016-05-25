#
# Description: Creates Hostgroups
# TODO: code cleanup...lots of duplicate code
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
  # define methods
  # ====================================

  # method to create the hostgroup
  def hg_create(payload, main_config)
    # ensure that we have the correct rest_base_url and capture our current rest base url
    current_url = @rest_base_url
    @rest_base_url = "https://#{main_config[:rest_sat_server]}/api/v2/"

    # post the payload
    hg_response = build_rest('hostgroups', :post, payload )
    log(:info, "Inspecting hg_response: #{hg_response.inspect}") if @debug == true

    # reset the url back to what it was before
    @rest_base_url = current_url

    # return the id of the hostgroup we created
    hg_id = hg_response['id']
  end

  # ====================================
  # log beginning of method
  # ====================================

  # set method variables and log entering method
  @method = 'host_groups.rb'
  @debug = true

  # log entering method
  log(:info, "Entering method <#{@method}>")

  # ====================================
  # set variables
  # ====================================

  # log setting variables
  log(:info, "Setting variables for method: <#{@method}>")

  # get configurations
  hg_config = YAML::load_file('../conf/host_groups.yml')
  env_config = YAML::load_file('../conf/environments.yml')
  loc_config = YAML::load_file('../conf/locations.yml')
  main_config = YAML::load_file('../conf/main_config.yml')

  # inspect the config
  log(:info, "Inspecting hg_config: #{hg_config.inspect}") if @debug == true

  # ====================================
  # begin main method
  # ====================================

  # log entering main method
  log(:info, "Running main portion of ruby code on method: <#{@method}>")

  # create a container for objects which will need to be updated at the org level after the hostgroup creation
  pt_ids = []

  # get the environments and locations, as we will be creating them nested in the following format
  # HG_PARENT/HG_LOCATION/HG_ENV
  # NOTE: only using the last lifecycle environment in this case
  locs = loc_config[:locations].keys.select { |loc| loc_config[:locations][loc][:parent] == nil }
  envs = [ env_config[:environments].keys.last ]

  # create host groups
  hg_config[:host_groups].each do |group, attrs|
    # get the content view id
    cv_id = build_rest("content_views", :get, { :name => attrs[:content_view], :organization_id => @org_id })['results'].first['id']

    # change the rest base url for those items that aren't tenanted
    @rest_base_url = "https://#{main_config[:rest_sat_server]}/api/v2/"

    # get the operating system id
    os_id = build_rest('operatingsystems', :get, { :name => attrs[:operating_system] } )['results'].first['id']
    os_attrs = build_rest("operatingsystems/#{os_id}", :get)
    media_id = os_attrs['media'].first['id']
    arch_id = os_attrs['architectures'].first['id']

    # create the hostgroup payload
    payload = {
      :hostgroup => {
        :name => group,
        :operatingsystem_id => os_id,
        :architecture_id => arch_id,
        :medium_id => media_id,
        :organization_ids => [ @org_id ],
        :content_view_id => [ cv_id ]
      }
    }

    # make the rest call to create the hostgroup
    hg_id = hg_create(payload, main_config)

    # create the hostgroup partition table if we have one
    if attrs[:ptable_conf]
      # get the partition table so that we can create it
      ptable = File.open("../conf/ptables/#{attrs[:ptable_conf]}").read

      # create the partition table
      payload = {
        :ptable => {
          :name => "PT_#{group.split('_').last}",
          :os_family => 'Redhat',
          :operatingsystem_ids => [ os_id ],
          :hostgroup_ids => [ hg_id ],
          :layout => ptable
        }
      }
      pt_response = build_rest('ptables', :post, payload )
      log(:info, "Inspecting pt_response: #{pt_response.inspect}") if @debug == true

      # push the id into the partition table array
      pt_ids.push(pt_response['id'])
    end

    # ====================================
    # create location based host groups
    # ====================================
    locs.each do |loc|
      # get the location id and the object
      loc_id = build_rest('locations', :get, { :search => loc } )['results'].first['id']
      loc_obj = build_rest("locations/#{loc_id}", :get )

      # get the domain/subnet ids for the location
      domain_id = loc_obj['domains'].first['id'] rescue nil
      subnet_id = loc_obj['subnets'].first['id'] rescue nil

      # create the location based hostgroup payload
      payload = {
        :hostgroup => {
          :name => loc,
          :parent_id => hg_id,
          :location_ids => [ loc_id ],
          :organization_ids => [ @org_id ]
        }
      }

      # make the rest call to create the location based hostgroup
      loc_hg_id = hg_create(payload, main_config)

      # ====================================
      # create environment based host groups
      # ====================================
      envs.each do |env|
        # reset the rest_base_url to default
        @rest_base_url = "https://#{main_config[:rest_sat_server]}#{main_config[:rest_sat_default_suffix]}"
        env_id = build_rest('environments', :get, { :name => env, :organization_id => @org_id } )['results'].first['id']

        # create the environment base hostgroup payload
        payload = {
          :hostgroup => {
            :name => env,
            :parent_id => loc_hg_id,
            :lifecycle_environment_id => env_id,
            :organization_ids => [ @org_id ]
          }
        }

        # make the rest call to create the environment based hostgroup
        env_hg_id = hg_create(payload, main_config)

        # change the rest base url
        @rest_base_url = "https://#{main_config[:rest_sat_server]}/api/v2/"
      end
    end
  end

  # update the organization with the new partition tables
  org_update({ :organization => { :ptable_ids => pt_ids } })

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


