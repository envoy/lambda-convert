require 'logger'
require 'rubygems'
require 'English'

require 'aws-sdk'

def lambda_convert
  logger = Logger.new(STDERR)

  aws_region = ENV['CONVERT_REGION'] || ENV['AWS_REGION']
  aws_credentials = Aws::Credentials.new(
    ENV['CONVERT_ACCESS_KEY'] || ENV['AWS_ACCESS_KEY_ID'],
    ENV['CONVERT_SECRET_ACCESS_KEY'] || ENV['AWS_SECRET_ACCESS_KEY']
  )
  s3_bucket = ENV['CONVERT_S3_BUCKET']
  lambda_function = ENV['CONVERT_LAMBDA_FUNCTION'] || 'image-convert-dev'

  s3 = Aws::S3::Client.new(
    region: aws_region,
    credentials: aws_credentials
  )
  aws_lambda = Aws::Lambda::Client.new(
    region: aws_region,
    credentials: aws_credentials
  )

  # TODO: handle special input argument like file.gif[0], file.gif[1],
  # not sure what the format will be
  input_file = ARGV[0]
  output_file = ARGV[-1]

  input_key = "_convert_tmp/#{SecureRandom.uuid}"
  output_key = "_convert_tmp/#{SecureRandom.uuid}"

  logger.info("Uploading file to s3://#{s3_bucket}/#{input_key}")
  File.open(input_file, 'rb') do |file|
    s3.put_object(bucket: s3_bucket, key: input_key, body: file)
  end
  instruction = {
    schema: 'envoy-convert-instruction',
    original: input_key,
    bucket: s3_bucket,
    write_options: {
      acl: 'private'
    },
    key: output_key,
    # TODO: deal with special input argumnet like file.gif[0]
    args: ['{source}'] + ARGV[1..-2] + ['{dest}']
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
    "Downloading file from s3://#{s3_bucket}/#{output_key} to #{output_file}"
  )
  s3.get_object(
    response_target: output_file,
    bucket: s3_bucket,
    key: output_key
  )
  logger.info('Done')
ensure
  logger.info("Delete files #{input_key} and #{output_key} from #{s3_bucket}")
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

def local_convert
  logger = Logger.new(STDERR)
  env = ENV.to_h
  # remove Gem bindir from the path, so that we won't invoke ourself
  path = ENV['PATH'].split(File::PATH_SEPARATOR) - [Gem.bindir]
  env['PATH'] = path.join(File::PATH_SEPARATOR)
  # we also put a CONVERT_RECURSIVE_FLAG to avoid somehow calling ourself again
  # by mistake
  env['CONVERT_RECURSIVE_FLAG'] = '1'
  logger.info("Running local convert with args #{ARGV}")
  system(env, *(['convert'] + ARGV))
  abort('Failed to run local convert') unless $CHILD_STATUS.success?
  logger.info('Done')
end

def main
  abort('Recursive call') if ENV['CONVERT_RECURSIVE_FLAG'] == '1'
  lambda_convert
rescue StandardError => e
  logger = Logger.new(STDERR)
  logger.warn("Failed to convert via lambda, error=#{e}")
  fallback_disabled = (ENV['CONVERT_DISABLE_FALLBACK'].to_i != 0) || false
  if fallback_disabled
    abort("Failed to convert via lambda, no fallback, error=#{e}")
  end
  logger.info('Fallback to local convert command')
  local_convert
end
