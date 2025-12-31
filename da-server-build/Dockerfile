FROM golang:1.22-alpine
RUN apk add --no-cache git make gcc musl-dev
RUN git clone https://github.com/evstack/celestia-da.git /src
WORKDIR /src
RUN go mod download
# Find and build the main package
RUN find . -name "main.go"
RUN go build -o /usr/local/bin/da-server . || go build -o /usr/local/bin/da-server ./cmd/celestia-da || go build -o /usr/local/bin/da-server ./cmd/...
ENTRYPOINT ["da-server"]