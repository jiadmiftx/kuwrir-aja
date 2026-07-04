# syntax=docker/dockerfile:1

FROM golang:1.25-alpine AS builder
WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /server ./cmd/server

FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata
WORKDIR /app
COPY --from=builder /server /server

# Uploaded files (banners, merchant logos, product photos) are written here
# by internal/upload.Save — must be a mounted volume in docker-compose, or
# every redeploy wipes them since this is otherwise the container's
# ephemeral writable layer.
RUN mkdir -p /app/uploads

EXPOSE 8080
ENTRYPOINT ["/server"]
