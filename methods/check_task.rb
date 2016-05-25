require 'yaml'
require_relative 'call_rest.rb'

# keep looping until we have a success response from the task status
def check_task(retries, sleep_time, task_uuid)
  # some logging
  log(:info, "Waiting until task <#{task_uuid}> is complete")

  # get the main config
  main_config = YAML::load_file('../conf/main_config.yml')

  # set some base values for the loop
  index = 1
  task_status = 'started'

  # loop until we receive a success status
  until task_status['success'] do
    # sleep for requested time
    sleep(sleep_time)

    # get the sync status
    # NOTE: we are resetting the rest_base_url because the generic method uses the katello prefix
    # we need to change it back if we make any more rest calls
    @rest_base_url = "https://#{main_config[:rest_sat_server]}/foreman_tasks/api/"
    task_response = build_rest("tasks/#{task_uuid}", :get)
    task_status = task_response['result'] unless task_response.nil?
    if index == retries
      log(:warn, "Reached attempt number #{index}.  Breaking.")
      break
    elsif task_response.nil?
      log(:error, "Unable to determine task_status for task id <#{task_uuid}>")
      break
    end

    # log where we are at in the loop and that state and increment the counter
    log(:info, "Attempt number #{index}: Task Status for <#{task_uuid}> is #{task_status}")
    index += 1
  end

  # reset the rest_base_url to default
  @rest_base_url = "https://#{main_config[:rest_sat_server]}#{main_config[:rest_sat_default_suffix]}"
end
