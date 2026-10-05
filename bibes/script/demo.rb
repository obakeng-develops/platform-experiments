# Build a two-engineer story that makes the pinning rule visible on first run.
staging = Environment.find_by!(name: "staging")
posts = Service.find_by!(name: "posts")

{ "alice" => "Alice", "bob" => "Bob" }.each do |name, engineer|
  bibe = Bibe.find_by(name: name)
  bibe ||= BibeManager.create(name: name, engineer: engineer, parent: staging.name)
  BibeManager.new(bibe).provision
end

alice = Bibe.find_by!(name: "alice")
bob = Bibe.find_by!(name: "bob")
alice_posts = alice.bibes_services.find_by!(service: posts)

BibeManager.new(alice).pin!(alice_posts, "9.0.0") unless alice_posts.pinned? && alice_posts.version == "9.0.0"
BibeManager.parent_deploy!(staging, posts, "2.5.0")

[ alice, bob ].each { |bibe| BibeManager.new(bibe).reconcile }

puts "Demo is ready: Alice's posts service is pinned at 9.0.0."
puts "Staging and Bob's posts service are at 2.5.0."
