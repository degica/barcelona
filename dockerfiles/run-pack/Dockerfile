FROM alpine:3.5

ENV GOPATH /.go
ENV GOBIN $GOPATH/bin
ENV PATH=$GOBIN:$PATH

ADD . /.go/src/app

RUN apk add --no-cache go curl git gcc libc-dev glide \
  && cd $GOPATH/src/app \
  && mkdir -p $GOBIN \
  && mkdir /barcelona \
  && glide install \
  && go build -o /barcelona/barcelona-run --ldflags '-linkmode external -extldflags "-static"' \
  && rm -rf /.go \
  && apk del --purge go curl git gcc libc-dev

VOLUME ["/barcelona"]

CMD ["/bin/true"]
