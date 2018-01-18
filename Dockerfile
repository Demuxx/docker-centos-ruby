FROM centos
MAINTAINER me@mbc.io

ENV RUBY_MAJOR 2.4
ENV RUBY_VERSION 2.4.3
ENV RUBY_SRC_HOME /usr/src/ruby

# Build environment for ruby
# Download, verify, and build ruby
RUN yum install -y gcc make openssl-devel libyaml libyaml-devel libffi libffi-devel readline-devel zlib zlib-devel gdbm gdbm-devel ncurses ncurses-devel bzip2 automake autoconf \
  && mkdir -p $RUBY_SRC_HOME \
  && line=`curl -s https://cache.ruby-lang.org/pub/ruby/index.txt | grep "ruby-2.4.3.tar.gz\s"` \
  && shaone=`echo $line | awk '{ print $3 }' | awk '{ print $1 }'` \
  && shatwo=`echo $line | awk '{ print $4 }' | awk '{ print $1 }'` \
  && shafive=`echo $line | awk '{ print $5 }' | awk '{ print $1 }'` \
  && curl -SL -o $RUBY_SRC_HOME/ruby-$RUBY_VERSION.tar.gz "https://cache.ruby-lang.org/pub/ruby/$RUBY_MAJOR/ruby-$RUBY_VERSION.tar.gz" \
  && shaonedl=`sha1sum $RUBY_SRC_HOME/ruby-$RUBY_VERSION.tar.gz | awk '{ print $1 }'` \
  && shatwodl=`sha256sum $RUBY_SRC_HOME/ruby-$RUBY_VERSION.tar.gz | awk '{ print $1 }'` \
  && shafivedl=`sha512sum $RUBY_SRC_HOME/ruby-$RUBY_VERSION.tar.gz | awk '{ print $1 }'` \
  && if [ \( "$shaone" != "$shaonedl" \) -o \( "$shatwo" != "$shatwodl" \) -o \( "$shafive" != "$shafivedl" \) ]; then echo "The download was corrupt"; exit 1; fi \
  && tar -xzC $RUBY_SRC_HOME --strip-components=1 -f $RUBY_SRC_HOME/ruby-$RUBY_VERSION.tar.gz \
  && cd $RUBY_SRC_HOME \
  && rm -f ruby-$RUBY_VERSION.tar.gz \
  && autoconf \
  && ./configure --disable-install-doc \
  && make -j"$(nproc)" \
  && make install \
  && (yum remove -y gcc make openssl-devel libyaml-devel libffi-devel readline-devel zlib-devel gdbm-devel ncurses-devel bzip2 automake autoconf || exit 0) \
  && yum clean -y all \
  && rm -rf $RUBY_SRC_HOME \
  && echo -e "install: --no-ri --no-rdoc\nupdate: --no-ri --no-rdoc" >> /usr/local/etc/gemrc

# Install bundler
ENV GEM_HOME /usr/local/bundle
ENV PATH $GEM_HOME/bin:$PATH
RUN gem install bundler \
      && bundle config --global path "$GEM_HOME" \
      && bundle config --global bin "$GEM_HOME/bin" \
      && rm -rf /usr/local/bundle/cache/*.gem

# Do not create .bundle in apps directory
ENV BUNDLE_APP_CONFIG $GEM_HOME

# Add defaults file for ruby
ADD ruby.conf /etc/default/ruby.conf
ADD profile.d-ruby.sh /etc/profile.d/ruby.sh

WORKDIR /
