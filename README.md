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
ruby -I"lib:test" spec/direct_connect/unit/direct_connect_gateway_test.rb # run unit tests
ruby -I"lib:test" spec/direct_connect/unit/direct_connect_gateway_test.rb -n "test_method_name" # run unit test "test_method_name"
ruby -I"lib:test" spec/direct_connect/remote/remote_direct_connect_gateway_test.rb # run remote tests
ruby -I"lib:test" spec/direct_connect/remote/remote_direct_connect_gateway_test.rb -n "test_method_name" # run remote test "test_method_name"
```

# Docs

- [Direct Connect API Docs](https://gateway.1directconnect.com/paygate/nethelp/)
