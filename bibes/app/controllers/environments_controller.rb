class EnvironmentsController < ApplicationController
  def deploy
    @environment = Environment.find(params[:environment_id])
    @service = Service.find(params[:service_id])
    version = params.require(:version).to_s.strip

    unless version.match?(/\A\d+\.\d+\.\d+(?:-[a-zA-Z0-9.-]+)?\z/)
      redirect_to root_path, alert: "Use a version such as 2.5.0."
      return
    end

    BibeManager.parent_deploy!(@environment, @service, version)
    updated = @environment.bibes.includes(:bibes_services).flat_map do |bibe|
      BibeManager.new(bibe).reconcile
    end

    redirect_to root_path, notice: "#{@environment.name} now runs #{@service.name} #{version}. #{updated.size} BIBE service(s) synced."
  rescue Kubernetes::Error => e
    redirect_to root_path, alert: "The parent version was saved, but a BIBE could not sync: #{e.message}"
  end
end
