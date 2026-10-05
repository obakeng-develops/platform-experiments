# The service catalogue. This is the one place a service is named, and the only
# file an engineer edits when the backend gains or loses a service.
# Parent environments and the versions they currently run.
PARENTS = {
  "staging" => {
    "gateway" => "2.4.0",
    "posts" => "2.4.0",
    "media" => "2.4.0",
    "notifications" => "1.9.2",
    "db" => "5.1.0",
    "cache" => "7.3.1"
  },
  "prod" => {
    "gateway" => "2.3.7",
    "posts" => "2.3.7",
    "media" => "2.3.7",
    "notifications" => "1.9.2",
    "db" => "5.1.0",
    "cache" => "7.3.1"
  }
}.freeze

Service::CATALOG.each do |name, config|
  service = Service.find_or_create_by!(name: name)
  service.update!(kind: config.fetch(:kind))
end

PARENTS.each do |env_name, versions|
  environment = Environment.find_or_create_by!(name: env_name)
  versions.each do |service_name, version|
    service = Service.find_by!(name: service_name)
    release = Release.find_or_initialize_by(
      environment: environment, service: service
    )
    release.version = version
    release.save!
  end
end

puts "Seeded #{Service.count} services and #{Environment.count} parent environments."
puts "  services: #{Service.pluck(:name).join(', ')}"
puts "  parents:  #{Environment.pluck(:name).join(', ')}"
