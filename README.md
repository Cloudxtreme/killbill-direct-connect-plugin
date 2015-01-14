# killbill-direct-connect-plugin

Kill Bill payment plugin to use the Direct Connect Gateway

# install

```sh
gem install bundler jbundler
rbenv rehash
bundle install
bundle exec jbundle install
```

# tests

```sh
ruby -I"lib:test" spec/direct_connect/unit/direct_connect_gateway_test.rb # run unit tests
ruby -I"lib:test" spec/direct_connect/unit/direct_connect_gateway_test.rb -n "test_method_name" # run unit test "test_method_name"
ruby -I"lib:test" spec/direct_connect/remote/remote_direct_connect_gateway_test.rb # run remote tests
ruby -I"lib:test" spec/direct_connect/remote/remote_direct_connect_gateway_test.rb -n "test_method_name" # run remote test "test_method_name"
```

# Docs

- [Direct Connect API Docs](https://gateway.1directconnect.com/paygate/nethelp/)
