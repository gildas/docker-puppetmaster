FROM gildas/puppetbase
MAINTAINER Gildas Cherruel "gildas.cherruel@inin.com"

RUN yum --assumeyes update
RUN sed -i '/^127\.0\.0\.1/s/$/ puppet puppet.local puppetdb puppetdb.local/' /etc/hosts
RUN echo "puppet" > /etc/hostname
RUN echo "DHCP_HOSTNAME=\"puppet\"" > /etc/sysconfig/network-scripts/ifcfg-eth0
RUN systemctl restart network
RUN yum --assumeyes install puppet-server
RUN gem install --quiet --no-document librarian-puppet
RUN rm -rf /etc/puppet
RUN git clone git://github.com/gildas/docker-puppetserver.git /etc/puppet
RUN ln -s /etc/puppet/hiera.yaml /etc/hiera.yaml
RUN chown -R puppet:puppet /var/lib/puppet/client* /var/lib/puppet/lib /var/lib/puppet/ssl
RUN sudo update-rc.d puppetmaster defaults

# Port: ssh
EXPOSE 22
# Port: puppet server
EXPOSE 8140
