# One service inside one ephemeral environment. Pinning stops it from following its parent.
class BibeService < ApplicationRecord
  belongs_to :bibe
  belongs_to :service

  validates :service_id, uniqueness: { scope: :bibe_id }

  # Name the pod reports back, used to check readiness in the cluster.
  def pod_name
    service.name
  end

  scope :ordered, -> { includes(:service).sort_by { |bs| bs.service.name } }

  # True when this environment's copy has fallen behind its parent.
  def drifted?
    parent = Release.find_by(environment_id: parent_environment_id, service_id: service_id)
    parent.present? && parent.version != version
  end

  def parent_environment_id
    Environment.find_by(name: bibe.environment)&.id
  end

  # True when a synced service has drifted, which is what reconcile fixes.
  def needs_sync?
    !pinned? && drifted?
  end

  def status
    return "pending" unless ready?
    return "pinned" if pinned?
    drifted? ? "drifted" : "in sync"
  end

  # Pod status as reported by the cluster.
  def ready?
    Kubernetes.pod_ready?(bibe.namespace, pod_name)
  end
end
