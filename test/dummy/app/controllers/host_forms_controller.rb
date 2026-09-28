# Host-app controller used only to prove ActiveCanvas does not turn the host's
# own native ActionText/Trix usage into Lexxy (host isolation). See
# admin_collection_items_lexxy_test.rb.
class HostFormsController < ApplicationController
  def show
  end
end
