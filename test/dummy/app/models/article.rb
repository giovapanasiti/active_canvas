class Article < ApplicationRecord
  scope :published, -> { where(published: true) }
end
