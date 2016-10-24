# Buffers `say` output strings so that you can assert the entire body of your
# command's output, rather than having to assert it line-by-line.
shared_context 'with output' do
  let(:output) { '' }
  before do
    allow(subject).to receive(:say) do |said|
      output << said + "\n"
    end
  end
end
