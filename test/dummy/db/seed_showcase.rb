def upsert_collection(slug, name, fields, rows)
  c = ActiveCanvas::Collection.find_or_initialize_by(slug: slug)
  c.name = name
  c.fields = fields
  c.save!
  rows.each do |row|
    item = c.items.find_or_initialize_by(slug: row["slug"])
    item.draft_data = row.except("slug")
    item.save!
    item.publish!
  end
  c
end

upsert_collection("team", "Team",
  [ { "id" => "name", "label" => "Name", "type" => "text" },
    { "id" => "role", "label" => "Role", "type" => "text" },
    { "id" => "initials", "label" => "Initials", "type" => "text" },
    { "id" => "bio", "label" => "Bio", "type" => "textarea" } ],
  [ { "slug" => "ada",   "name" => "Ada Lovelace",   "role" => "Engineer",  "initials" => "AL", "bio" => "Writes the algorithms that keep our engines humming." },
    { "slug" => "grace", "name" => "Grace Hopper",   "role" => "Scientist", "initials" => "GH", "bio" => "Turns hard problems into compilers and clear words." },
    { "slug" => "alan",  "name" => "Alan Turing",    "role" => "Researcher", "initials" => "AT", "bio" => "Asks the questions the rest of us answer for decades." },
    { "slug" => "mary",  "name" => "Mary Jackson",   "role" => "Designer",  "initials" => "MJ", "bio" => "Shapes every surface so it feels obvious." } ])

upsert_collection("plans", "Plans",
  [ { "id" => "name", "label" => "Name", "type" => "text" },
    { "id" => "price", "label" => "Price", "type" => "number" },
    { "id" => "tagline", "label" => "Tagline", "type" => "text" },
    { "id" => "features", "label" => "Features", "type" => "textarea" },
    { "id" => "featured", "label" => "Featured", "type" => "boolean" } ],
  [ { "slug" => "starter", "name" => "Starter", "price" => 9,  "tagline" => "For a first site.",        "features" => "1 site, 10 pages, community support", "featured" => false },
    { "slug" => "growth",  "name" => "Growth",  "price" => 29, "tagline" => "For teams that publish.",  "features" => "5 sites, unlimited pages, collections, priority support", "featured" => true },
    { "slug" => "scale",   "name" => "Scale",   "price" => 99, "tagline" => "For many brands.",         "features" => "Unlimited sites, SSO, audit log, dedicated support", "featured" => false } ])

upsert_collection("faqs", "FAQs",
  [ { "id" => "question", "label" => "Question", "type" => "text" },
    { "id" => "answer", "label" => "Answer", "type" => "textarea" } ],
  [ { "slug" => "q1", "question" => "Can I change a plan later?",     "answer" => "Yes. Change it any time from the admin. The new price applies from the next month." },
    { "slug" => "q2", "question" => "Where does the data come from?", "answer" => "From collections you edit in the admin, or from data sources your developer registers." },
    { "slug" => "q3", "question" => "Is the content escaped?",        "answer" => "Yes. Every value is escaped before it reaches the template." } ])

