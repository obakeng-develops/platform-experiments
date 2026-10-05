# Create database records from the service catalogue.
Service::CATALOG.each do |name, config|
  service = Service.find_or_create_by!(name: name)
  service.update!(kind: config.fetch(:kind))
end

PARENT_VERSIONS.each do |env_name, versions|
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
