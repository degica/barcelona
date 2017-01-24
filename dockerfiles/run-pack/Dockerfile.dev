FROM alpine:3.4

ENV GOPATH /.go
ENV GOBIN $GOPATH/bin
ENV PATH=$GOBIN:$PATH
ENV SRCPATH $GOPATH/src/app

RUN mkdir -p $SRCPATH
WORKDIR $SRCPATH
RUN mkdir -p $GOBIN
RUN mkdir -p /barcelona
RUN apk add --no-cache go curl git gcc libc-dev
RUN curl https://glide.sh/get | sh

ADD glide.yaml $SRCPATH
ADD glide.lock $SRCPATH
RUN glide install

ADD . $SRCPATH
RUN go build -o /barcelona/barcelona-run --ldflags '-linkmode external -extldflags "-static"'

VOLUME ["/barcelona"]
