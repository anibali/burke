guard 'rspec' do
  watch('^spec/(.*)_spec.rb')
  watch('^lib/(.*)\.rb')          { |m| "spec/#{File.basename(m[1])}_spec.rb" }
  watch('^spec/spec_helper.rb')   { "spec" }
end

