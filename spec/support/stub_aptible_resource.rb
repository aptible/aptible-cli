class StubAptibleResource < OpenStruct
  def headers
    @headers ||= {}
  end

  def find_by_url(_url)
    self
  end

  def href
    self[:href] || "/#{self.class.resource_path}/#{id}"
  end

  def self.resource_path
    name = to_s.sub(/^Stub/, '')
    snake = name.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                .gsub(/([a-z\d])([A-Z])/, '\1_\2')
                .downcase
    if snake.end_with?('y')
      snake.sub(/y$/, 'ies')
    else
      "#{snake}s"
    end
  end
end
