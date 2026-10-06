# What one service is running at in one parent environment.
class Release < ApplicationRecord
  belongs_to :environment
  belongs_to :service

  validates :version, presence: true
  validates :service_id, uniqueness: { scope: :environment_id }
end
