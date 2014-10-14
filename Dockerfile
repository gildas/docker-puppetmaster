FROM gildas/puppetbase
MAINTAINER Gildas Cherruel "gildas.cherruel@inin.com"

RUN yum --assumeyes update
RUN yum --assumeyes install puppet-server
RUN gem install --quiet librarian-puppet
