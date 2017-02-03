shared_context 'mock ssh' do
  let(:ssh_mock_outfile) { Tempfile.new('tunnel_spec') }

  after do
    ssh_mock_outfile.close
    ssh_mock_outfile.unlink
  end

  around do |example|
    mocks_path = File.expand_path('../../mock', __FILE__)
    env = {
      PATH: "#{mocks_path}#{File::PATH_SEPARATOR}#{ENV['PATH']}",
      SSH_MOCK_OUTFILE: ssh_mock_outfile.path
    }

    ClimateControl.modify(env) { example.run }
  end

  def read_mock_pid
    File.open(ssh_mock_outfile) do |f|
      return JSON.load(f.read).fetch('pid')
    end
  end

  def read_mock_argv
    File.open(ssh_mock_outfile) do |f|
      return JSON.load(f.read).fetch('argv')
    end
  end

  def read_mock_env
    File.open(ssh_mock_outfile) do |f|
      return JSON.load(f.read).fetch('env')
    end
  end
end
