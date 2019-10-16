require 'spec_helper'

describe Aptible::CLI::Agent do
  before do
    allow(subject).to receive(:ask)
    allow(subject).to receive(:save_token)
    allow(subject).to receive(:token_file).and_return 'some.json'
  end

  describe '#version' do
    it 'should print the version' do
      ClimateControl.modify(APTIBLE_TOOLBELT: nil) do
        version = Aptible::CLI::VERSION
        subject.version
        expect(captured_output_text).to eq("aptible-cli v#{version}\n")
      end
    end

    it 'should print the version (with toolbelt)' do
      ClimateControl.modify(APTIBLE_TOOLBELT: '1') do
        version = Aptible::CLI::VERSION
        subject.version
        expect(captured_output_text).to eq("aptible-cli v#{version} toolbelt\n")
      end
    end
  end

  describe '#login' do
    let(:token) { double('Aptible::Auth::Token') }
    let(:created_at) { Time.now }
    let(:expires_at) { created_at + 1.week }

    def make_oauth2_error(code, ctx = nil)
      parsed = { 'error' => code }
      parsed['exception_context'] = ctx if ctx
      response = double('response', parsed: parsed, body: "error #{code}")
      allow(response).to receive(:error=)
      OAuth2::Error.new(response)
    end

    before do
      allow(token).to receive(:access_token).and_return 'access_token'
      allow(token).to receive(:created_at).and_return created_at
      allow(token).to receive(:expires_at).and_return expires_at
      allow(subject).to receive(:puts) {}
    end

    it 'should save a token to ~/.aptible/tokens' do
      allow(Aptible::Auth::Token).to receive(:create).and_return token
      expect(subject).to receive(:save_token).with('access_token')
      subject.login
    end

    it 'should output the token location and token lifetime' do
      allow(Aptible::Auth::Token).to receive(:create).and_return token
      subject.login
      expect(captured_logs).to match(/token written to.*json/i)
      expect(captured_logs).to match(/expire after 7 days/i)
    end

    it 'should raise an error if authentication fails' do
      allow(Aptible::Auth::Token).to receive(:create)
        .and_raise(make_oauth2_error('foo'))
      expect do
        subject.login
      end.to raise_error 'Could not authenticate with given credentials: foo'
    end

    it 'should use command line arguments if passed' do
      options = { email: 'test@example.com', password: 'password',
                  lifetime: '30 minutes' }
      allow(subject).to receive(:options).and_return options
      args = { email: options[:email], password: options[:password],
               expires_in: 30.minutes.seconds }
      expect(Aptible::Auth::Token).to receive(:create).with(args) { token }
      subject.login
    end

    it 'should default to 1 week expiry when OTP is disabled' do
      options = { email: 'test@example.com', password: 'password' }
      allow(subject).to receive(:options).and_return options
      args = options.dup.merge(expires_in: 1.week.seconds)
      expect(Aptible::Auth::Token).to receive(:create).with(args) { token }
      subject.login
    end

    it 'should fail if the lifetime is invalid' do
      options = { email: 'test@example.com', password: 'password',
                  lifetime: 'this is sparta' }
      allow(subject).to receive(:options).and_return options

      expect { subject.login }.to raise_error(/Invalid token lifetime/)
    end

    context 'with 2FA' do
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
            .and_raise(make_oauth2_error('otp_token_required'))

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
            .and_raise(make_oauth2_error('otp_token_required'))

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
            .and_raise(make_oauth2_error('otp_token_required'))

          expect(Aptible::Auth::Token).to receive(:create)
            .with(email: email, password: password, otp_token: token,
                  expires_in: 12.hours.seconds)
            .once
            .and_raise(make_oauth2_error('foo'))

          expect { subject.login }.to raise_error(/Could not authenticate/)
        end
      end

      context 'with U2F' do
        before do
          allow(subject).to receive(:options)
            .and_return(email: email, password: password)
        end

        it 'shouldn\'t use U2F if not supported' do
          allow(subject).to receive(:which)
            .and_return(nil)

          e = make_oauth2_error(
            'otp_token_required',
            'u2f' => {
              'challenge' => 'some 123',
              'devices' => [
                { 'version' => 'U2F_V2', 'key_handle' => '123' },
                { 'version' => 'U2F_V2', 'key_handle' => '456' }
              ]
            }
          )

          expect(Aptible::Auth::Token).to receive(:create)
            .with(email: email, password: password, expires_in: 1.week.seconds)
            .once
            .and_raise(e)

          expect(Aptible::CLI::Helpers::SecurityKey).not_to \
            receive(:authenticate)

          expect(subject).to receive(:ask).with('2FA Token: ')
            .once
            .and_return(token)

          expect(Aptible::Auth::Token).to receive(:create)
            .with(email: email, password: password, otp_token: token,
                  expires_in: 12.hours.seconds)
            .once
            .and_return(token)

          subject.login
        end

        it 'should call into U2F if supported' do
          allow(subject).to receive(:which).and_return('u2f-host')
          allow(subject).to receive(:ask).with('2FA Token: ') { sleep }

          e = make_oauth2_error(
            'otp_token_required',
            'u2f' => {
              'challenge' => 'some 123',
              'devices' => [
                { 'version' => 'U2F_V2', 'key_handle' => '123' },
                { 'version' => 'U2F_V2', 'key_handle' => '456' }
              ]
            }
          )

          u2f = double('u2f response')

          expect(Aptible::Auth::Token).to receive(:create)
            .with(email: email, password: password, expires_in: 1.week.seconds)
            .once
            .and_raise(e)

          expect(subject).to receive(:puts).with(/security key/i)

          expect(Aptible::CLI::Helpers::SecurityKey).to receive(:authenticate)
            .with(
              'https://auth.aptible.com/',
              'https://auth.aptible.com/u2f/trusted_facets',
              'some 123',
              array_including(
                instance_of(Aptible::CLI::Helpers::SecurityKey::Device),
                instance_of(Aptible::CLI::Helpers::SecurityKey::Device)
              )
            ).and_return(u2f)

          expect(Aptible::Auth::Token).to receive(:create)
            .with(email: email, password: password, u2f: u2f,
                  expires_in: 12.hours.seconds)
            .once
            .and_return(token)

          subject.login
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
      subject.send(:nag_toolbelt)
      expect(Integer(File.read(nag_file))).to be_within(5).of(Time.now.utc.to_i)
      expect(captured_logs).to match(/from source/)
    end

    it 'warns if the nag file contains an old timestamp' do
      Dir.mkdir(nag_dir)
      File.open(nag_file, 'w') do |f|
        f.write((Time.now.utc.to_i - 1.day).to_i.to_s)
      end

      subject.send(:nag_toolbelt)
      expect(captured_logs).to match(/from source/)
    end

    it 'does not warn if the nag file contains a recent timestamp' do
      Dir.mkdir(nag_dir)
      File.open(nag_file, 'w') do |f|
        f.write((Time.now.utc.to_i - 3.hours).to_i.to_s)
      end

      subject.send(:nag_toolbelt)
      expect(captured_logs).to eq('')
    end

    it 'does not warn if the nag file contains a recent timestamp (newline)' do
      # In case a customer writes to the nag file to disable the nag, they're
      # likely to add a trailing newline. Let's just make sure we support that.
      Dir.mkdir(nag_dir)
      File.open(nag_file, 'w') do |f|
        f.write("#{(Time.now.utc.to_i - 3.hours).to_i}\n")
      end

      subject.send(:nag_toolbelt)
      expect(captured_logs).to eq('')
    end

    it 'warns if the nag file contains an invalid timestamp' do
      Dir.mkdir(nag_dir)
      File.open(nag_file, 'w') { |f| f.write('foobar') }

      subject.send(:nag_toolbelt)
      expect(captured_logs).to match(/from source/)
    end

    it 'is compatible with itself' do
      2.times { subject.send(:nag_toolbelt) }
      expect(captured_logs.split("\n").grep(/from source/).size).to eq(1)
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
