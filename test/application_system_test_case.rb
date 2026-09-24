require "test_helper"
require "capybara/rails"

# System specs need a real browser for the GrapesJS editor. Opt in with
# AC_SYSTEM=1 (requires Chrome); without it the rack_test driver is used and
# the editor specs skip themselves.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  if ENV["AC_SYSTEM"]
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
    Capybara.default_max_wait_time = 10 # the editor loads GrapesJS from a CDN
  else
    driven_by :rack_test
  end
end
