# Creates and reconciles BIBEs in the cluster.
#
# The rule this implements: a BIBE copies its parent, and keeps following it
# service by service. Deploying your own build of a service pins that service.
# Everything else keeps syncing.
class BibeManager
  IMAGE = "bibes-service:latest"

  attr_reader :bibe

  def initialize(bibe)
    @bibe = bibe
  end

  # Create the namespace and one pod per service, each at the parent's version.
  def self.create(name:, engineer:, parent:)
    raise Kubernetes::Error, "Minikube is unavailable. Start it with `minikube start`." unless Kubernetes.ready?

    parent_env = Environment.find_by!(name: parent)
    namespace = "bibe-#{name}-#{parent}"
    if Kubernetes.namespace_exists?(namespace)
      raise Kubernetes::Error, "Namespace #{namespace} already exists. Inspect it before creating this BIBE."
    end

    bibe = nil
    namespace_created = false
    begin
      ActiveRecord::Base.transaction do
        bibe = Bibe.create!(
          name: name,
          engineer: engineer,
          namespace: namespace,
          environment: parent
        )

        Service.ordered.each do |service|
          BibeService.create!(
            bibe: bibe,
            service: service,
            version: parent_env.version_of!(service),
            pinned: false
          )
        end
      end

      Kubernetes.create_namespace(namespace)
      namespace_created = true
      new(bibe).provision
      bibe
    rescue StandardError
      begin
        Kubernetes.delete_namespace(namespace) if namespace_created && Kubernetes.namespace_exists?(namespace)
      rescue Kubernetes::Error
        # Keep the original provisioning error. The cluster can be cleaned up manually.
      end
      bibe.destroy if bibe&.persisted?
      raise
    end
  end

  def provision
    Kubernetes.create_namespace(bibe.namespace) unless Kubernetes.namespace_exists?(bibe.namespace)
    bibe.bibes_services.each { |bs| deploy(bs) }
  end

  def deploy(bibe_service)
    Kubernetes.deploy(
      namespace: bibe.namespace,
      name: bibe_service.pod_name,
      image: IMAGE,
      env: env_for(bibe_service)
    )
  end

  # An engineer deploys their own build. That service stops following the parent.
  def pin!(bibe_service, version)
    bibe_service.update!(version: version, pinned: true)
    deploy(bibe_service)
    bibe_service
  end

  # Drop back to whatever the parent runs and start following it again.
  def unpin!(bibe_service)
    parent = Environment.find_by!(name: bibe.environment)
    bibe_service.update!(
      version: parent.version_of!(bibe_service.service), pinned: false
    )
    deploy(bibe_service)
    bibe_service
  end

  # Bring every unpinned service up to the parent's version. Pinned services
  # are left alone, which is what makes a BIBE safe to keep using.
  def reconcile
    parent = Environment.find_by!(name: bibe.environment)
    synced = []

    bibe.bibes_services.ordered.each do |bs|
      next unless bs.needs_sync?

      bs.update!(version: parent.version_of(bs.service))
      deploy(bs)
      synced << bs.service.name
    end

    synced
  end

  def destroy
    Kubernetes.delete_namespace(bibe.namespace)
    bibe.destroy
  end

  # Push a new version to a parent environment, as a merge to main would.
  def self.parent_deploy!(environment, service, version)
    release = Release.find_or_initialize_by(
      environment: environment, service: service
    )
    release.version = version
    release.save!
    release
  end

  private

  def env_for(bibe_service)
    {
      SERVICE_NAME: bibe_service.service.name,
      SERVICE_VERSION: bibe_service.version,
      BIBE_NAME: bibe.name,
      BIBE_NAMESPACE: bibe.namespace,
      BIBE_PARENT: bibe.environment,
      BIBE_PINNED: bibe_service.pinned.to_s
    }.merge(dependency_env(bibe_service.service))
  end

  # Declare this service's dependencies so it can reach them over cluster DNS.
  def dependency_env(service)
    service.dependencies.to_h { |name| [ "DEP_#{name.upcase}", name ] }
  end
end
