class BibeServicesController < ApplicationController
  before_action :set_bibe_and_service

  def deploy
    version = params.require(:version).to_s.strip
    unless version.match?(/\A\d+\.\d+\.\d+(?:-[a-zA-Z0-9.-]+)?\z/)
      redirect_to bibe_path(@bibe), alert: "Use a version such as 2.5.0."
      return
    end

    BibeManager.new(@bibe).pin!(@bibe_service, version)
    redirect_to bibe_path(@bibe), notice: "#{@service.name} is now pinned at #{version}."
  rescue Kubernetes::Error => e
    redirect_to bibe_path(@bibe), alert: "Kubernetes could not deploy #{@service.name}: #{e.message}"
  end

  def unpin
    BibeManager.new(@bibe).unpin!(@bibe_service)
    redirect_to bibe_path(@bibe), notice: "#{@service.name} is following #{@bibe.environment} again."
  rescue Kubernetes::Error => e
    redirect_to bibe_path(@bibe), alert: "Kubernetes could not reset #{@service.name}: #{e.message}"
  end

  private

  def set_bibe_and_service
    @bibe = Bibe.find(params[:bibe_id])
    @service = Service.find(params[:service_id])
    @bibe_service = @bibe.bibes_services.find_by!(service: @service)
  end
end
