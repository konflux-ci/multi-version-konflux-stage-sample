FROM registry.access.redhat.com/ubi9/ubi:9.4-1123.1719560047 as builder

COPY . /src
RUN \
  cd /src && \
  echo echo "\"Hello World\"" > entrypoint.sh && \
  chmod +x entrypoint.sh

FROM registry.access.redhat.com/ubi9/ubi-micro:9.4-9

LABEL name="Branch exposing image"
LABEL description="A container image that shows the branch it was built from"
LABEL com.redhat.component="konflux-multibranch-sample"
LABEL io.k8s.description="A container image that shows the branch it was built from"
LABEL io.k8s.display-name="Branch exposing image"

COPY --from=builder /src/entrypoint.sh /
COPY LICENSE /licenses/

USER 65532:65532
ENTRYPOINT /entrypoint.sh
