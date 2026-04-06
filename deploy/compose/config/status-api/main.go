package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"
)

// ContainerStatus is the JSON response shape for each container.
type ContainerStatus struct {
	Name   string `json:"name"`
	State  string `json:"state"`
	Health string `json:"health"`
	Status string `json:"status"`
}

// dockerGet performs a GET request against the Docker Engine API over the unix socket.
func dockerGet(socketPath, path string) (*http.Response, error) {
	client := &http.Client{
		Timeout: 5 * time.Second,
		Transport: &http.Transport{
			DialContext: func(_ context.Context, _, _ string) (net.Conn, error) {
				return net.Dial("unix", socketPath)
			},
		},
	}
	return client.Get("http://docker" + path)
}

// dockerContainer is a subset of the Docker API container JSON.
type dockerContainer struct {
	Names  []string `json:"Names"`
	State  string   `json:"State"`
	Status string   `json:"Status"`
	Labels map[string]string `json:"Labels"`
}

func getContainerStatuses(socketPath, projectName string) ([]ContainerStatus, error) {
	// Filter by compose project label
	filter := fmt.Sprintf(`{"label":["com.docker.compose.project=%s"]}`, projectName)
	resp, err := dockerGet(socketPath, "/containers/json?all=true&filters="+filter)
	if err != nil {
		return nil, fmt.Errorf("docker API error: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("docker API returned %d", resp.StatusCode)
	}

	var containers []dockerContainer
	if err := json.NewDecoder(resp.Body).Decode(&containers); err != nil {
		return nil, fmt.Errorf("decode error: %w", err)
	}

	statuses := make([]ContainerStatus, 0, len(containers))
	for _, c := range containers {
		name := ""
		if len(c.Names) > 0 {
			name = strings.TrimPrefix(c.Names[0], "/")
		}

		// Skip the init containers (they exit after running)
		if strings.HasSuffix(name, "-init") {
			continue
		}

		health := "none"
		if h, ok := c.Labels["com.docker.compose.container-number"]; ok {
			_ = h // just accessing labels
		}
		// Extract health from Status string (e.g. "Up 2 hours (healthy)")
		statusLower := strings.ToLower(c.Status)
		if strings.Contains(statusLower, "(healthy)") {
			health = "healthy"
		} else if strings.Contains(statusLower, "(unhealthy)") {
			health = "unhealthy"
		} else if strings.Contains(statusLower, "(health: starting)") {
			health = "starting"
		} else if c.State == "running" {
			health = "none"
		}

		statuses = append(statuses, ContainerStatus{
			Name:   name,
			State:  c.State,
			Health: health,
			Status: c.Status,
		})
	}

	return statuses, nil
}

func main() {
	// Health check mode: GET /healthz and exit with appropriate code.
	// Used by Docker HEALTHCHECK since scratch containers have no shell/curl.
	if len(os.Args) > 1 && os.Args[1] == "-healthcheck" {
		port := os.Getenv("PORT")
		if port == "" {
			port = "8081"
		}
		client := &http.Client{Timeout: 3 * time.Second}
		resp, err := client.Get("http://127.0.0.1:" + port + "/healthz")
		if err != nil || resp.StatusCode != http.StatusOK {
			os.Exit(1)
		}
		os.Exit(0)
	}

	socketPath := os.Getenv("DOCKER_SOCKET")
	if socketPath == "" {
		socketPath = "/var/run/docker.sock"
	}

	projectName := os.Getenv("COMPOSE_PROJECT")
	if projectName == "" {
		projectName = "compose"
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8081"
	}

	mux := http.NewServeMux()

	mux.HandleFunc("/api/status", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}

		// CORS — local network appliance, allow any origin
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET")
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("Cache-Control", "no-store")

		statuses, err := getContainerStatuses(socketPath, projectName)
		if err != nil {
			log.Printf("error fetching status: %v", err)
			w.WriteHeader(http.StatusInternalServerError)
			json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
			return
		}

		json.NewEncoder(w).Encode(statuses)
	})

	// CORS preflight
	mux.HandleFunc("/api/", func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodOptions {
			w.Header().Set("Access-Control-Allow-Origin", "*")
			w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
			w.Header().Set("Access-Control-Max-Age", "86400")
			w.WriteHeader(http.StatusNoContent)
			return
		}
		http.NotFound(w, r)
	})

	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain")
		fmt.Fprint(w, "ok\n")
	})

	srv := &http.Server{
		Addr:         ":" + port,
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Graceful shutdown
	go func() {
		sigCh := make(chan os.Signal, 1)
		signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
		<-sigCh
		log.Println("shutting down...")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		srv.Shutdown(ctx)
	}()

	log.Printf("status-api listening on :%s (project=%s)", port, projectName)
	if err := srv.ListenAndServe(); err != http.ErrServerClosed {
		log.Fatalf("server error: %v", err)
	}
}