content = <<~HTML
  <section class="bg-slate-950 text-white">
    <div class="mx-auto max-w-6xl px-6 py-24 text-center">
      <p class="text-sm font-semibold uppercase tracking-widest text-indigo-400">{{ eyebrow }}</p>
      <h1 class="mt-4 text-5xl font-bold tracking-tight">{{ headline }}</h1>
      <p class="mx-auto mt-6 max-w-2xl text-lg text-slate-300">{{ intro }}</p>
      <div class="mt-10 flex justify-center gap-4">
        <a href="#plans" class="rounded-lg bg-indigo-500 px-6 py-3 font-semibold text-white hover:bg-indigo-400">See plans</a>
        <a href="#team" class="rounded-lg border border-slate-700 px-6 py-3 font-semibold text-slate-200 hover:bg-slate-800">Meet the team</a>
      </div>
    </div>
  </section>

  <section id="team" class="bg-slate-50">
    <div class="mx-auto max-w-6xl px-6 py-20">
      <h2 class="text-3xl font-bold text-slate-900">Meet the team</h2>
      <p class="mt-2 text-slate-600">One card per member of the Team collection.</p>
      <div class="mt-10 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
        <div data-ac-for="member in team" class="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-slate-200">
          <div class="flex h-14 w-14 items-center justify-center rounded-full bg-indigo-100 text-lg font-bold text-indigo-700">{{ member.initials }}</div>
          <h3 class="mt-4 text-lg font-semibold text-slate-900">{{ member.name }}</h3>
          <p class="text-sm font-medium text-indigo-600">{{ member.role }}</p>
          <p class="mt-3 text-sm text-slate-600">{{ member.bio }}</p>
        </div>
      </div>
    </div>
  </section>

  <section id="plans" class="bg-white">
    <div class="mx-auto max-w-6xl px-6 py-20">
      <h2 class="text-3xl font-bold text-slate-900">Simple pricing</h2>
      <p class="mt-2 text-slate-600">The featured plan gets a badge and a stronger border through a condition.</p>
      <div class="mt-10 grid gap-6 lg:grid-cols-3">
        <div data-ac-for="plan in plans" class="relative flex flex-col rounded-2xl border border-slate-200 p-8">
          <span data-ac-if="plan.featured" class="absolute -top-3 left-8 rounded-full bg-indigo-600 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-white">Most popular</span>
          <h3 class="text-xl font-semibold text-slate-900">{{ plan.name }}</h3>
          <p class="mt-1 text-sm text-slate-500">{{ plan.tagline }}</p>
          <p class="mt-6"><span class="text-5xl font-bold text-slate-900">${{ plan.price }}</span><span class="text-slate-500"> / month</span></p>
          <p class="mt-6 flex-1 text-sm text-slate-600">{{ plan.features }}</p>
          <a href="#" class="mt-8 rounded-lg bg-slate-900 px-5 py-3 text-center font-semibold text-white hover:bg-slate-700">Choose {{ plan.name }}</a>
        </div>
      </div>
    </div>
  </section>

  <section class="bg-slate-50">
    <div class="mx-auto max-w-3xl px-6 py-20">
      <h2 class="text-3xl font-bold text-slate-900">Questions</h2>
      <dl class="mt-8 divide-y divide-slate-200">
        <div data-ac-for="faq in faqs" class="py-6">
          <dt class="text-lg font-semibold text-slate-900">{{ faq.question }}</dt>
          <dd class="mt-2 text-slate-600">{{ faq.answer }}</dd>
        </div>
      </dl>
    </div>
  </section>

  <section class="bg-white">
    <div class="mx-auto max-w-6xl px-6 py-20">
      <h2 class="text-3xl font-bold text-slate-900">Filters</h2>
      <p class="mt-2 text-slate-600">A filter changes how a value looks. Add it after the name with a pipe.</p>
      <div class="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <div class="rounded-xl bg-slate-50 p-5 ring-1 ring-slate-200"><code class="text-xs text-indigo-600">upcase</code><p class="mt-2 font-semibold text-slate-900">{{ headline | upcase }}</p></div>
        <div class="rounded-xl bg-slate-50 p-5 ring-1 ring-slate-200"><code class="text-xs text-indigo-600">truncate: 40</code><p class="mt-2 font-semibold text-slate-900">{{ intro | truncate: 40 }}</p></div>
        <div class="rounded-xl bg-slate-50 p-5 ring-1 ring-slate-200"><code class="text-xs text-indigo-600">size</code><p class="mt-2 font-semibold text-slate-900">{{ team.size }} members, {{ plans.size }} plans</p></div>
        <div class="rounded-xl bg-slate-50 p-5 ring-1 ring-slate-200"><code class="text-xs text-indigo-600">default</code><p class="mt-2 font-semibold text-slate-900">{{ empty_text | default: "no value yet" }}</p></div>
        <div class="rounded-xl bg-slate-50 p-5 ring-1 ring-slate-200"><code class="text-xs text-indigo-600">date</code><p class="mt-2 font-semibold text-slate-900">{{ "now" | date: "%B %-d, %Y" }}</p></div>
        <div class="rounded-xl bg-slate-50 p-5 ring-1 ring-slate-200"><code class="text-xs text-indigo-600">map, join</code><p class="mt-2 font-semibold text-slate-900">{{ plans | map: "name" | join: ", " }}</p></div>
        <div class="rounded-xl bg-slate-50 p-5 ring-1 ring-slate-200"><code class="text-xs text-indigo-600">where, first</code><p class="mt-2 font-semibold text-slate-900">{{ plans | where: "featured", true | map: "name" | first }}</p></div>
        <div class="rounded-xl bg-slate-50 p-5 ring-1 ring-slate-200"><code class="text-xs text-indigo-600">plus, times</code><p class="mt-2 font-semibold text-slate-900">Yearly Growth: ${{ 29 | times: 12 | minus: 48 }}</p></div>
        <div class="rounded-xl bg-slate-50 p-5 ring-1 ring-slate-200"><code class="text-xs text-indigo-600">replace, append</code><p class="mt-2 font-semibold text-slate-900">{{ eyebrow | replace: "showcase", "demo" | append: "!" }}</p></div>
      </div>
    </div>
  </section>

  <section class="bg-slate-50">
    <div class="mx-auto max-w-6xl px-6 py-20">
      <h2 class="text-3xl font-bold text-slate-900">Loops with modifiers and counters</h2>
      <p class="mt-2 text-slate-600">Set <strong>Repeat for each</strong> to <code>plan in plans limit:2</code>, <code>reversed</code> or <code>offset:1</code>. Inside a loop, <code>forloop.index</code> counts.</p>
      <div class="mt-10 grid gap-6 lg:grid-cols-3">
        <div class="rounded-2xl bg-white p-6 ring-1 ring-slate-200">
          <h3 class="text-sm font-semibold uppercase tracking-wide text-slate-500">limit:2</h3>
          <ol class="mt-4 space-y-2">
            <li data-ac-for="plan in plans limit:2" class="flex items-center gap-3 text-slate-800"><span class="flex h-7 w-7 items-center justify-center rounded-full bg-indigo-600 text-xs font-bold text-white">{{ forloop.index }}</span>{{ plan.name }}</li>
          </ol>
        </div>
        <div class="rounded-2xl bg-white p-6 ring-1 ring-slate-200">
          <h3 class="text-sm font-semibold uppercase tracking-wide text-slate-500">reversed</h3>
          <ol class="mt-4 space-y-2">
            <li data-ac-for="plan in plans reversed" class="flex items-center gap-3 text-slate-800"><span class="flex h-7 w-7 items-center justify-center rounded-full bg-slate-800 text-xs font-bold text-white">{{ forloop.index }}</span>{{ plan.name }} · ${{ plan.price }}</li>
          </ol>
        </div>
        <div class="rounded-2xl bg-white p-6 ring-1 ring-slate-200">
          <h3 class="text-sm font-semibold uppercase tracking-wide text-slate-500">offset:1, first and last</h3>
          <ul class="mt-4 space-y-2">
            <li data-ac-for="member in team offset:1" class="text-slate-800">{{ member.name }}<span data-ac-if="forloop.first" class="ml-2 rounded bg-emerald-100 px-2 py-0.5 text-xs font-semibold text-emerald-700">first</span><span data-ac-if="forloop.last" class="ml-2 rounded bg-amber-100 px-2 py-0.5 text-xs font-semibold text-amber-700">last</span></li>
          </ul>
        </div>
      </div>

      <h3 class="mt-16 text-xl font-bold text-slate-900">A striped table</h3>
      <p class="mt-2 text-slate-600">The loop sits on the row. <code>cycle</code> alternates the row color, <code>forloop.length</code> gives the total.</p>
      <div class="mt-6 overflow-hidden rounded-2xl bg-white ring-1 ring-slate-200">
        <table class="w-full text-left text-sm">
          <thead class="bg-slate-100 text-xs uppercase tracking-wide text-slate-500"><tr><th class="px-5 py-3">#</th><th class="px-5 py-3">Plan</th><th class="px-5 py-3">Price</th><th class="px-5 py-3">Featured</th></tr></thead>
          <tbody>
            <tr data-ac-for="plan in plans" class="{% cycle 'bg-white', 'bg-slate-50' %} border-t border-slate-100">
              <td class="px-5 py-3 text-slate-500">{{ forloop.index }} of {{ forloop.length }}</td>
              <td class="px-5 py-3 font-semibold text-slate-900">{{ plan.name }}</td>
              <td class="px-5 py-3 text-slate-700">${{ plan.price }}</td>
              <td class="px-5 py-3">{% if plan.featured %}<span class="rounded-full bg-indigo-100 px-2 py-0.5 text-xs font-semibold text-indigo-700">yes</span>{% else %}<span class="text-slate-400">no</span>{% endif %}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </section>

  <section class="bg-white">
    <div class="mx-auto max-w-6xl px-6 py-20">
      <h2 class="text-3xl font-bold text-slate-900">Conditions</h2>
      <p class="mt-2 text-slate-600"><strong>Show only if</strong> takes any Liquid condition: comparisons, <code>and</code>, <code>or</code>, <code>contains</code>. Two elements with opposite conditions make an else.</p>
      <div class="mt-10 grid gap-6 lg:grid-cols-2">
        <div class="rounded-2xl bg-slate-50 p-6 ring-1 ring-slate-200">
          <h3 class="text-sm font-semibold uppercase tracking-wide text-slate-500">Comparison and else</h3>
          <ul class="mt-4 space-y-2">
            <li data-ac-for="plan in plans" class="flex items-center justify-between text-slate-800">
              <span>{{ plan.name }}</span>
              <span data-ac-if="plan.price > 20" class="rounded bg-rose-100 px-2 py-0.5 text-xs font-semibold text-rose-700">premium</span>
              <span data-ac-if="plan.price <= 20" class="rounded bg-emerald-100 px-2 py-0.5 text-xs font-semibold text-emerald-700">budget</span>
            </li>
          </ul>
        </div>
        <div class="rounded-2xl bg-slate-50 p-6 ring-1 ring-slate-200">
          <h3 class="text-sm font-semibold uppercase tracking-wide text-slate-500">contains, and, or</h3>
          <ul class="mt-4 space-y-2">
            <li data-ac-for="member in team" class="text-slate-800">
              {{ member.name }}
              <span data-ac-if="member.role contains 'Eng' or member.role contains 'Res'" class="ml-2 rounded bg-indigo-100 px-2 py-0.5 text-xs font-semibold text-indigo-700">technical</span>
              <span data-ac-if="member.role == 'Designer' and member.initials == 'MJ'" class="ml-2 rounded bg-pink-100 px-2 py-0.5 text-xs font-semibold text-pink-700">design lead</span>
            </li>
          </ul>
        </div>
        <div class="rounded-2xl bg-slate-50 p-6 ring-1 ring-slate-200">
          <h3 class="text-sm font-semibold uppercase tracking-wide text-slate-500">Empty lists</h3>
          <p data-ac-if="faqs.size > 0" class="mt-4 text-slate-800">There are {{ faqs.size }} questions.</p>
          <p data-ac-if="faqs.size == 0" class="mt-4 text-slate-400">No questions yet.</p>
          <p data-ac-if="empty_list.size == 0" class="mt-2 text-slate-400">The <code>empty_list</code> binding is empty, so this line shows and the next one does not.</p>
          <p data-ac-if="empty_list.size > 0" class="mt-2 text-slate-800">This never shows.</p>
        </div>
        <div class="rounded-2xl bg-slate-50 p-6 ring-1 ring-slate-200">
          <h3 class="text-sm font-semibold uppercase tracking-wide text-slate-500">Raw tags: unless, elsif, case, assign, capture</h3>
          <div class="mt-4 space-y-2 text-slate-800">
            <p>{% unless team.size == 0 %}The team is not empty.{% endunless %}</p>
            <p>{% if plans.size > 5 %}Many plans.{% elsif plans.size > 1 %}A few plans.{% else %}One plan.{% endif %}</p>
            <p>{% assign top = plans | last %}Top plan: <strong>{{ top.name }}</strong>{% case top.name %}{% when 'Scale' %} (built for many brands){% when 'Growth' %} (built for teams){% else %} (a good start){% endcase %}</p>
            <p>{% capture greeting %}Hello {{ team.first.name }}{% endcapture %}{{ greeting | append: ", welcome back." }}</p>
          </div>
          <p class="mt-4 text-xs text-slate-500">Raw tags render on the public page and in Preview. The editor canvas shows them as text, so prefer the attribute form where it exists.</p>
        </div>
      </div>
    </div>
  </section>

  <footer class="bg-slate-950 py-10 text-center text-sm text-slate-400">{{ footer }}</footer>
