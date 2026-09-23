require "test_helper"

class ActiveCanvas::TemplateRenderer::DirectiveExpanderTest < ActiveSupport::TestCase
  def expand(source)
    ActiveCanvas::TemplateRenderer::DirectiveExpander.new(source).expand
  end

  test "returns the source byte-for-byte when there are no directives" do
    source = "<table><tbody>{% for r in rows %}<tr><td>{{ r }}</td></tr>{% endfor %}</tbody></table>  "
    assert_equal source, expand(source)
  end

  test "wraps a table row loop without moving it out of the table" do
    out = expand(%(<table><tbody><tr data-ac-for="r in rows"><td>{{ r }}</td></tr></tbody></table>))
    assert_includes out, "<tbody>{% for r in rows %}<tr><td>{{ r }}</td></tr>{% endfor %}</tbody>"
    refute_includes out, "data-ac-for"
  end

  test "wraps a condition" do
    out = expand(%(<p data-ac-if="user.admin">secret</p>))
    assert_equal "{% if user.admin %}<p>secret</p>{% endif %}", out
  end

  test "puts the loop outside the condition when both are on one element" do
    out = expand(%(<li data-ac-for="m in team" data-ac-if="m.active">{{ m.name }}</li>))
    assert_equal "{% for m in team %}{% if m.active %}<li>{{ m.name }}</li>{% endif %}{% endfor %}", out
  end

  test "handles a loop nested inside a loop" do
    out = expand(%(<ul data-ac-for="g in groups"><li data-ac-for="m in g.members">{{ m }}</li></ul>))
    assert_equal "{% for g in groups %}<ul>{% for m in g.members %}<li>{{ m }}</li>{% endfor %}</ul>{% endfor %}", out
  end

  test "keeps other attributes and Liquid inside attributes" do
    out = expand(%(<a data-ac-for="l in links" class="x" href="{{ l.url }}">{{ l.title }}</a>))
    assert_equal %({% for l in links %}<a class="x" href="{{ l.url }}">{{ l.title }}</a>{% endfor %}), out
  end

  test "passes Liquid for-loop modifiers through" do
    out = expand(%(<li data-ac-for="m in team limit:3 reversed">x</li>))
    assert_equal "{% for m in team limit:3 reversed %}<li>x</li>{% endfor %}", out
  end

  test "rejects a malformed loop expression with a Liquid syntax error" do
    assert_raises(Liquid::SyntaxError) { expand(%(<li data-ac-for="team">x</li>)) }
    assert_raises(Liquid::SyntaxError) { expand(%(<li data-ac-for="">x</li>)) }
  end

  test "rejects a blank condition" do
    assert_raises(Liquid::SyntaxError) { expand(%(<p data-ac-if="  ">x</p>)) }
  end
end
