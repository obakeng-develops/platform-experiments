require "open3"
require "json"
require "timeout"

# Thin wrapper over kubectl. Every call is a real cluster operation, so the
# dashboard reflects what Kubernetes actually holds rather than what we recorded.
module Kubernetes
  class Error < StandardError; end

  NAMESPACE_PREFIX = "bibe"
  CONTEXT = "minikube"

  module_function

  def capture(*args, **options)
    Open3.capture3("kubectl", "--context=#{CONTEXT}", "--request-timeout=5s", *args, **options)
  end

  def run(*args, namespace: nil)
    cmd = []
    cmd += [ "-n", namespace ] if namespace
    cmd += args
    out, err, status = capture(*cmd)
    raise Error, err unless status.success?
    out
  end

  def contexts
    out = run("config", "get-contexts", "-o", "name")
    out.lines.map(&:strip).reject(&:empty?)
  end

  def current_context
    CONTEXT
  end

  def ready?
    _, _, status = Timeout.timeout(5) { capture("cluster-info") }
    status.success?
  rescue Errno::ENOENT, Timeout::Error
    false
  end

  def namespace_exists?(name)
    _, _, status = capture("get", "namespace", name)
    status.success?
  end

  def create_namespace(name)
    run("create", "namespace", name)
  end

  def delete_namespace(name)
    run("delete", "namespace", name, "--ignore-not-found", "--wait=false")
  end

  # Deployments and Services are named the same, so cluster DNS resolves a
  # service to the copy inside its own namespace and no other.
  def deploy(namespace:, name:, image:, env:)
    manifest = {
      "apiVersion" => "apps/v1",
      "kind" => "Deployment",
      "metadata" => { "name" => name, "labels" => { "app" => name } },
      "spec" => {
        "replicas" => 1,
        "selector" => { "matchLabels" => { "app" => name } },
        "template" => {
          "metadata" => { "labels" => { "app" => name } },
          "spec" => {
            "containers" => [ {
              "name" => name,
              "image" => image,
              "imagePullPolicy" => "Never",
              "env" => env.map { |k, v| { "name" => k.to_s, "value" => v.to_s } }
            } ]
          }
        }
      }
    }

    service_manifest = {
      "apiVersion" => "v1",
      "kind" => "Service",
      "metadata" => { "name" => name },
      "spec" => {
        "selector" => { "app" => name },
        "ports" => [ { "port" => 8080, "targetPort" => 8080 } ]
      }
    }

    apply(manifest, namespace)
    apply(service_manifest, namespace)
  end

  def apply(manifest, namespace)
    json = JSON.generate(manifest)
    cmd = [ "kubectl", "apply", "-n", namespace, "-f", "-" ]
    out, err, status = capture(*cmd.drop(1), stdin_data: json)
    raise Error, err unless status.success?
    out
  end

  def delete_service(namespace, name)
    run("delete", "deployment", name, "--ignore-not-found", namespace: namespace)
    run("delete", "service", name, "--ignore-not-found", namespace: namespace)
  end

  # True once the deployment has a ready replica.
  def pod_ready?(namespace, deployment)
    out, _, status = Timeout.timeout(5) do
      capture(
        "get", "deployment", deployment,
        "-n", namespace, "-o", "jsonpath={.status.readyReplicas}"
      )
    end
    status.success? && out.strip == "1"
  rescue Errno::ENOENT, Timeout::Error
    false
  end

  # Port-forward a BIBE service so a browser can call it directly.
  def port_forward(namespace, deployment, local_port)
    pid = spawn(
      "kubectl", "--context=#{CONTEXT}", "port-forward", "-n", namespace, "svc/#{deployment}",
      "#{local_port}:8080",
      out: File::NULL, err: File::NULL
    )
    pid
  end
end
