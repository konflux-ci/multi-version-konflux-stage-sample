FROM registry.access.redhat.com/ubi9/ubi:9.5-1734081738 as builder

RUN \
  yum install -y \
    --disablerepo="*" \
    --enablerepo=ubi-9-baseos-rpms,ubi-9-appstream-rpms \
    git && \
  yum clean all
COPY . /src
RUN \
  cd /src && \
  echo echo "\"$(git branch --show-current)\"" > entrypoint.sh && \
  chmod +x entrypoint.sh

FROM registry.access.redhat.com/ubi9/ubi-micro:9.5-1734513256

LABEL name="Branch exposing image"
LABEL description="A container image that shows the branch it was built from"
LABEL com.redhat.component="konflux-multibranch-sample"
LABEL io.k8s.description="A container image that shows the branch it was built from"
LABEL io.k8s.display-name="Branch exposing image"

COPY --from=builder /src/entrypoint.sh /
COPY LICENSE /licenses/

USER 65532:65532
ENTRYPOINT /entrypoint.sh
