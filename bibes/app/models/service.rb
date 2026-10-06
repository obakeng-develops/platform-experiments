class Service < ApplicationRecord
  CATALOG = {
    "gateway" => { kind: "gateway", dependencies: %w[posts media notifications] },
    "posts" => { kind: "app", dependencies: %w[db cache] },
    "media" => { kind: "app", dependencies: %w[db cache] },
    "notifications" => { kind: "app", dependencies: %w[db cache] },
    "db" => { kind: "store", dependencies: [] },
    "cache" => { kind: "store", dependencies: [] }
  }.freeze

  has_many :releases, dependent: :destroy
  has_many :bibes_services, dependent: :destroy

  validates :name, presence: true, uniqueness: true

  scope :ordered, -> { order(:name) }

  def dependencies
    CATALOG.fetch(name).fetch(:dependencies)
  end
end
