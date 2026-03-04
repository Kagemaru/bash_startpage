# Find eligible builder and runner images on Docker Hub. We use global lifecycle (GL)
# tags to avoid major and minor version updates, and "debian-trixie" cause it's a
# temporary fix for OpenSSL compatibility issues with some dependencies.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=1.19.5-erlang-28
# https://hub.docker.com/_/debian?tab=tags&name=trixie
#
# To update, @sha256:... strings can be updated with:
#
#     docker pull hexpm/elixir:1.19.5-erlang-28.3.2-debian-trixie-20250224-slim
#     docker image inspect --format='{{index .RepoDigests 0}}' hexpm/elixir:1.19.5-erlang-28.3.2-debian-trixie-20250224-slim
#
ARG ELIXIR_VERSION=1.19.5
ARG OTP_VERSION=28.3.3
ARG DEBIAN_VERSION=trixie-20260223

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}-slim"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}-slim"

FROM ${BUILDER_IMAGE} AS builder

# Install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Workaround for JIT emulation issues in cross-arch builds
ENV ERL_AFLAGS="+JMsingle true"

# Prepare build dir
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build ENV
ENV MIX_ENV="prod"

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the deps
# to be properly recompiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv

COPY lib lib

# Compile the application first so phoenix-colocated hooks are generated
# into the build path (NODE_PATH includes Mix.Project.build_path())
RUN mix compile

COPY assets assets

# Compile assets (requires phoenix-colocated to already exist in build path)
RUN mix assets.deploy

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# Start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
      apt-get install -y libstdc++6 openssl libncurses6 locales ca-certificates \
      && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:en"
ENV LC_ALL="en_US.UTF-8"

WORKDIR /app
RUN chown nobody /app

# SQLite database directory — mount a volume here to persist data
RUN mkdir -p /data && chown nobody /data
ENV DATABASE_PATH="/data/bash_startpage.db"

# Set runner ENV
ENV MIX_ENV="prod"

# Set default release node for distribution
ENV RELEASE_NODE="bash_startpage@127.0.0.1"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/bash_startpage ./

# Ensure overlay scripts are executable (they aren't by default)
RUN chmod +x /app/bin/server /app/bin/migrate

USER nobody

# Expose HTTP port, EPMD, and Erlang distribution port for Observer
EXPOSE 4000
EXPOSE 4369
EXPOSE 9001

# Volume for SQLite database persistence
VOLUME ["/data"]

CMD ["/app/bin/server"]

# Connecting Erlang Observer remotely:
#
#   Erlang distribution requires mutual EPMD visibility. Use --network=host
#   so the container shares the host's network stack (and EPMD), avoiding
#   the dual-EPMD conflict that occurs with -p port mappings.
#
#   docker run --network=host \
#     -e SECRET_KEY_BASE=... \
#     -e TOKEN_SIGNING_SECRET=... \
#     -e RELEASE_COOKIE=my_cookie \
#     -e RELEASE_NODE=bash_startpage@127.0.0.1 \
#     -e PORT=4001 \
#     -v $(pwd)/data:/data \
#     bash_startpage:latest
#
#   # Connect from your local machine:
#   iex --name observer@127.0.0.1 --cookie my_cookie \
#       --remsh bash_startpage@127.0.0.1
#
#   # Then in the remote shell:
#   :observer.start()
#
#   # Or verify Observer connectivity without a GUI:
#   elixir --name debug@127.0.0.1 --cookie my_cookie -e \
#     'Node.connect(:"bash_startpage@127.0.0.1"); :rpc.call(:"bash_startpage@127.0.0.1", :observer_backend, :sys_info, []) |> IO.inspect()'
