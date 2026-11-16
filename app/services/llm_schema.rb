require "json_schemer"

# A JSON Schema file used three ways: validate replies locally with the full constraints, and send the
# API a copy without the keywords structured outputs don't support (min/max, lengths, item counts).
class LlmSchema
  UNSUPPORTED_BY_API = %w[minimum maximum minItems maxItems minLength maxLength].freeze

  def initialize(path)
    @path = path
  end

  def full
    @full ||= JSON.parse(File.read(@path))
  end

  def for_api
    strip(full)
  end

  # Human-readable problems; empty means valid.
  def errors_for(data)
    @validator ||= JSONSchemer.schema(full)
    @validator.validate(data).map { |error| "#{error['data_pointer']}: #{error['error']}" }
  end

  private

  def strip(node)
    case node
    when Hash then node.except(*UNSUPPORTED_BY_API).transform_values { |value| strip(value) }
    when Array then node.map { |value| strip(value) }
    else node
    end
  end
end
