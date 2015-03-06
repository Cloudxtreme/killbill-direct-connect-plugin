# killbill-direct-connect-plugin

Kill Bill payment plugin to use the Direct Connect Gateway

# prereqs

Avoid this by using the [vagrant box](https://github.com/NGPVAN/killbill-you-vagrant).

- jruby-1.7.17
- a bunch of other things

# install

Run the following commands from inside this repo's directory. In our standard vagrant box, this is at `/vagrant/plugins/killbill-direct-connect-plugin`.

```sh
rbenv local jruby-1.7.17
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

# rake tasks

You are now ready to run [rake tasks](https://github.com/killbill/killbill-plugin-framework-ruby#rake-tasks). Follow the instructions on that page to build the package. Then run this deploy command:

```sh
rake killbill:deploy[true,/vagrant/bundles/plugins/ruby]
rake d # a shortcut for the above
```

On Windows machines you may enounter file permission errors when attempting to run the deploy task. Running the `rake d` task with `windows` set to `true` will fix the file permissions:

```sh
rake d[true]
```

IMPORTANT: do not run this on Linux/OS X hosts. If you see that every file in the repo has been modified, you will need to do some git magic to revert the file permissions on every file before checking in, while retaining your actual changes. No file should be checked in with permissions `777`.

# Docs

- [Direct Connect API Docs](https://gateway.1directconnect.com/paygate/nethelp/)
- [Direct Connect Test Forms](https://gateway.1directconnect.com/ws/TestForms/TestFormsTOC.aspx)
