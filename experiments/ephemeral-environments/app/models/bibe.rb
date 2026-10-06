# One engineer's isolated copy of the whole backend, backed by a namespace.
class Bibe < ApplicationRecord
  has_many :bibes_services, class_name: "BibeService", dependent: :destroy
  belongs_to :parent_environment,
             class_name: "Environment",
             foreign_key: :environment,
             primary_key: :name

  validates :name, presence: true, uniqueness: true
  validates :namespace, presence: true, uniqueness: true
  validates :name, format: { with: /\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/ }, length: { maximum: 30 }

  scope :ordered, -> { order(:name) }

  def service(name)
    bibes_services.find_by(service: name)
  end

  # Services still following their parent, and the ones an engineer has taken over.
  def pinned
    bibes_services.where(pinned: true).includes(:service).map(&:service)
  end

  def syncing
    bibes_services.where(pinned: false).includes(:service).map(&:service)
  end

  def ready?
    bibes_services.all?(&:ready?)
  end
end
