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
    articles = [ Article.new(1, "a", "x", nil), Article.new(2, "b", "y", nil) ]
    drops = ActiveCanvas::AutoDrop.wrap_collection(articles, attributes: %i[id title])
    assert_equal 2, drops.size
    assert_equal "a", drops.first.invoke_drop("title")
  end

  test "escapes string attributes" do
    drop = ActiveCanvas::AutoDrop.new(Article.new(1, "<b>Hi</b> & bye", "shh", nil), attributes: %i[title])
    assert_equal "&lt;b&gt;Hi&lt;/b&gt; &amp; bye", drop.invoke_drop("title")
  end

  test "html: attributes pass through raw" do
    drop = ActiveCanvas::AutoDrop.new(Article.new(1, "<b>Hi</b>", "shh", nil), attributes: %i[title], html: %i[title])
    assert_equal "<b>Hi</b>", drop.invoke_drop("title")
  end

  test "html_safe strings are not escaped twice" do
    drop = ActiveCanvas::AutoDrop.new(Article.new(1, "<b>Hi</b>".html_safe, "shh", nil), attributes: %i[title])
    assert_equal "<b>Hi</b>", drop.invoke_drop("title")
  end

  test "a whitelisted attribute the record lacks returns nil" do
    drop = ActiveCanvas::AutoDrop.new(Article.new(1, "Hello", "shh", nil), attributes: %i[missing])
    assert_nil drop.invoke_drop("missing")
  end

  test "non-string attributes are returned as they are" do
    drop = ActiveCanvas::AutoDrop.new(Article.new(7, "Hello", "shh", nil), attributes: %i[id])
    assert_equal 7, drop.invoke_drop("id")
  end

  test "escapes strings inside arrays and hashes" do
    drop = ActiveCanvas::AutoDrop.new(Article.new(1, [ "<i>", { k: "<u>" } ], "shh", nil), attributes: %i[title])
    assert_equal [ "&lt;i&gt;", { "k" => "&lt;u&gt;" } ], drop.invoke_drop("title")
  end

  test "symbols are escaped as strings" do
    drop = ActiveCanvas::AutoDrop.new(Article.new(1, :"<s>", "shh", nil), attributes: %i[title])
    assert_equal "&lt;s&gt;", drop.invoke_drop("title")
  end

  test "an attribute that returns an arbitrary object is refused" do
    drop = ActiveCanvas::AutoDrop.new(Article.new(1, Author.new("x", "y"), "shh", nil), attributes: %i[title])
    assert_raises(ActiveCanvas::DataSources::UnsafeData) { drop.invoke_drop("title") }
  end

  test "dates, times, numbers, booleans and nil pass through" do
    [ Date.new(2026, 1, 1), Time.new(2026, 1, 1), 3, 2.5, true, false, nil ].each do |v|
      drop = ActiveCanvas::AutoDrop.new(Article.new(1, v, "shh", nil), attributes: %i[title])
      v.nil? ? assert_nil(drop.invoke_drop("title")) : assert_equal(v, drop.invoke_drop("title"))
    end
  end

  test "to_h exposes the whitelisted attributes and associations" do
    article = Article.new(1, "Hello", "shh", Author.new("Jane", "secret@x.com"))
    drop = ActiveCanvas::AutoDrop.new(article, attributes: %i[id title], associations: { author: %i[name] })
    h = drop.to_h
    assert_equal 1, h["id"]
    assert_equal "Hello", h["title"]
    assert_kind_of ActiveCanvas::AutoDrop, h["author"]
    refute h.key?("secret_field")
  end
end
