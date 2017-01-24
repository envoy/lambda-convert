require 'open3'

module LambdaConvert
  # Utils functions
  module Utils
    # find command path array matching given `cmd` name in $PATH
    def self.find_cmd(cmd)
      (ENV['PATH'].split(File::PATH_SEPARATOR).map do |path|
        cmd_path = File.join(path, cmd)
        cmd_path if File.executable?(cmd_path) && !File.directory?(cmd_path)
      end).compact
    end

    def self.original_convert
      find_cmd('convert').find do |path|
        output, = Open3.capture3({ 'CONVERT_CHECK_SCRIPT' => '1' }, path)
        output.strip != 'yes'
      end
    end

    def self.parse_input_path(path)
      # convert command input path could be attached with selecting syntax,
      # let's parse it and return them in an array of
      #
      #     [filename, selecting syntax]
      #
      # ref: https://www.imagemagick.org/script/command-line-processing.php
      match = /([^\[\]]+)(\[(.+)\])?/.match(path)
      [match[1], match[3]]
    end
  end
end
