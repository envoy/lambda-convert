require 'spec_helper.rb'

RSpec.describe LambdaConvert::Utils do
  describe '#parse_input_path' do
    context 'simple file path' do
      let(:path) { '/path/to/file/foo.png' }
      subject { LambdaConvert::Utils.parse_input_path(path) }
      it 'parses path correctly' do
        expect(subject).to eq([path, nil])
      end
    end

    context 'file path with simple selecting syntax' do
      let(:path) { '/path/to/file/foo.png[0]' }
      subject { LambdaConvert::Utils.parse_input_path(path) }
      it 'parses path correctly' do
        expect(subject).to eq(['/path/to/file/foo.png', '0'])
      end
    end

    context 'file path with complex selecting syntax' do
      let(:path) { '/path/to/file/foo.png[600x400+1900+2900]' }
      subject { LambdaConvert::Utils.parse_input_path(path) }
      it 'parses path correctly' do
        expect(subject).to eq(['/path/to/file/foo.png', '600x400+1900+2900'])
      end
    end
  end
end
