module ActiveCanvas
  class FormSubmission < ApplicationRecord
    belongs_to :page

    attribute :data, default: {}

    validates :form_key, presence: true
  end
end
