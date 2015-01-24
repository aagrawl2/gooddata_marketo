Gem::Specification.new do |s|
  s.name        = 'gooddata_marketo'
  s.version     = '0.0.1'
  s.date        = '2015-01-01'
  s.summary     = "Marketo SOAP/REST wrapper to CSV/GoodData ADS"
  s.description = "A gem."
  s.authors     = ["Patrick McConlogue"]
  s.email       = 'patrick.mcconlogue@gooddata.com'
  s.files       = `git ls-files`.split("\n")
  s.homepage    = 'https://github.com/thnkr/connectors/tree/master/marketo'

  s.required_ruby_version = '>= 1.9.3'

  s.add_development_dependency  'aws-sdk', '~> 1.61.0'
  s.add_development_dependency  'rubyntlm', '~> 0.3.2'
  s.add_development_dependency  'rest-client', '~> 1.7.2'
  s.add_development_dependency  'pmap', '~> 1.0.2'

  s.add_runtime_dependency 'savon', '= 2.8.0'
  s.add_runtime_dependency  'gooddata', '= 0.6.11'
  s.add_runtime_dependency  'gooddata_datawarehouse', '= 0.0.5'

  s.license     = 'MIT'
end
