class StubLogDrain < OpenStruct
  def attributes
    # I foresee hard-coding values like this
    # being hard to debug in the future,
    # so sorry if you're here and cursing me, but
    # I can't think of a better way to fake this.
    {
      'drain_username' => drain_username,
      'drain_host' => drain_host,
      'drain_port' => drain_port,
      'url' => url
    }
  end
end

Fabricator(:log_drain, from: :stub_log_drain) do
  id { sequence(:log_drain_id) }
  account
  links do |attrs|
    hash = {
      account: OpenStruct.new(
        href: "/accounts/#{attrs[:account].id}"
      )
    }
    OpenStruct.new(hash)
  end

  after_create { |drain| drain.account.log_drains << drain }
end
