FROM swift:5.4-focal as build

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update && apt-get -q dist-upgrade -y \
    && apt-get install -y --no-install-recommends libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY ./Package.* ./
RUN swift package resolve
COPY . .
RUN swift build -c release

WORKDIR /app
COPY ./_Packages/ ./_Packages/
RUN (cd ./_Packages/ && swift build -c release)

WORKDIR /staging
RUN cp "$(swift build --package-path /build -c release --show-bin-path)/Run" ./
RUN [ -d /build/Public ] && { mv /build/Public ./Public && chmod -R a-w ./Public; } || true
RUN [ -d /build/Resources ] && { mv /build/Resources ./Resources && chmod -R a-w ./Resources && chmod 744 ./Resources/Temp; } || true

FROM swift:5.4-focal
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true && \
    apt-get -q update && apt-get -q dist-upgrade -y && rm -r /var/lib/apt/lists/*

RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor

WORKDIR /app
COPY --from=build --chown=vapor:vapor /staging /app
COPY --from=build --chown=vapor:vapor /app /app

USER vapor:vapor
EXPOSE $PORT

ENTRYPOINT ["./Run"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0"]
