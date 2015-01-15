# killbill-direct-connect-plugin

Kill Bill payment plugin to use the Direct Connect Gateway

# prereqs

Avoid this by using the [vagrant box](https://github.com/NGPVAN/killbill-you-vagrant).

- jruby-1.7.17
- a bunch of other things

# install

```sh
mkdir -p ~/.killbill
cp spec/direct_connect_fixtures.yml ~/.killbill/direct_connect_fixtures.yml # edit the ~ one to have your credentials
rbenv install jruby-1.7.17 # make sure the right version is installed
gem install bundler jbundler # install prereq executables
rbenv rehash # make sure executables are available
bundle install # install gems
bundle exec jbundle install # install jars
```

Do not edit `spec/direct_connect_fixtures.yml`. Instead, edit the copied one at `~/.killbill/direct_connect_fixtures.yml`.

# tests

```sh
rake test:unit # run all gateway unit tests
rake test:unit[test_failed_purchase] # run gateway unit test 'test_failed_purchase'
rake test:remote # run all gateway remote tests
rake test:remote[test_failed_purchase] # run gateway remote test 'test_failed_purchase'
```

# Docs

- [Direct Connect API Docs](https://gateway.1directconnect.com/paygate/nethelp/)
