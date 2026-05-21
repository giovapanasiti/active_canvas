require "test_helper"

class ActiveCanvas::AutoDropTest < ActiveSupport::TestCase
  Article = Struct.new(:id, :title, :secret_field, :author) do
    def published_at; Time.new(2026, 1, 1); end
  end
  Author = Struct.new(:name, :email)

  test "exposes only whitelisted attributes" do
    drop = ActiveCanvas::AutoDrop.new(Article.new(1, "Hello", "shh", nil), attributes: %i[id title])
    assert_equal 1,       drop.invoke_drop("id")
    assert_equal "Hello", drop.invoke_drop("title")
  end

  test "non-whitelisted attribute returns nil" do
    drop = ActiveCanvas::AutoDrop.new(Article.new(1, "Hello", "shh", nil), attributes: %i[id title])
    assert_nil drop.invoke_drop("secret_field")
  end

  test "exposes derived methods (e.g., published_at) if listed" do
    drop = ActiveCanvas::AutoDrop.new(Article.new(1, "Hello", "shh", nil), attributes: %i[published_at])
    assert_equal Time.new(2026, 1, 1), drop.invoke_drop("published_at")
  end

  test "association returns nested AutoDrop with declared attributes" do
    article = Article.new(1, "Hello", "shh", Author.new("Jane", "secret@x.com"))
    drop = ActiveCanvas::AutoDrop.new(
      article,
      attributes: %i[title],
      associations: { author: %i[name] }
    )
    author_drop = drop.invoke_drop("author")
    assert_kind_of ActiveCanvas::AutoDrop, author_drop
    assert_equal "Jane", author_drop.invoke_drop("name")
    assert_nil author_drop.invoke_drop("email")
  end

  test "wraps collections so each element is dropped" do
    articles = [Article.new(1, "a", "x", nil), Article.new(2, "b", "y", nil)]
    drops = ActiveCanvas::AutoDrop.wrap_collection(articles, attributes: %i[id title])
    assert_equal 2, drops.size
    assert_equal "a", drops.first.invoke_drop("title")
  end
end
