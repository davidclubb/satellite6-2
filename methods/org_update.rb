# update the organization with the new information
def org_update(payload)
  log(:info, "Updating organization <#{@org_id}> with payload <#{payload.inspect}>")
  org_response = build_rest("organizations/#{@org_id}", :put, payload)
  log(:info, "Insecting org_response: #{org_response.inspect}") if @debug == true
end