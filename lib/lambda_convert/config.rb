module LambdaConvert
  class Config
    attr_accessor :access_key,
                  :lambda_function,
                  :lambda_region,
                  :s3_bucket,
                  :s3_key_prefix,
                  :s3_region,
                  :secret_key

    # Set some defaults
    def initialize
      @access_key      = ??
      @secret_key      = ??
      @lambda_function = "image-convert-dev"
      @lambda_region   = "us-east-1"
      @s3_region       = "us-east-1"
      @s3_bucket       = "envoy-development-staging-2"
      @s3_key_prefix   = "_convert_tmp"
    end
  end
end
