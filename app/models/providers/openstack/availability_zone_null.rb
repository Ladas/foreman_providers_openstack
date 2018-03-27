# An availability zone to represent the cases where Openstack VMs may be
# launched into no availability zone
class Providers::Openstack::AvailabilityZoneNull < Providers::Openstack::AvailabilityZone
  before_create :set_default_values

  def set_default_values
    self.name = "No Availability Zone"
  end
end
