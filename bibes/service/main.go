// A BIBE workload pod. Every service in every environment runs this same binary,
// with its role supplied by environment variables.
package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"sort"
	"strings"
	"time"
)

func env(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

// identity is what this pod knows about itself.
func identity() map[string]any {
	return map[string]any{
		"service":   env("SERVICE_NAME", "unknown"),
		"version":   env("SERVICE_VERSION", "0.0.0"),
		"namespace": env("BIBE_NAMESPACE", "default"),
		"env":       env("BIBE_PARENT", "unknown"),
		"bibe":      env("BIBE_NAME", ""),
		"pinned":    os.Getenv("BIBE_PINNED") == "true",
		"pod":       env("HOSTNAME", "unknown"),
	}
}

// deps returns the declared dependencies, found in DEP_<NAME> vars.
func deps() []string {
	var found []string
	for _, e := range os.Environ() {
		key, value, ok := strings.Cut(e, "=")
		if ok && strings.HasPrefix(key, "DEP_") {
			found = append(found, value)
		}
	}
	sort.Strings(found)
	return found
}

// probe calls a dependency over cluster DNS and reports what came back.
func probe(name string) map[string]any {
	url := fmt.Sprintf("http://%s:8080/version", name)
	client := &http.Client{Timeout: 3 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return map[string]any{"service": name, "reachable": false, "error": err.Error()}
	}
	defer resp.Body.Close()

	out := map[string]any{"service": name, "reachable": true}
	var body map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&body); err == nil {
		out["version"] = body["version"]
		out["namespace"] = body["namespace"]
		out["bibe"] = body["bibe"]
	}
	return out
}

func main() {
	mux := http.NewServeMux()

	mux.HandleFunc("/version", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(identity())
	})

	// /deps proves service discovery stays inside this BIBE. Every response in
	// the tree should report this pod's own namespace.
	mux.HandleFunc("/deps", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		results := []map[string]any{}
		for _, d := range deps() {
			results = append(results, probe(d))
		}
		json.NewEncoder(w).Encode(map[string]any{"self": identity(), "dependencies": results})
	})

	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		self := identity()
		fmt.Fprintf(w, "%s %s in %s\n", self["service"], self["version"], self["namespace"])
	})

	http.ListenAndServe(":8080", mux)
}
