require "test_helper"

module ActiveCanvas
  class SettingTest < ActiveSupport::TestCase
    setup { Current.reset }
    teardown { Current.reset }

    test "get memoizes within the current request scope" do
      Setting.set("cached_key", "first")
      Current.reset

      assert_sql_count(1) { 3.times { Setting.get("cached_key") } }
    end

    test "get memoizes nil results to avoid repeated misses" do
      Current.reset

      assert_sql_count(1) { 3.times { Setting.get("missing_key") } }
    end

    test "set refreshes the cached value" do
      Setting.set("cache_key", "old")
      assert_equal "old", Setting.get("cache_key")

      Setting.set("cache_key", "new")
      assert_equal "new", Setting.get("cache_key")
    end

    test "Current.reset clears the cache so new requests see fresh data" do
      Setting.set("reset_key", "before")
      assert_equal "before", Setting.get("reset_key")

      Setting.where(key: "reset_key").update_all(value: "after")
      assert_equal "before", Setting.get("reset_key"), "cache should still hold old value"

      Current.reset
      assert_equal "after", Setting.get("reset_key")
    end

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

    test "custom_head_html defaults to empty string" do
      Current.reset
      assert_equal "", Setting.custom_head_html
    end

    test "custom_head_html round-trips via set/get" do
      Setting.custom_head_html = '<meta name="x" content="y">'
      assert_equal '<meta name="x" content="y">', Setting.custom_head_html
    end

    private

    def assert_sql_count(expected, &block)
      queries = []
      callback = ->(_name, _start, _finish, _id, payload) do
        sql = payload[:sql]
        next if payload[:name] == "SCHEMA"
        next if sql.start_with?("BEGIN", "COMMIT", "ROLLBACK", "SAVEPOINT", "RELEASE")
        queries << sql if sql.include?("active_canvas_settings")
      end

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &block)
      assert_equal expected, queries.size, "expected #{expected} settings query/queries, got #{queries.size}:\n#{queries.join("\n")}"
    end
  end
end
