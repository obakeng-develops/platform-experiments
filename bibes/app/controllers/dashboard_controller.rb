class DashboardController < ApplicationController
  def show
    @cluster_ready = Kubernetes.ready?
    @cluster_context = Kubernetes.current_context if @cluster_ready
    @cluster_error = nil
    @environments = Environment.includes(releases: :service).order(:name)
    @bibes = Bibe.includes(bibes_services: :service).ordered
    @services = Service.ordered
    @readiness = @bibes.to_h { |bibe| [ bibe.id, @cluster_ready && bibe.ready? ] }
  rescue Kubernetes::Error => e
    @cluster_ready = false
    @cluster_error = e.message
    @environments = Environment.includes(releases: :service).order(:name)
    @bibes = Bibe.includes(bibes_services: :service).ordered
    @services = Service.ordered
    @readiness = @bibes.to_h { |bibe| [ bibe.id, false ] }
  end
end
