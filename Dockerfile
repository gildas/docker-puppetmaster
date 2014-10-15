FROM gildas/puppetbase
MAINTAINER Gildas Cherruel "gildas.cherruel@inin.com"

RUN yum --assumeyes update
RUN curl -sSL http://tinyurl.com/setup-linux-server -o /tmp/setup.sh && bash /tmp/setup.sh
RUN yum --assumeyes install puppet-server
RUN gem install --quiet librarian-puppet
RUN rm -rf /etc/puppet
RUN git clone git://github.com/gildas/docker-puppetserver.git /etc/puppet
