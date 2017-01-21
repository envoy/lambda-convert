require 'aws-sdk'

def main
  # TODO: handle special input argument like file.gif[0], file.gif[1],
  # not sure what the format will be
  input_file = ARGV[0]
  output_file = ARGV[-1]
  s3 = Aws::S3::Client.new
  file_name = SecureRandom.uuid
  File.open(input_file, 'rb') do |file|
    s3.put_object(bucket: ENV['S3_BUCKET'], key: file_name, body: file)
  end
  # TODO: invoke convert lambda here
  # TODO: download output file from s3 and write it to output_file path
end
