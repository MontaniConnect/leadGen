class Contact < ApplicationRecord
  SOURCES = %w[apollo site manual].freeze

  belongs_to :company
  has_many :messages, dependent: :nullify

  validates :source, inclusion: { in: SOURCES }

  def full_name
    [ first_name, last_name ].compact_blank.join(" ")
  end
end
