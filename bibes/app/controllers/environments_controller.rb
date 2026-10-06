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
    outcomes = @environment.bibes.includes(:bibes_services).map do |bibe|
      updated = BibeManager.new(bibe).reconcile
      copy = bibe.bibes_services.find_by!(service: @service)

      if copy.pinned?
        "#{bibe.engineer} stayed at #{copy.version} (pinned)"
      elsif updated.include?(@service.name)
        "#{bibe.engineer} updated to #{copy.version}"
      else
        "#{bibe.engineer} was already at #{copy.version}"
      end
    end

    outcome_summary = outcomes.any? ? outcomes.to_sentence : "No ephemeral environments follow this parent yet"
    redirect_to root_path, notice: "#{@environment.name.capitalize} released #{@service.name} #{version}. #{outcome_summary}."
  rescue Kubernetes::Error => e
    redirect_to root_path, alert: "The parent version was saved, but an environment could not sync: #{e.message}"
  end
end
