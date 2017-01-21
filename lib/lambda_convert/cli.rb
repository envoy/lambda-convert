require 'logger'

require 'aws-sdk'

def main
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

  input_key = SecureRandom.uuid
  output_key = SecureRandom.uuid

  logger.info("Uploading file to s3://#{s3_bucket}/#{input_key}")
  File.open(input_file, 'rb') do |file|
    s3.put_object(bucket: s3_bucket, key: input_key, body: file)
  end
  instruction = {
    schema: 'envoy-convert-instruction',
    original: input_key,
    bucket: 'envoy-development',
    write_options: {
      acl: 'public-read'
    },
    key: output_key,
    args: ['{source}', '-resize', '100x100', '{dest}']
  }
  logger.info("Invoking lambda with instruction #{instruction}")

  resp = aws_lambda.invoke(
    function_name: lambda_function,
    invocation_type: 'RequestResponse',
    payload: JSON.dump(instruction)
  )
  logger.info("Get response of invoke #{resp}")
  raise 'Failed to run convert on Lambda' if resp.status_code != 200
  # TODO: download output file from s3 and write it to output_file path
end
