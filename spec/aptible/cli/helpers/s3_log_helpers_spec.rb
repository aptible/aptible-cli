require 'spec_helper'

describe Aptible::CLI::Helpers::S3LogHelpers do
  subject { Class.new.send(:include, described_class).new }
  let(:v2_pfx) { 'mystack/shareable/v2/fakesha' }
  let(:v3_pfx) { 'mystack/shareable/v3/fakesha' }
  let(:v2app) do
    "#{v2_pfx}/apps-321/fakebread-json.log.2022-06-29T18:30:01.bck.gz"
  end
  let(:v2app_rotated) do
    "#{v2_pfx}/apps-321/fakebread-json.1.log.2022-06-29T18:30:01.bck.gz"
  end
  let(:v3app) do
    "#{v3_pfx}/apps-321/service-123/deadbeef-json.log." \
    '2022-08-24T21:12:33.2022-08-24T21:14:38.archived.gz'
  end
  let(:v3db) do
    "#{v3_pfx}/databases-321/fakebread-json.log." \
    '2022-08-24T21:12:33.2022-08-24T21:14:38.archived.gz'
  end
  let(:v3db_rotated) do
    "#{v3_pfx}/databases-321/fakebread-json.log.1." \
    '2022-08-24T21:12:33.2022-08-24T21:14:38.archived.gz'
  end

  describe '#ensure_aws_creds' do
    it 'Raises if no keys are provided via ENV' do
      expect { subject.ensure_aws_creds }
        .to raise_error(Thor::Error, /Missing environment variable/)
    end

    it 'Accepts AWS keypair from the ENV' do
      ENV['AWS_ACCESS_KEY_ID'] = 'foo'
      ENV['AWS_SECRET_ACCESS_KEY'] = 'bar'
      expect { subject.ensure_aws_creds }.to_not raise_error
    end
  end

  describe '#info_from_path' do
    it 'can read app data from v2 paths' do
      result = subject.info_from_path(v2app)
      expect(result[:schema]).to eq('v2')
      expect(result[:shasum]).to eq('fakesha')
      expect(result[:type]).to eq('apps')
      expect(result[:id]).to eq(321)
      expect(result[:service_id]).to be(nil)
      expect(result[:container_id]).to eq('fakebread')
      expect(result[:uploaded_at]).to eq('2022-06-29T18:30:01')
      expect(result[:container_id]).to eq('fakebread')
      expect(result[:start_time]).to be(nil)
      expect(result[:end_time]).to be(nil)
    end

    it 'can read app data from v3 paths' do
      result = subject.info_from_path(v3app)
      expect(result[:schema]).to eq('v3')
      expect(result[:shasum]).to eq('fakesha')
      expect(result[:type]).to eq('apps')
      expect(result[:id]).to eq(321)
      expect(result[:service_id]).to eq(123)
      expect(result[:container_id]).to eq('deadbeef')
      expect(result[:uploaded_at]).to be(nil)
      expect(result[:start_time]).to eq('2022-08-24T21:12:33')
      expect(result[:end_time]).to eq('2022-08-24T21:14:38')
    end

    it 'can read db data from v3 paths' do
      result = subject.info_from_path(v3db)
      expect(result[:schema]).to eq('v3')
      expect(result[:shasum]).to eq('fakesha')
      expect(result[:type]).to eq('databases')
      expect(result[:id]).to eq(321)
      expect(result[:service_id]).to be(nil)
      expect(result[:container_id]).to eq('fakebread')
      expect(result[:uploaded_at]).to be(nil)
      expect(result[:start_time]).to eq('2022-08-24T21:12:33')
      expect(result[:end_time]).to eq('2022-08-24T21:14:38')
    end

    context 'files  that have been rotated by docker (.json.log.1)' do
      it 'can read data from v3 paths' do
        result = subject.info_from_path(v3db_rotated)
        expect(result[:schema]).to eq('v3')
        expect(result[:shasum]).to eq('fakesha')
        expect(result[:type]).to eq('databases')
        expect(result[:id]).to eq(321)
        expect(result[:service_id]).to be(nil)
        expect(result[:container_id]).to eq('fakebread')
        expect(result[:uploaded_at]).to be(nil)
        expect(result[:start_time]).to eq('2022-08-24T21:12:33')
        expect(result[:end_time]).to eq('2022-08-24T21:14:38')
      end
      it 'can read app data from v2 paths' do
        result = subject.info_from_path(v2app)
        expect(result[:schema]).to eq('v2')
        expect(result[:shasum]).to eq('fakesha')
        expect(result[:type]).to eq('apps')
        expect(result[:id]).to eq(321)
        expect(result[:service_id]).to be(nil)
        expect(result[:container_id]).to eq('fakebread')
        expect(result[:uploaded_at]).to eq('2022-06-29T18:30:01')
        expect(result[:container_id]).to eq('fakebread')
        expect(result[:start_time]).to be(nil)
        expect(result[:end_time]).to be(nil)
      end
    end
  end

  describe '#validate_log_search_options' do
    it 'Forces you to identify the files with a supported option' do
      opts = {}
      expect { subject.validate_log_search_options(opts) }
        .to raise_error(Thor::Error, / specify an option to identify/)
    end

    it 'Does not let you pass --string-matches and id options' do
      opts = { string_matches: ['foo'], app_id: 123 }
      expect { subject.validate_log_search_options(opts) }
        .to raise_error(Thor::Error, /cannot pass/)
    end

    it 'Does not let you pass multiple id options' do
      opts = { database_id: 12, app_id: 23 }
      expect { subject.validate_log_search_options(opts) }
        .to raise_error(Thor::Error, /specify only one of/)
    end

    it 'Does not let you use date options with string-matches' do
      opts = { string_matches: 12, start_date: 'foo' }
      expect { subject.validate_log_search_options(opts) }
        .to raise_error(Thor::Error, /cannot be used when searching by string/)
    end

    it 'Does not allow open-ended date range.' do
      opts = { app_id: 123, start_date: 'foo' }
      expect { subject.validate_log_search_options(opts) }
        .to raise_error(Thor::Error, /must pass both/)
    end
  end

  describe '#decrypt_and_translate_s3_file' do
    it 'retrieves, decrypts, and saves to a local file' do
      skip 'Testing effort here is too high'
    end
  end

  describe '#find_s3_files_by_string_match' do
    client_stub = Aws::S3::Client.new(stub_responses: true)
    client_stub.stub_responses(
      :list_buckets, buckets: [{ name: 'bucket' }]
    )
    client_stub.stub_responses(
      :list_objects_v2, contents: [
        { key: 'stack/it/doesnt/matter' },
        { key: 'stack/matter/it/does/not/yoda' }
      ]
    )
    before do
      subject.stub(:s3_client) do
        Aws::S3::Resource.new(region: 'us-east-1', client: client_stub)
      end
    end

    it 'finds files with a single matching string' do
      strings = %w(yoda)
      result = subject.find_s3_files_by_string_match('us-east-1', 'bucket',
                                                     'stack', strings)
      expect(result).to match_array(%w(stack/matter/it/does/not/yoda))
    end

    it 'finds files with two matching strings' do
      strings = %w(it matter)
      result = subject.find_s3_files_by_string_match('us-east-1', 'bucket',
                                                     'stack', strings)
      expect(result).to match_array(%w(stack/it/doesnt/matter
                                       stack/matter/it/does/not/yoda))
    end

    it 'only find files with all matching strings' do
      strings = %w(it yoda)
      result = subject.find_s3_files_by_string_match('us-east-1', 'bucket',
                                                     'stack', strings)
      expect(result).to match_array(%w(stack/matter/it/does/not/yoda))
    end
  end

  describe '#find_s3_files_by_attrs' do
    before do
      client_stub = Aws::S3::Client.new(stub_responses: true)
      client_stub.stub_responses(
        :list_buckets, buckets: [{ name: 'bucket' }]
      )
      client_stub.stub_responses(
        :list_objects_v2, contents: [
          { key: v2app },
          { key: v2app_rotated },
          { key: v3db_rotated },
          { key: v3db },
          { key: v3app }
        ]
      )
      subject.stub(:s3_client) do
        Aws::S3::Resource.new(region: 'us-east-1', client: client_stub)
      end
    end

    it 'can find apps by id' do
      attrs = { type: 'apps', id: 321 }
      result = subject.find_s3_files_by_attrs('us-east-1', 'bucket',
                                              'stack', attrs)
      expect(result).to match_array([v3app, v2app, v2app_rotated])
    end

    it 'can find databases by id' do
      attrs = { type: 'databases', id: 321 }
      result = subject.find_s3_files_by_attrs('us-east-1', 'bucket',
                                              'stack', attrs)
      expect(result).to match_array([v3db, v3db_rotated])
    end

    it 'can find by other attributes of the log file like container id' do
      # The function CAN do this, but the command the user
      # runs cannot at this time
      attrs = { container_id: 'deadbeef' }
      result = subject.find_s3_files_by_attrs('us-east-1', 'bucket',
                                              'stack', attrs)
      expect(result).to match_array([v3app])
    end

    it 'can find files by time range' do
      skip 'TO DO WHILE REVIEW UNDERWAY'
    end
  end
end
