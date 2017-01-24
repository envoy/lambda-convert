require 'spec_helper.rb'
require 'open3'
require 'english'
require 'tempfile'

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
    let(:tempfile) { Tempfile.new(['output', '.jpg']) }
    subject do
      Open3.capture2(
        { 'CONVERT_DISABLE_FALLBACK' => '1' },
        bin_path, envoy_logo, '-resize', '100x100', tempfile.path
      )
    end
    it 'resizes the image' do
      # TODO: check the image size
      expect(subject[1].success?).to eq(true)
    end
  end
end
