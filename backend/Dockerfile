# Build stage
FROM golang:1.23-alpine AS builder

RUN apk add --no-cache gcc musl-dev git

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .

ARG VERSION=dev
ARG COMMIT=none
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-s -w -X main.Version=${VERSION} -X main.Commit=${COMMIT}" \
    -o /server ./cmd/server
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /migrate ./cmd/migrate

# Runtime stage
FROM alpine:3.20

RUN apk add --no-cache ca-certificates tzdata

COPY --from=builder /server /app/server
COPY --from=builder /migrate /app/migrate
COPY --from=builder /app/db/migrations /app/db/migrations

WORKDIR /app
EXPOSE 8080

CMD ["/app/server"]
