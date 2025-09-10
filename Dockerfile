FROM zmkfirmware/zmk-dev-arm:3.5-branch

RUN wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq

RUN git config --global --add safe.directory "*"

CMD ["/bin/bash"]
