class StubStack < OpenStruct; end

Fabricator(:stack, from: :stub_stack) do
  name 'foo'
  version 'v2'

  apps { [] }
  databases { [] }
end
