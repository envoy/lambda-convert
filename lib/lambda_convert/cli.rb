require 'json'
require 'securerandom'
require 'English'

require 'aws-sdk'

module LambdaConvert
  # `convert` command line tool implementation
  module CLI
    class <<self
      attr_accessor :logger

      def aws_credentials
        if ENV['CONVERT_ACCESS_KEY'] && ENV['CONVERT_SECRET_ACCESS_KEY']
          Aws::Credentials.new(
            ENV['CONVERT_ACCESS_KEY'], ENV['CONVERT_SECRET_ACCESS_KEY']
          )
        end
      end

      def lambda_region
        ENV['CONVERT_LAMBDA_REGION'] || ENV['AWS_REGION']
      end

      def lambda_function
        ENV['CONVERT_LAMBDA_FUNCTION'] || 'image-convert-prod'
      end

      def s3_region
        ENV['CONVERT_S3_REGION'] || ENV['AWS_REGION']
      end

      def s3_bucket
        ENV['CONVERT_S3_BUCKET']
      end

      def s3_key_prefix
        ENV['CONVERT_S3_KEY_PREFIX'] || '_convert_tmp/'
      end

      def s3_client
        @s3_client ||= Aws::S3::Client.new(
          region: s3_region,
          credentials: aws_credentials
        )
      end

      def lambda_client
        @aws_lambda ||= Aws::Lambda::Client.new(
          region: lambda_region,
          credentials: aws_credentials
        )
      end
    end

    def self.upload_file(input_file, input_key)
      logger.info("Uploading file to s3://#{s3_bucket}/#{input_key}")
      File.open(input_file, 'rb') do |file|
        s3_client.put_object(bucket: s3_bucket, key: input_key, body: file)
      end
    end

    def self.invoke_lambda(input_key, input_selecting, args, output_key)
      source = '{source}'
      source += "[#{input_selecting}]" unless input_selecting.nil?
      instruction = {
        schema: 'envoy-convert-instruction',
        original: input_key,
        bucket: s3_bucket,
        write_options: {},
        key: output_key,
        args: [source] + args + ['{dest}']
      }
      logger.info("Invoking lambda with instruction #{instruction}")

      resp = lambda_client.invoke(
        function_name: lambda_function,
        invocation_type: 'RequestResponse',
        payload: JSON.dump(instruction)
      )
      logger.info("Get response of invoke #{resp}")
      raise 'Failed to run convert on Lambda' if resp.status_code != 200
    end

    def self.download_file(output_key, output_file)
      logger.info(
        "Downloading file from s3://#{s3_bucket}/#{output_key} to " \
        "#{output_file}"
      )
      s3_client.get_object(
        response_target: output_file,
        bucket: s3_bucket,
        key: output_key
      )
    end

    def self.delete_files(keys)
      logger.info("Delete files #{keys} from #{s3_bucket}")
      s3_client.delete_objects(
        bucket: s3_bucket,
        delete: {
          objects: keys.map { |key| { key: key } },
          quiet: true
        }
      )
    end

    def self.lambda_convert
      input_file, input_selecting = LambdaConvert::Utils.parse_input_path(
        ARGV[0]
      )
      # Notice: there is also special output file syntax for convert command,
      # but we are not supporting them now, as we probably won't use it
      output_file = ARGV[-1]
      input_key = "#{s3_key_prefix}#{SecureRandom.uuid}"
      output_key = "#{s3_key_prefix}#{SecureRandom.uuid}"

      upload_file(input_file, input_key)
      invoke_lambda(input_key, input_selecting, ARGV[1..-2], output_key)
      download_file(output_key, output_file)

      logger.info('Done')
    ensure
      if !input_key.nil? && !output_key.nil?
        delete_files([input_key, output_key])
      end
    end

    def self.local_convert
      env = ENV.to_h
      # find the original convert bin path
      original_convert = LambdaConvert::Utils.original_convert
      abort('No local convert found') if original_convert.nil?
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
      abort('Invalid arguments') if ARGV.count < 2
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
