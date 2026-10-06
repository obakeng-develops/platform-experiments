# Reset Alice and Bob's ephemeral environments to a repeatable story: Alice owns a pinned build
# of posts, while Bob and staging follow the current parent version.
PARENT_VERSIONS.each do |environment_name, versions|
  environment = Environment.find_by!(name: environment_name)
  versions.each do |service_name, version|
    BibeManager.parent_deploy!(
      environment, Service.find_by!(name: service_name), version
    )
  end
end

staging = Environment.find_by!(name: "staging")
posts = Service.find_by!(name: "posts")

{ "alice" => "Alice", "bob" => "Bob" }.each do |name, engineer|
  bibe = Bibe.find_by(name: name)
  bibe ||= BibeManager.create(name: name, engineer: engineer, parent: staging.name)
  target_namespace = "ephemeral-#{name}-#{staging.name}"
  if bibe.namespace != target_namespace
    Kubernetes.delete_namespace(bibe.namespace)
    bibe.update!(namespace: target_namespace)
  end
  BibeManager.new(bibe).provision
end

alice = Bibe.find_by!(name: "alice")
bob = Bibe.find_by!(name: "bob")
alice_manager = BibeManager.new(alice)
bob_manager = BibeManager.new(bob)

alice.bibes_services.each do |bibe_service|
  if bibe_service.service == posts
    alice_manager.pin!(bibe_service, "9.0.0") unless bibe_service.pinned? && bibe_service.version == "9.0.0"
  elsif bibe_service.pinned?
    alice_manager.unpin!(bibe_service)
  end
end

bob.bibes_services.each { |bibe_service| bob_manager.unpin!(bibe_service) if bibe_service.pinned? }

BibeManager.parent_deploy!(staging, posts, "2.5.0")

alice_manager.reconcile
bob_manager.reconcile

puts "Demo is ready: Alice's posts service is pinned at 9.0.0."
puts "Staging and Bob's posts service are at 2.5.0."