HTML

bindings = {
  "eyebrow"  => { "source" => "_literal", "value" => "Dynamic data showcase" },
  "headline" => { "source" => "_literal", "value" => "Pages that write themselves" },
  "intro"    => { "source" => "_literal", "value" => "Every card, price and answer on this page comes from a collection. Edit the collection, and the page follows." },
  "footer"   => { "source" => "_literal", "value" => "Built with ActiveCanvas dynamic data." },
  "team"     => { "source" => "team",  "params" => { "sort_field" => "name", "sort_dir" => "asc" } },
  "plans"    => { "source" => "plans", "params" => { "sort_field" => "price", "sort_dir" => "asc" } },
  "faqs"     => { "source" => "faqs",  "params" => {} },
  "empty_list" => { "source" => "_literal", "value" => [] },
  "empty_text" => { "source" => "_literal", "value" => "" }
}

page = ActiveCanvas::Page.find_or_initialize_by(slug: "showcase")
page.assign_attributes(title: "Showcase", page_type: ActiveCanvas::PageType.first, published: true,
  template_enabled: true, content: content, content_css: "", content_js: "", content_components: "", bindings: bindings)
page.save!
if ActiveCanvas::TailwindCompiler.available?
  page.update_columns(compiled_tailwind_css: ActiveCanvas::TailwindCompiler.compile_for_page(page), tailwind_compiled_at: Time.current)
end
puts "page #{page.id} /canvas/showcase"
