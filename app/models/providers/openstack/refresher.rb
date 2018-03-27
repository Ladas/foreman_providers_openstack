module Providers
  class Openstack::Refresher < Cloud::Refresher
    def collect_inventory_for_targets(ems, targets)
      targets_with_data = targets.collect do |target|
        target_name = target.try(:name) || target.try(:event_type)

        _log.info("Filtering inventory for #{target.class} [#{target_name}] id: [#{target.id}]...")
        [target, nil]
      end

      targets_with_data
    end

    def parse_targeted_inventory(ems, _target, inventory)
      log_header = format_ems_for_logging(ems)
      _log.debug "#{log_header} Parsing inventory..."
      hashes = Providers::Openstack::Parser.ems_inv_to_hashes(ems)
      hashes = hashes.slice(:instances, :availability_zones) # POC only
      _log.debug "#{log_header} Parsing inventory...Complete"

      hashes
    end

    def preprocess_targets
      super

      # sort the EMSes to be refreshed with cloud managers before other EMSes.
      # since @targets_by_ems_id is a hash, we have to insert the items into a new
      # hash in the order we want them to appear.
      sorted_ems_targets = {}
      # pull out the IDs of cloud managers and reinsert them in a new hash first, to take advantage of preserved insertion order
      cloud_manager_ids = @targets_by_ems_id.keys.select { |key| @ems_by_ems_id[key].kind_of? Providers::Openstack::Manager }
      cloud_manager_ids.each { |ems_id| sorted_ems_targets[ems_id] = @targets_by_ems_id.delete(ems_id) }
      # now that the cloud managers have been removed from @targets_by_ems_id, move the rest of the values
      # over to the new hash and then replace @targets_by_ems_id.
      @targets_by_ems_id.keys.each { |ems_id| sorted_ems_targets[ems_id] = @targets_by_ems_id.delete(ems_id) }
      @targets_by_ems_id = sorted_ems_targets
    end

    def post_process_refresh_classes
      [] #[::Vm, CloudTenant]
    end
  end
end
