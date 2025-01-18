# Build stage
FROM golang:bullseye AS builder

WORKDIR /build
COPY . .

RUN go mod download
RUN CGO_ENABLED=1 go build -buildmode=c-shared -o libtailscale.so

# Final stage
FROM debian:bullseye-slim
COPY --from=builder /build/libtailscale.so ./
