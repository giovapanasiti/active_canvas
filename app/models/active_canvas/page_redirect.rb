module ActiveCanvas
  class PageRedirect < ApplicationRecord
    belongs_to :page

    validates :from_slug, presence: true, uniqueness: true
  end
end
