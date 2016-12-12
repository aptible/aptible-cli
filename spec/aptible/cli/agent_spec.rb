require 'spec_helper'

describe Aptible::CLI::Agent do
  before { subject.stub(:ask) }
  before { subject.stub(:save_token) }
  before { allow(subject).to receive(:token_file).and_return 'some.json' }

  describe '#version' do
    it 'should print the version' do
      ClimateControl.modify(APTIBLE_TOOLBELT: nil) do
        version = Aptible::CLI::VERSION
        expect(STDOUT).to receive(:puts).with "aptible-cli v#{version}"
        subject.version
      end
    end

    it 'should print the version (with toolbelt)' do
      ClimateControl.modify(APTIBLE_TOOLBELT: '1') do
        version = Aptible::CLI::VERSION
        expect(STDOUT).to receive(:puts).with "aptible-cli v#{version} toolbelt"
        subject.version
      end
    end
  end

  describe '#login' do
    let(:token) { double('Aptible::Auth::Token') }
    let(:created_at) { Time.now }
    let(:expires_at) { created_at + 1.week }
    let(:output) { [] }

    before do
      m = -> (code) { @code = code }
      OAuth2::Error.send :define_method, :initialize, m
    end
    before { token.stub(:access_token) { 'access_token' } }
    before { token.stub(:created_at) { created_at } }
    before { token.stub(:expires_at) { expires_at } }
    before { allow(subject).to receive(:puts) { |m| output << m } }

    it 'should save a token to ~/.aptible/tokens' do
      Aptible::Auth::Token.stub(:create) { token }
      expect(subject).to receive(:save_token).with('access_token')
      subject.login
    end

    it 'should output the token location and token lifetime' do
      Aptible::Auth::Token.stub(:create) { token }
      subject.login
      expect(output.size).to eq(3)
      expect(output[0]).to eq('')
      expect(output[1]).to match(/written to some\.json/)
      expect(output[2]).to match(/will expire after 7 days/)
    end

    it 'should raise an error if authentication fails' do
      Aptible::Auth::Token.stub(:create).and_raise(OAuth2::Error, 'foo')
      expect do
        subject.login
      end.to raise_error 'Could not authenticate with given credentials: foo'
    end

    it 'should use command line arguments if passed' do
      options = { email: 'test@example.com', password: 'password',
                  lifetime: '30 minutes' }
      subject.stub(:options) { options }
      args = { email: options[:email], password: options[:password],
               expires_in: 30.minutes.seconds }
      expect(Aptible::Auth::Token).to receive(:create).with(args) { token }
      subject.login
    end

    it 'should default to 1 week expiry when OTP is disabled' do
      options = { email: 'test@example.com', password: 'password' }
      subject.stub(:options) { options }
      args = options.dup.merge(expires_in: 1.week.seconds)
      expect(Aptible::Auth::Token).to receive(:create).with(args) { token }
      subject.login
    end

    it 'should fail if the lifetime is invalid' do
      options = { email: 'test@example.com', password: 'password',
                  lifetime: 'this is sparta' }
      subject.stub(:options) { options }

      expect { subject.login }.to raise_error(/Invalid token lifetime/)
    end

    context 'with OTP' do
      let(:email) { 'foo@example.org' }
      let(:password) { 'bar' }
      let(:token) { '123456' }

      context 'with options' do
        before do
          allow(subject).to receive(:options)
            .and_return(email: email, password: password, otp_token: token)
        end

        it 'should authenticate without otp_token_required feedback' do
          expect(Aptible::Auth::Token).to receive(:create)
            .with(email: email, password: password, otp_token: token,
                  expires_in: 12.hours.seconds)
            .once
            .and_return(token)

          subject.login
        end
      end

      context 'with prompts' do
        before do
          [
            [['Email: '], email],
            [['Password: ', echo: false], password],
            [['2FA Token: '], token]
          ].each do |prompt, val|
            expect(subject).to receive(:ask).with(*prompt).once.and_return(val)
          end
        end

        it 'should prompt for an OTP token and use it' do
          expect(Aptible::Auth::Token).to receive(:create)
            .with(email: email, password: password, expires_in: 1.week.seconds)
            .once
            .and_raise(OAuth2::Error, 'otp_token_required')

          expect(Aptible::Auth::Token).to receive(:create)
            .with(email: email, password: password, otp_token: token,
                  expires_in: 12.hours.seconds)
            .once
            .and_return(token)

          subject.login
        end

        it 'should let the user override the default lifetime' do
          expect(Aptible::Auth::Token).to receive(:create)
            .with(email: email, password: password, expires_in: 1.day.seconds)
            .once
            .and_raise(OAuth2::Error, 'otp_token_required')

          expect(Aptible::Auth::Token).to receive(:create)
            .with(email: email, password: password, otp_token: token,
                  expires_in: 1.day.seconds)
            .once
            .and_return(token)

          allow(subject).to receive(:options).and_return(lifetime: '1d')
          subject.login
        end

        it 'should not retry non-OTP errors.' do
          expect(Aptible::Auth::Token).to receive(:create)
            .with(email: email, password: password, expires_in: 1.week.seconds)
            .once
            .and_raise(OAuth2::Error, 'otp_token_required')

          expect(Aptible::Auth::Token).to receive(:create)
            .with(email: email, password: password, otp_token: token,
                  expires_in: 12.hours.seconds)
            .once
            .and_raise(OAuth2::Error, 'foo')

          expect { subject.login }.to raise_error(/Could not authenticate/)
        end
      end
    end
  end

  describe '#nag_toolbelt' do
    let!(:work_dir) { Dir.mktmpdir }
    after { FileUtils.remove_entry work_dir }
    around { |example| ClimateControl.modify(HOME: work_dir) { example.run } }

    let(:nag_dir) { File.join(work_dir, '.aptible') }
    let(:nag_file) { File.join(nag_dir, 'nag_toolbelt') }

    it 'warns if the nag file is not present' do
      expect($stderr).to receive(:puts).at_least(:once)
      subject.send(:nag_toolbelt)
      expect(Integer(File.read(nag_file))).to be_within(5).of(Time.now.utc.to_i)
    end

    it 'warns if the nag file contains an old timestamp' do
      Dir.mkdir(nag_dir)
      File.open(nag_file, 'w') do |f|
        f.write((Time.now.utc.to_i - 1.day).to_i.to_s)
      end

      expect($stderr).to receive(:puts).at_least(:once)
      subject.send(:nag_toolbelt)
    end

    it 'does not warn if the nag file contains a recent timestamp' do
      Dir.mkdir(nag_dir)
      File.open(nag_file, 'w') do |f|
        f.write((Time.now.utc.to_i - 3.hours).to_i.to_s)
      end

      expect($stderr).not_to receive(:puts)
      subject.send(:nag_toolbelt)
    end

    it 'does not warn if the nag file contains a recent timestamp (newline)' do
      # In case a customer writes to the nag file to disable the nag, they're
      # likely to add a trailing newline. Let's just make sure we support that.
      Dir.mkdir(nag_dir)
      File.open(nag_file, 'w') do |f|
        f.write("#{(Time.now.utc.to_i - 3.hours).to_i}\n")
      end

      expect($stderr).not_to receive(:puts)
      subject.send(:nag_toolbelt)
    end

    it 'warns if the nag file contains an invalid timestamp' do
      Dir.mkdir(nag_dir)
      File.open(nag_file, 'w') { |f| f.write('foobar') }

      expect($stderr).to receive(:puts).at_least(:once)
      subject.send(:nag_toolbelt)
    end

    it 'is compatible with itself' do
      expect($stderr).to receive(:puts).once
      2.times { subject.send(:nag_toolbelt) }
    end
  end

  context 'load' do
    it 'loads without git' do
      mocks = File.expand_path('../../../mock', __FILE__)
      bins =  File.expand_path('../../../../bin', __FILE__)
      sep = File::PATH_SEPARATOR
      ClimateControl.modify PATH: [mocks, bins, ENV['PATH']].join(sep) do
        _, _, status = Open3.capture3('aptible version')
        expect(status).to eq(0)
      end
    end
  end
end
