# Build stage — compile static Go binary
FROM golang:1.23-alpine AS builder

WORKDIR /src
COPY go.mod ./
# No external dependencies — skip go mod download
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /status-api .

# Runtime stage — scratch for minimal image (~5MB)
FROM scratch

COPY --from=builder /status-api /status-api

EXPOSE 8081

ENTRYPOINT ["/status-api"]
