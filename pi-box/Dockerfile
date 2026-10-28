FROM node:24-bookworm-slim

ARG FRP_VERSION=0.71.1

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
     bash ca-certificates git ripgrep sudo curl vim \
     python3 python3-pip python3-venv \
     openssh-server tmux tmuxinator \
  && rm -rf /var/lib/apt/lists/* \
  && ln -sf /usr/bin/python3 /usr/local/bin/python \
  && ln -sf /usr/bin/pip3 /usr/local/bin/pip

# Install frpc (this image targets linux/amd64).
RUN curl -fsSL \
      "https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz" \
      -o /tmp/frp.tar.gz \
 && tar -xzf /tmp/frp.tar.gz -C /tmp \
 && install -m 0755 "/tmp/frp_${FRP_VERSION}_linux_amd64/frpc" /usr/local/bin/frpc \
 && rm -rf /tmp/frp.tar.gz "/tmp/frp_${FRP_VERSION}_linux_amd64"

RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent

# Match the host user; override at build time if needed.
ARG HOST_UID=1000
ARG HOST_GID=1000

# The official Node image already has node at UID/GID 1000.
# Move it out of the way before creating dev.
RUN groupmod -g 1001 node \
  && usermod -u 1001 -g 1001 node \
  && groupadd --gid ${HOST_GID} dev \
  && useradd -m -u ${HOST_UID} -g ${HOST_GID} -s /bin/bash dev \
  && echo 'dev ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/dev \
  && chmod 0440 /etc/sudoers.d/dev \
  && mkdir -p /home/dev/.ssh /home/dev/.pi /home/dev/workspace \
  && chmod 700 /home/dev/.ssh \
  && chown -R ${HOST_UID}:${HOST_GID} /home/dev

# Configure sshd: key-only auth, no root login
RUN mkdir -p /var/run/sshd \
  && sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config \
  && sed -i 's/#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
  && sed -i 's/#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config \
  && printf '\nAllowUsers dev\n' >> /etc/ssh/sshd_config

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh

COPY bashrc /home/dev/.bash_aliases
COPY tmux.conf /home/dev/.config/tmux/tmux.conf
COPY frpc.toml /etc/frpc/frpc.toml

WORKDIR /home/dev/workspace

CMD ["/usr/local/bin/entrypoint.sh"]
