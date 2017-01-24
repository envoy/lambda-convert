require 'spec_helper.rb'
require 'open3'
require 'tempfile'
require 'English'

RSpec::Matchers.define :eq_image_size do |expected|
  match do |actual|
    (output, status) = Open3.capture2('identify', '-format', '%G', actual)
    status.success? && output.strip == expected
  end

  failure_message do |actual|
    (output, error, status) = Open3.capture3(
      'identify', '-format', '%G', actual
    )
    unless status.success?
      return "expected that #{actual} image size should be #{expected}, " \
        "got error #{error} for identifying image instead"
    end
    "expected that #{actual} image size should be #{expected}, got " \
    "#{output.strip} instead"
  end
end

RSpec.describe LambdaConvert::CLI do
  let(:bin_path) { File.expand_path('../bin/convert', File.dirname(__FILE__)) }
  let(:fixture_folder) do
    File.expand_path('./fixtures', File.dirname(__FILE__))
  end
  let(:envoy_logo) { File.expand_path('./envoy-logo.png', fixture_folder) }

  context 'bad args' do
    before { system(bin_path) }
    subject { $CHILD_STATUS.success? }
    it 'exits with error' do
      expect(subject).to eq(false)
    end
  end

  context 'with CONVERT_CHECK_SCRIPT enabled' do
    subject { Open3.capture2({ 'CONVERT_CHECK_SCRIPT' => '1' }, bin_path) }
    it 'exits with success and yes stdout' do
      expect(subject[0]).to eq("yes\n")
      expect(subject[1].success?).to eq(true)
    end
  end

  context 'simple lambda resize' do
    let(:tempfile) { Tempfile.new('output') }
    subject do
      Open3.capture2(
        { 'CONVERT_DISABLE_FALLBACK' => '1' },
        bin_path, envoy_logo, '-resize', '100x100!', tempfile.path
      )
    end
    it 'resizes the image' do
      expect(subject[1].success?).to eq(true)
      expect(tempfile.path).to eq_image_size('100x100')
    end
  end
end
