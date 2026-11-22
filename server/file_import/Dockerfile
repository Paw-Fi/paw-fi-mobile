FROM dart:3.9.2 AS build
WORKDIR /app
COPY server/file_import/worker.pubspec.yaml ./pubspec.yaml
COPY server/file_import/worker.pubspec.lock ./pubspec.lock
RUN dart pub get --enforce-lockfile
COPY lib/ lib/
COPY server/file_import/*.dart bin/
RUN dart compile exe bin/worker.dart -o /worker

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates qpdf python3-xlrd && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /worker ./worker
COPY lib/l10n/*.arb ./lib/l10n/
COPY server/file_import/legacy_excel.py ./server/file_import/legacy_excel.py
USER 65534:65534
ENTRYPOINT ["/app/worker"]
