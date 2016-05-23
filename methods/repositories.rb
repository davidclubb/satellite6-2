#
# Description: Enables Red Hat repositories via REST
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
  @method = 'repositories.rb'
  @debug = true

  # log entering method
  log(:info, "Entering method <#{@method}>")

  # ====================================
  # set variables
  # ====================================

  # log setting variables
  log(:info, "Setting variables for method: <#{@method}>")

  # get configuration
  repo_config = YAML::load_file('../conf/repositories.yml')

  # inspect the repo_config
  log(:info, "Inspecting repo_config: #{repo_config.inspect}") if @debug == true

  # ====================================
  # begin main method
  # ====================================

  # log entering main method
  log(:info, "Running main portion of ruby code on method: <#{@method}>")

  # enable the repositories
  repo_config[:products].each do |product, repos|
    # get product id
    log(:info, "Getting product_id for product: #{product}")
    product = build_rest("organizations/#{@org_id}/products", :get, { :name => product })
    log(:info, "Inspecting product: #{product.inspect}")
    product_id = product['results'].first['id']
    raise "Unable to determine product id" if product_id.nil?

    # get the repo id and enable each repository
    repos[:repositories].each do |repo|
      repo.each do |repo_name, attrs|
        # get the repository id for the api call
        repo = build_rest("products/#{product_id}/repository_sets", :get, { :name => repo_name } )
        log(:info, "Inspecting repo: #{repo.inspect}") if @debug == true
        repo_id = repo['results'].first['id']
        raise "Unable to determine repo_id" if repo_id.nil?

        # add payload data
        payload = {}
        payload[:basearch] = attrs[:basearch] unless attrs[:basearch].nil?
        payload[:releasever] = attrs[:releasever] unless attrs[:releasever].nil?

        # enable the repository
        repo_response = build_rest("products/#{product_id}/repository_sets/#{repo_id}/enable", :put, payload ) rescue nil
        log(:info, "Inspecting repo_response: #{repo_response.inspect}")

        # log an error if the repository enable failed
        log(:error, "Unable to enable repository <#{repo_name}>") if repo_response.nil?
      end
    end

    # sync the products
    sync_response = build_rest("products/#{product_id}/sync", :post) rescue nil
    log(:info, "Inspecting sync_response: #{sync_response.inspect}") if @debug == true
    log(:error, "Unable to sync product <#{product}>") if sync_response.nil?
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