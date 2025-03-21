require 'lambda_convert/cli'
require 'lambda_convert/config'
require 'lambda_convert/utils'

module LambdaConvert
  def self.config
    @config ||= Config.new
  end

  def self.configure(&_block)
    yield config
  end
end
