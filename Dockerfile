# The SurrealDB image runs as nonroot (65532) but ships /data owned by root,
# so a fresh volume on /data is not writable. Pre-create it with the right owner.
FROM busybox:1.36.1 AS datadir
RUN mkdir -p /rootfs/data

FROM surrealdb/surrealdb:v2.3.10

LABEL org.opencontainers.image.title="fabric.db"
LABEL org.opencontainers.image.description="Governed state fabric for agentic systems"
LABEL org.opencontainers.image.source="https://github.com/fabric-work/fabric.db"
LABEL org.opencontainers.image.licenses="Apache-2.0"

COPY surrealdb /fabric-db/surrealdb
COPY schema /fabric-db/schema
COPY --from=datadir --chown=65532:65532 /rootfs/ /

EXPOSE 8000

CMD ["start", "--log", "info", "--user", "root", "--pass", "root", "rocksdb:/data/fabric.db"]
