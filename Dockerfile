FROM registry.redhat.io/openshift4/ose-cli

COPY system-create-install.sh /usr/local/bin/system-create-install.sh
RUN chmod +x /usr/local/bin/system-create-install.sh

# Install jq
RUN curl -O -L https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 && \
    chmod +x jq-linux64 && \
    mv jq-linux64 /usr/local/bin/jq

ENTRYPOINT ["/usr/local/bin/system-create-install.sh"]