require 'rubygems'
require 'json'
require 'English'

require 'aws-sdk'

module LambdaConvert
  # `convert` command line tool implementation
  module CLI
    class <<self
      attr_accessor :logger
    end

    def self.lambda_convert
      s3_region = ENV['CONVERT_S3_REGION'] || ENV['AWS_REGION']
      lambda_region = ENV['CONVERT_LAMBDA_REGION'] || ENV['AWS_REGION']
      aws_credentials = Aws::Credentials.new(
        ENV['CONVERT_ACCESS_KEY'] || ENV['AWS_ACCESS_KEY_ID'],
        ENV['CONVERT_SECRET_ACCESS_KEY'] || ENV['AWS_SECRET_ACCESS_KEY']
      )
      s3_bucket = ENV['CONVERT_S3_BUCKET']
      s3_key_prefix = ENV['CONVERT_S3_KEY_PREFIX'] || '_convert_tmp/'
      lambda_function = ENV['CONVERT_LAMBDA_FUNCTION'] || 'image-convert-prod'

      s3 = Aws::S3::Client.new(
        region: s3_region,
        credentials: aws_credentials
      )
      aws_lambda = Aws::Lambda::Client.new(
        region: lambda_region,
        credentials: aws_credentials
      )

      input_file, input_selecting = LambdaConvert::Utils.parse_input_path(
        ARGV[0]
      )
      # Notice: there is also special output file syntax for convert command,
      # but we are not supporting them now, as we probably won't use it
      output_file = ARGV[-1]

      input_key = "#{s3_key_prefix}#{SecureRandom.uuid}"
      output_key = "#{s3_key_prefix}#{SecureRandom.uuid}"

      logger.info("Uploading file to s3://#{s3_bucket}/#{input_key}")
      File.open(input_file, 'rb') do |file|
        s3.put_object(bucket: s3_bucket, key: input_key, body: file)
      end
      source = '{source}'
      source += "[#{input_selecting}]" unless input_selecting.nil?
      instruction = {
        schema: 'envoy-convert-instruction',
        original: input_key,
        bucket: s3_bucket,
        write_options: {
          acl: 'private'
        },
        key: output_key,
        args: [source] + ARGV[1..-2] + ['{dest}']
      }
      logger.info("Invoking lambda with instruction #{instruction}")

      resp = aws_lambda.invoke(
        function_name: lambda_function,
        invocation_type: 'RequestResponse',
        payload: JSON.dump(instruction)
      )
      logger.info("Get response of invoke #{resp}")
      raise 'Failed to run convert on Lambda' if resp.status_code != 200

      logger.info(
        "Downloading file from s3://#{s3_bucket}/#{output_key} to " \
        "#{output_file}"
      )
      s3.get_object(
        response_target: output_file,
        bucket: s3_bucket,
        key: output_key
      )
      logger.info('Done')
    ensure
      if !s3.nil? && !input_key.nil? && !output_key.nil?
        logger.info(
          "Delete files #{input_key} and #{output_key} from #{s3_bucket}"
        )
        s3.delete_objects(
          bucket: s3_bucket,
          delete: {
            objects: [
              {
                key: input_key
              },
              {
                key: output_key
              }
            ],
            quiet: true
          }
        )
      end
    end

    def self.local_convert
      env = ENV.to_h
      # find the original convert bin path
      original_convert = LambdaConvert::Utils.original_convert
      # we also put a CONVERT_RECURSIVE_FLAG to avoid somehow calling ourself
      # again by mistake
      env['CONVERT_RECURSIVE_FLAG'] = '1'
      logger.info("Running local convert #{original_convert} with args #{ARGV}")
      system(env, *([original_convert] + ARGV))
      abort('Failed to run local convert') unless $CHILD_STATUS.success?
      logger.info('Done')
    end

    def self.main
      abort('Recursive call') if ENV['CONVERT_RECURSIVE_FLAG'] == '1'
      lambda_convert
    rescue StandardError => e

      logger.warn("Failed to convert via lambda, error=#{e}")
      fallback_disabled = (ENV['CONVERT_DISABLE_FALLBACK'].to_i != 0) || false
      if fallback_disabled
        abort("Failed to convert via lambda, no fallback, error=#{e}")
      end
      logger.info('Fallback to local convert command')
      local_convert
    end
  end
end
