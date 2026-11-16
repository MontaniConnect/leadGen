# Runtime-editable configuration. Database rows override config/settings_defaults.yml.
# Keys are dotted paths, e.g. "prefilter.min_employees".
class Setting < ApplicationRecord
  DEFAULTS_PATH = Rails.root.join("config/settings_defaults.yml")

  validates :key, presence: true, uniqueness: true

  class << self
    def get(key)
      override = find_by(key: key)
      return override.value if override

      default_for(key)
    end

    def set(key, value)
      record = find_or_initialize_by(key: key)
      record.update!(value: value)
      value
    end

    def reset(key)
      where(key: key).destroy_all
    end

    private

    def default_for(key)
      key.to_s.split(".").reduce(defaults) do |node, part|
        node.is_a?(Hash) ? node[part] : nil
      end
    end

    def defaults
      @defaults ||= YAML.load_file(DEFAULTS_PATH)
    end
  end
end
