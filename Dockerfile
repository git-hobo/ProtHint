# ---- Base ----
FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive

# (Optional but helpful) pull security updates first
RUN apt-get update && apt-get -y upgrade && rm -rf /var/lib/apt/lists/*

# System deps: one Perl (no Conda), toolchain for CPAN, Python 3
RUN apt-get update && apt-get install -y --no-install-recommends \
      perl perl-modules build-essential cpanminus \
      python3 python3-distutils \
      ca-certificates procps \
    && rm -rf /var/lib/apt/lists/*

# Install Perl modules into a single global prefix; enforce Thread::Queue >= 3.11
RUN cpanm --notest --quiet --local-lib /usr/local/lib/perl5 \
      MCE::Mutex YAML Math::Utils Thread::Queue \
 && perl -MThread::Queue -e 'die "Thread::Queue too old\n" if $Thread::Queue::VERSION < 3.11; print "Thread::Queue OK $Thread::Queue::VERSION\n"'

# Make modules discoverable
ENV PERL5LIB=/usr/local/lib/perl5/lib/perl5
ENV PATH=/usr/local/lib/perl5/bin:$PATH

# ---- ProtHint tree ----
WORKDIR /opt/ProtHint
COPY . /opt/ProtHint

# Ensure bundled binaries are executable
RUN chmod -R a+rx /opt/ProtHint/bin \
 && chmod -R a+rx /opt/ProtHint/dependencies || true

# Put ProtHint bin/ and dependencies/ on PATH
ENV PROTHINT_HOME=/opt/ProtHint
ENV PATH=$PROTHINT_HOME/bin:$PROTHINT_HOME/dependencies:$PATH

# Create a tiny launcher so aliases all work the same (and PERL5LIB is always set)
RUN printf '%s\n' '#!/bin/sh' \
    'export PERL5LIB="${PERL5LIB:-/usr/local/lib/perl5/lib/perl5}"' \
    'exec python3 /opt/ProtHint/bin/prothint.py "$@"' \
    > /usr/local/bin/prothint && chmod +x /usr/local/bin/prothint \
 && ln -sf /usr/local/bin/prothint /usr/local/bin/prothint.py \
 && ln -sf /usr/local/bin/prothint /usr/local/bin/ProtHint

# GeneMark-ES placeholder (license-restricted; mount at runtime or use --geneMarkGtf)
RUN mkdir -p /opt/ProtHint/dependencies/GeneMarkES
ENV GMES_PATH=/opt/ProtHint/dependencies/GeneMarkES

# (Optional) trim build deps to reduce CVE surface
RUN apt-get purge -y --auto-remove build-essential || true \
 && rm -rf /root/.cpanm

# Runtime defaults
WORKDIR /data
# ENTRYPOINT left unset so you can call any alias directly; examples below
CMD ["prothint", "--help"]
