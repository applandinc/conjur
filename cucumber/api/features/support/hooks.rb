# frozen_string_literal: true

# Generates random unique names
#
require 'haikunator'
require 'fileutils'

# Reset the DB between each test
#
# Prior to this hook, our tests had hidden coupling.  This ensures each test is
# run independently.
Before do
  @user_index = 0
  @host_index = 0

  Role.truncate(cascade: true)
  Secret.truncate
  Credentials.truncate

  Slosilo.each do |k,v|
    unless %w(authn:rspec authn:cucumber).member?(k)
      Slosilo.send(:keystore).adapter.model[k].delete
    end
  end
  
  Account.find_or_create_accounts_resource
  admin_role = Role.create(role_id: "cucumber:user:admin")
  Credentials.new(role: admin_role).save(raise_on_save_failure: true)

  # Save env to revert to it after the test
  @env = {}
  ENV.each do |key, value|
    @env[key] = value
  end
end

Around('~@appmap-disable') do |scenario, block|
  # Cribbed from v5 version of ActiveSupport:Inflector#parameterize:
  # https://github.com/rails/rails/blob/v5.2.4/activesupport/lib/active_support/inflector/transliterate.rb#L92
  sanitize_filename = lambda do |fname, separator: '_'|
    # Replace accented chars with their ASCII equivalents.
    fname = fname.encode('utf-8', invalid: :replace, undef: :replace, replace: '_')

    # Turn unwanted chars into the separator.
    fname.gsub!(/[^a-z0-9\-_]+/i, separator)

    re_sep = Regexp.escape(separator)
    re_duplicate_separator        = /#{re_sep}{2,}/
    re_leading_trailing_separator = /^#{re_sep}|#{re_sep}$/i

    # No more than one of the separator in a row.
    fname.gsub!(re_duplicate_separator, separator)

    # Finally, Remove leading/trailing separator.
    fname.gsub(re_leading_trailing_separator, '')
  end

  record_resource = rest_resource({})['_appmap']['record']

  recording_status = JSON.parse(record_resource.get.body)
  if recording_status['enabled']
    warn 'AppMap recording is already in progress. Terminating it now...'
    record_resource.delete
  end

  record_resource.post({})
  begin
    block.call
  ensure
    appmap = JSON.parse(record_resource.delete.body)
  end

  # <Cucumber::Core::Ast::Location::Precise: cucumber/api/features/authenticate.feature:1>
  feature_group = scenario.feature.location.to_s.split('/').last.split('.')[0]

  appmap['metadata'].tap do |m|
    m['name'] = scenario.name
    m['feature'] = scenario.feature.name
    m['feature_group'] = feature_group
    m['labels'] ||= []
    m['labels'] += (scenario.tags&.map(&:name) || [])
    m['frameworks'] ||= []
    m['frameworks'] << {
      'name' => 'cucumber',
      'version' => Gem.loaded_specs['cucumber']&.version&.to_s
    }
    m['recorder'] = {
      'name' => 'cucumber'
    }
  end

  fname = sanitize_filename.call([ scenario.feature.name, scenario.name ].join('_'))

  FileUtils.mkdir_p 'tmp/appmap/cucumber'
  File.write(File.join('tmp/appmap/cucumber', "#{fname}.appmap.json"), JSON.generate(appmap))
end

After do
  FileUtils.remove_dir('cuke_export') if Dir.exists?('cuke_export')

  # Revert to original env
  @env.each do |key, value|
    ENV[key] = value
  end
end

Before("@logged-in") do
  random_login = Haikunator.haikunate
  @current_user = create_user(random_login, admin_user)
end

Before("@logged-in-admin") do
  @current_user = admin_user
end
