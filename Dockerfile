FROM ruby:1.9.3

# Use a directory called /code in which to store
# this application's files. (The directory name
# is arbitrary and could have been anything.)
WORKDIR /code

# Copy all the application's files into the /code
# directory.
COPY . /code

# Run bundle install to install the Ruby dependencies.
RUN bundle install

RUN git clone https://github.com/BenGardiner/static.mindmup.com
RUN ln -nsf $(which sed) /usr/local/bin/gsed
RUN cd static.mindmup.com && sh pack.sh
RUN cp -Lpr static.mindmup.com/content/img public
RUN cp -Lpr static.mindmup.com/content/font public
RUN cp -Lpr static.mindmup.com/content/pack_latest public

ENV PUBLIC_HOST="http://localhost:5000"
RUN sed -i "s/20161111155712/pack_latest/g" web.rb

RUN gem install foreman
EXPOSE 5000
CMD ["foreman", "start"]

