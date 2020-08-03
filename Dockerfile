FROM amazon/aws-cli:latest

RUN curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm" \
    && yum install -y session-manager-plugin.rpm \
    && rm session-manager-plugin.rpm

RUN yum -y install openssh-server openssh-clients iproute python37 net-tools
RUN mkdir -p /var/run/sshd
RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

COPY dockerfs/tmp/tunneling-script/requirements.txt /tmp/requirements.txt
RUN pip3 install -r /tmp/requirements.txt

RUN /usr/bin/ssh-keygen -A
#RUN echo "LogLevel DEBUG1" >> /etc/ssh/sshd_config

COPY dockerfs/ /


EXPOSE 22

ENTRYPOINT [ "" ]
CMD [ "/bin/bash" ]
