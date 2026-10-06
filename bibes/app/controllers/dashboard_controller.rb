class DashboardController < ApplicationController
  def show
    @cluster_ready = Kubernetes.ready?
    @cluster_context = Kubernetes.current_context if @cluster_ready
    @cluster_error = nil
    load_dashboard_data
  rescue Kubernetes::Error => e
    @cluster_ready = false
    @cluster_error = e.message
    load_dashboard_data
  end

  private

  def load_dashboard_data
    @environments = Environment.includes(releases: :service).order(:name)
    @bibes = Bibe.includes(bibes_services: :service).ordered
    @readiness = @bibes.to_h { |bibe| [ bibe.id, @cluster_ready && bibe.ready? ] }
    @demo_environment = Environment.find_by!(name: "staging")
    @demo_service = Service.find_by!(name: "posts")
    @demo_release = Release.find_by!(environment: @demo_environment, service: @demo_service)
    @demo_next_version = next_patch_version(@demo_release.version)
    @demo_copies = @bibes.filter_map do |bibe|
      next unless bibe.environment == @demo_environment.name

      bibe_service = bibe.bibes_services.find { |copy| copy.service_id == @demo_service.id }
      [ bibe, bibe_service ] if bibe_service
    end
  end

  def next_patch_version(version)
    parts = version.split(".").map(&:to_i)
    return version unless parts.length == 3

    parts[2] += 1
    parts.join(".")
  end
end
