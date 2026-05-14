require "test_helper"

module ActiveCanvas
  class SettingTest < ActiveSupport::TestCase
    test "set retries when another process inserts the same key concurrently" do
      Setting.where(key: "race_key").delete_all

      call_count = 0
      original_save = Setting.instance_method(:save!)

      Setting.define_method(:save!) do |*args, **kwargs|
        call_count += 1
        if call_count == 1
          # Simulate the row appearing between find_or_initialize_by and save!
          self.class.connection.insert(
            "INSERT INTO active_canvas_settings (key, value, created_at, updated_at) " \
              "VALUES ('race_key', 'from_other_process', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
          )
          raise ActiveRecord::RecordNotUnique, "simulated unique violation"
        end
        original_save.bind(self).call(*args, **kwargs)
      end

      assert_nothing_raised do
        Setting.set("race_key", "from_this_process")
      end

      assert_equal "from_this_process", Setting.get("race_key")
      assert_equal 2, call_count, "expected exactly one retry"
    ensure
      Setting.remove_method(:save!) if Setting.instance_methods(false).include?(:save!)
      Setting.where(key: "race_key").delete_all
    end

    test "set re-raises RecordNotUnique after a second failure" do
      Setting.where(key: "stuck_key").delete_all

      Setting.define_method(:save!) do |*_args, **_kwargs|
        raise ActiveRecord::RecordNotUnique, "persistent violation"
      end

      assert_raises(ActiveRecord::RecordNotUnique) do
        Setting.set("stuck_key", "value")
      end
    ensure
      Setting.remove_method(:save!) if Setting.instance_methods(false).include?(:save!)
      Setting.where(key: "stuck_key").delete_all
    end
  end
end
