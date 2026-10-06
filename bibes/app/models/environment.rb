# A parent environment (staging or prod) that engineers clone from.
class Environment < ApplicationRecord
  has_many :releases, dependent: :destroy
  has_many :bibes,
           class_name: "Bibe",
           foreign_key: :environment,
           primary_key: :name,
           dependent: :destroy

  validates :name, presence: true, uniqueness: true

  # Every service this environment currently runs, at its current version.
  def version_of(service)
    releases.find_by(service_id: service.id)&.version
  end

  # Fall back to a default so an environment can be created, even if the parent
  # has not released a version for every service yet.
  def version_of!(service, default: "1.0.0")
    version_of(service) || default
  end
end
