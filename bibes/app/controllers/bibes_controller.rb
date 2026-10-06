class BibesController < ApplicationController
  before_action :set_bibe, only: %i[show destroy reconcile]

  def show
    @cluster_ready = Kubernetes.ready?
    @services = @bibe.bibes_services.ordered
    @parent = Environment.find_by!(name: @bibe.environment)
    @readiness = @services.to_h { |service| [ service.id, @cluster_ready && service.ready? ] }
  end

  def create
    name = params.require(:bibe).fetch(:name).to_s.parameterize
    engineer = params.require(:bibe).fetch(:engineer).to_s.strip
    parent = params.require(:bibe).fetch(:environment)

    if name.blank? || engineer.blank? || !Environment.exists?(name: parent)
      redirect_to root_path, alert: "Enter an engineer, a BIBE name and a parent environment."
      return
    end

    bibe = BibeManager.create(name: name, engineer: engineer, parent: parent)
    redirect_to bibe_path(bibe), notice: "#{bibe.name} was created. Its pods are starting."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to root_path, alert: e.record.errors.full_messages.to_sentence
  rescue Kubernetes::Error => e
    redirect_to root_path, alert: "Kubernetes could not create the BIBE: #{e.message}"
  end

  def destroy
    BibeManager.new(@bibe).destroy
    redirect_to root_path, notice: "#{@bibe.name} was removed."
  rescue Kubernetes::Error => e
    redirect_to root_path, alert: "Kubernetes could not remove the BIBE: #{e.message}"
  end

  def reconcile
    changed = BibeManager.new(@bibe).reconcile
    message = changed.any? ? "Updated #{changed.to_sentence}." : "All unpinned services are already in sync."
    redirect_to bibe_path(@bibe), notice: message
  rescue Kubernetes::Error => e
    redirect_to bibe_path(@bibe), alert: "Kubernetes could not reconcile this BIBE: #{e.message}"
  end

  private

  def set_bibe
    @bibe = Bibe.find(params[:id])
  end
end
