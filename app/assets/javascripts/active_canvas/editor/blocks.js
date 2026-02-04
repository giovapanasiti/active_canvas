/**
 * ActiveCanvas Editor - Custom Blocks
 * Framework-aware blocks for Tailwind, Bootstrap 5, and vanilla CSS
 */

(function() {
  'use strict';

  window.ActiveCanvasEditor = window.ActiveCanvasEditor || {};

  /**
   * Register all custom blocks with the editor
   * @param {Object} editor - GrapeJS editor instance
   * @param {Object} config - Editor configuration (optional)
   */
  function addCustomBlocks(editor, config) {
    const bm = editor.BlockManager;
    const framework = config?.cssFramework || 'tailwind';

    // Add universal blocks (work with any framework)
    addUniversalBlocks(bm);

    // Add framework-specific blocks
    switch (framework) {
      case 'bootstrap5':
        addBootstrapBlocks(bm);
        break;
      case 'custom':
        addVanillaBlocks(bm);
        break;
      case 'tailwind':
      default:
        addTailwindBlocks(bm);
        break;
    }
  }

  /**
   * Universal blocks that work with any framework
   */
  function addUniversalBlocks(bm) {
    bm.add('div', {
      label: 'Div Block',
      category: 'Layout',
      content: '<div></div>',
      attributes: { class: 'gjs-fonts gjs-f-b1' }
    });

    bm.add('link-block', {
      label: 'Link',
      category: 'Basic',
      content: '<a href="#">Link text</a>'
    });

    bm.add('image', {
      label: 'Image',
      category: 'Basic',
      content: { type: 'image' },
      activate: true
    });

    bm.add('video', {
      label: 'Video',
      category: 'Basic',
      content: { type: 'video' },
      activate: true
    });
  }

  /**
   * Tailwind CSS blocks
   */
  function addTailwindBlocks(bm) {
    // --- Layout ---
    bm.add('section', {
      label: 'Section',
      category: 'Layout',
      content: '<section class="py-16 px-4"><div class="max-w-6xl mx-auto"></div></section>'
    });

    bm.add('container', {
      label: 'Container',
      category: 'Layout',
      content: '<div class="max-w-6xl mx-auto px-4"></div>'
    });

    bm.add('flex-row', {
      label: 'Flex Row',
      category: 'Layout',
      content: '<div class="flex flex-row gap-4"></div>'
    });

    bm.add('flex-col', {
      label: 'Flex Column',
      category: 'Layout',
      content: '<div class="flex flex-col gap-4"></div>'
    });

    bm.add('grid-2', {
      label: 'Grid 2 Cols',
      category: 'Layout',
      content: '<div class="grid grid-cols-1 md:grid-cols-2 gap-6"></div>'
    });

    bm.add('grid-3', {
      label: 'Grid 3 Cols',
      category: 'Layout',
      content: '<div class="grid grid-cols-1 md:grid-cols-3 gap-6"></div>'
    });

    bm.add('grid-4', {
      label: 'Grid 4 Cols',
      category: 'Layout',
      content: '<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6"></div>'
    });

    // --- Typography ---
    bm.add('heading-1', {
      label: 'Heading 1',
      category: 'Typography',
      content: '<h1 class="text-5xl font-bold">Heading 1</h1>'
    });

    bm.add('heading-2', {
      label: 'Heading 2',
      category: 'Typography',
      content: '<h2 class="text-4xl font-bold">Heading 2</h2>'
    });

    bm.add('heading-3', {
      label: 'Heading 3',
      category: 'Typography',
      content: '<h3 class="text-3xl font-semibold">Heading 3</h3>'
    });

    bm.add('paragraph', {
      label: 'Paragraph',
      category: 'Typography',
      content: '<p class="text-base text-gray-600 leading-relaxed">Your paragraph text goes here. Edit this text to add your own content.</p>'
    });

    bm.add('text-lead', {
      label: 'Lead Text',
      category: 'Typography',
      content: '<p class="text-xl text-gray-500 leading-relaxed">A larger lead paragraph for introductions and important text.</p>'
    });

    // --- Buttons ---
    bm.add('button-primary', {
      label: 'Primary Button',
      category: 'Buttons',
      content: '<a href="#" class="inline-block bg-blue-600 text-white px-6 py-3 rounded-lg font-semibold hover:bg-blue-700 transition-colors">Button</a>'
    });

    bm.add('button-secondary', {
      label: 'Secondary Button',
      category: 'Buttons',
      content: '<a href="#" class="inline-block bg-gray-200 text-gray-800 px-6 py-3 rounded-lg font-semibold hover:bg-gray-300 transition-colors">Button</a>'
    });

    bm.add('button-outline', {
      label: 'Outline Button',
      category: 'Buttons',
      content: '<a href="#" class="inline-block border-2 border-blue-600 text-blue-600 px-6 py-3 rounded-lg font-semibold hover:bg-blue-600 hover:text-white transition-colors">Button</a>'
    });

    // --- Hero Sections ---
    bm.add('hero-simple', {
      label: 'Hero Simple',
      category: 'Sections',
      content: `
        <section class="py-20 px-4 bg-gray-900 text-white text-center">
          <div class="max-w-4xl mx-auto">
            <h1 class="text-5xl font-bold mb-6">Welcome to Your Site</h1>
            <p class="text-xl text-gray-300 mb-8">A beautiful subtitle that describes what you do and why visitors should care.</p>
            <a href="#" class="inline-block bg-blue-600 text-white px-8 py-3 rounded-lg font-semibold hover:bg-blue-700">Get Started</a>
          </div>
        </section>
      `
    });

    bm.add('hero-split', {
      label: 'Hero Split',
      category: 'Sections',
      content: `
        <section class="py-16 px-4">
          <div class="max-w-6xl mx-auto grid md:grid-cols-2 gap-12 items-center">
            <div>
              <h1 class="text-4xl font-bold mb-4">Build Something Amazing</h1>
              <p class="text-lg text-gray-600 mb-6">Create beautiful, responsive websites without writing code. Drag, drop, and customize.</p>
              <a href="#" class="inline-block bg-blue-600 text-white px-6 py-3 rounded-lg font-semibold">Learn More</a>
            </div>
            <div class="bg-gray-200 rounded-lg aspect-video flex items-center justify-center">
              <span class="text-gray-500">Image Placeholder</span>
            </div>
          </div>
        </section>
      `
    });

    bm.add('hero-centered', {
      label: 'Hero Centered',
      category: 'Sections',
      content: `
        <section class="py-24 px-4 bg-gradient-to-br from-blue-600 to-purple-700 text-white text-center">
          <div class="max-w-3xl mx-auto">
            <span class="inline-block px-4 py-1 bg-white/20 rounded-full text-sm font-medium mb-6">New Release</span>
            <h1 class="text-5xl md:text-6xl font-bold mb-6">The Future is Here</h1>
            <p class="text-xl text-white/80 mb-8">Experience the next generation of web building with our powerful visual editor.</p>
            <div class="flex flex-col sm:flex-row gap-4 justify-center">
              <a href="#" class="bg-white text-blue-600 px-8 py-3 rounded-lg font-semibold hover:bg-gray-100">Get Started Free</a>
              <a href="#" class="border-2 border-white text-white px-8 py-3 rounded-lg font-semibold hover:bg-white/10">Watch Demo</a>
            </div>
          </div>
        </section>
      `
    });

    // --- Feature Sections ---
    bm.add('features-grid', {
      label: 'Features Grid',
      category: 'Sections',
      content: `
        <section class="py-16 px-4 bg-gray-50">
          <div class="max-w-6xl mx-auto">
            <h2 class="text-3xl font-bold text-center mb-12">Features</h2>
            <div class="grid md:grid-cols-3 gap-8">
              <div class="text-center p-6">
                <div class="w-12 h-12 bg-blue-600 rounded-lg mx-auto mb-4"></div>
                <h3 class="text-xl font-semibold mb-2">Feature One</h3>
                <p class="text-gray-600">Description of this amazing feature and why it matters.</p>
              </div>
              <div class="text-center p-6">
                <div class="w-12 h-12 bg-blue-600 rounded-lg mx-auto mb-4"></div>
                <h3 class="text-xl font-semibold mb-2">Feature Two</h3>
                <p class="text-gray-600">Description of this amazing feature and why it matters.</p>
              </div>
              <div class="text-center p-6">
                <div class="w-12 h-12 bg-blue-600 rounded-lg mx-auto mb-4"></div>
                <h3 class="text-xl font-semibold mb-2">Feature Three</h3>
                <p class="text-gray-600">Description of this amazing feature and why it matters.</p>
              </div>
            </div>
          </div>
        </section>
      `
    });

    bm.add('features-alternating', {
      label: 'Features Alt',
      category: 'Sections',
      content: `
        <section class="py-16 px-4">
          <div class="max-w-6xl mx-auto space-y-16">
            <div class="grid md:grid-cols-2 gap-12 items-center">
              <div class="bg-gray-200 rounded-lg aspect-video"></div>
              <div>
                <h3 class="text-2xl font-bold mb-4">Feature Title</h3>
                <p class="text-gray-600 mb-4">Detailed description of this feature and its benefits for users.</p>
                <a href="#" class="text-blue-600 font-semibold">Learn more →</a>
              </div>
            </div>
            <div class="grid md:grid-cols-2 gap-12 items-center">
              <div class="order-2 md:order-1">
                <h3 class="text-2xl font-bold mb-4">Another Feature</h3>
                <p class="text-gray-600 mb-4">Detailed description of this feature and its benefits for users.</p>
                <a href="#" class="text-blue-600 font-semibold">Learn more →</a>
              </div>
              <div class="bg-gray-200 rounded-lg aspect-video order-1 md:order-2"></div>
            </div>
          </div>
        </section>
      `
    });

    // --- Cards ---
    bm.add('card', {
      label: 'Card',
      category: 'Components',
      content: `
        <div class="bg-white rounded-lg shadow-md overflow-hidden max-w-sm">
          <div class="bg-gray-200 h-48 flex items-center justify-center">
            <span class="text-gray-500">Image</span>
          </div>
          <div class="p-6">
            <h3 class="text-xl font-semibold mb-2">Card Title</h3>
            <p class="text-gray-600 mb-4">Some description text for this card component.</p>
            <a href="#" class="text-blue-600 font-semibold">Learn more →</a>
          </div>
        </div>
      `
    });

    bm.add('cards-row', {
      label: 'Cards Row',
      category: 'Sections',
      content: `
        <section class="py-16 px-4">
          <div class="max-w-6xl mx-auto grid md:grid-cols-3 gap-8">
            <div class="bg-white rounded-lg shadow-md overflow-hidden">
              <div class="bg-gray-200 h-48"></div>
              <div class="p-6">
                <h3 class="text-xl font-semibold mb-2">Card One</h3>
                <p class="text-gray-600">Description text for this card.</p>
              </div>
            </div>
            <div class="bg-white rounded-lg shadow-md overflow-hidden">
              <div class="bg-gray-200 h-48"></div>
              <div class="p-6">
                <h3 class="text-xl font-semibold mb-2">Card Two</h3>
                <p class="text-gray-600">Description text for this card.</p>
              </div>
            </div>
            <div class="bg-white rounded-lg shadow-md overflow-hidden">
              <div class="bg-gray-200 h-48"></div>
              <div class="p-6">
                <h3 class="text-xl font-semibold mb-2">Card Three</h3>
                <p class="text-gray-600">Description text for this card.</p>
              </div>
            </div>
          </div>
        </section>
      `
    });

    // --- CTA ---
    bm.add('cta-simple', {
      label: 'CTA Section',
      category: 'Sections',
      content: `
        <section class="py-16 px-4 bg-blue-600 text-white text-center">
          <div class="max-w-3xl mx-auto">
            <h2 class="text-3xl font-bold mb-4">Ready to Get Started?</h2>
            <p class="text-blue-100 mb-8">Join thousands of satisfied customers using our product.</p>
            <a href="#" class="inline-block bg-white text-blue-600 px-8 py-3 rounded-lg font-semibold hover:bg-gray-100">Start Free Trial</a>
          </div>
        </section>
      `
    });

    // --- Testimonials ---
    bm.add('testimonial', {
      label: 'Testimonial',
      category: 'Components',
      content: `
        <div class="bg-white p-8 rounded-lg shadow-md max-w-md">
          <p class="text-gray-600 mb-6 italic">"This product has completely transformed how we work. Highly recommended!"</p>
          <div class="flex items-center">
            <div class="w-12 h-12 bg-gray-300 rounded-full mr-4"></div>
            <div>
              <div class="font-semibold">John Doe</div>
              <div class="text-gray-500 text-sm">CEO, Company</div>
            </div>
          </div>
        </div>
      `
    });

    // --- Navigation ---
    bm.add('navbar', {
      label: 'Navbar',
      category: 'Navigation',
      content: `
        <nav class="py-4 px-4 bg-white shadow-sm">
          <div class="max-w-6xl mx-auto flex justify-between items-center">
            <a href="#" class="text-xl font-bold">YourBrand</a>
            <div class="flex gap-6">
              <a href="#" class="text-gray-600 hover:text-gray-900">Home</a>
              <a href="#" class="text-gray-600 hover:text-gray-900">About</a>
              <a href="#" class="text-gray-600 hover:text-gray-900">Services</a>
              <a href="#" class="text-gray-600 hover:text-gray-900">Contact</a>
            </div>
            <a href="#" class="bg-blue-600 text-white px-4 py-2 rounded-lg font-semibold">Sign Up</a>
          </div>
        </nav>
      `
    });

    // --- Footer ---
    bm.add('footer-simple', {
      label: 'Footer',
      category: 'Sections',
      content: `
        <footer class="py-8 px-4 bg-gray-900 text-white">
          <div class="max-w-6xl mx-auto flex flex-col md:flex-row justify-between items-center">
            <div class="text-xl font-bold mb-4 md:mb-0">YourBrand</div>
            <nav class="flex gap-6 mb-4 md:mb-0">
              <a href="#" class="text-gray-400 hover:text-white">Home</a>
              <a href="#" class="text-gray-400 hover:text-white">About</a>
              <a href="#" class="text-gray-400 hover:text-white">Services</a>
              <a href="#" class="text-gray-400 hover:text-white">Contact</a>
            </nav>
            <div class="text-gray-400 text-sm">© 2024 YourBrand. All rights reserved.</div>
          </div>
        </footer>
      `
    });

    // --- Pricing ---
    bm.add('pricing-card', {
      label: 'Pricing Card',
      category: 'Components',
      content: `
        <div class="bg-white rounded-lg shadow-md p-8 text-center max-w-sm">
          <h3 class="text-xl font-semibold mb-2">Pro Plan</h3>
          <div class="text-4xl font-bold mb-4">$29<span class="text-lg text-gray-500">/mo</span></div>
          <ul class="text-gray-600 mb-6 space-y-2">
            <li>Unlimited Projects</li>
            <li>Priority Support</li>
            <li>Advanced Analytics</li>
            <li>Custom Domain</li>
          </ul>
          <a href="#" class="block bg-blue-600 text-white py-3 rounded-lg font-semibold">Get Started</a>
        </div>
      `
    });

    // --- Forms ---
    bm.add('contact-form', {
      label: 'Contact Form',
      category: 'Forms',
      content: `
        <form class="max-w-lg mx-auto p-8 bg-white rounded-lg shadow-md">
          <h3 class="text-2xl font-bold mb-6">Contact Us</h3>
          <div class="mb-4">
            <label class="block text-gray-700 text-sm font-semibold mb-2">Name</label>
            <input type="text" class="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500" placeholder="Your name">
          </div>
          <div class="mb-4">
            <label class="block text-gray-700 text-sm font-semibold mb-2">Email</label>
            <input type="email" class="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500" placeholder="your@email.com">
          </div>
          <div class="mb-4">
            <label class="block text-gray-700 text-sm font-semibold mb-2">Message</label>
            <textarea class="w-full px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 h-32" placeholder="Your message"></textarea>
          </div>
          <button type="submit" class="w-full bg-blue-600 text-white py-3 rounded-lg font-semibold hover:bg-blue-700">Send Message</button>
        </form>
      `
    });

    bm.add('newsletter', {
      label: 'Newsletter',
      category: 'Forms',
      content: `
        <section class="py-12 px-4 bg-gray-100">
          <div class="max-w-xl mx-auto text-center">
            <h3 class="text-2xl font-bold mb-4">Subscribe to Our Newsletter</h3>
            <p class="text-gray-600 mb-6">Get the latest updates delivered to your inbox.</p>
            <form class="flex gap-2">
              <input type="email" class="flex-1 px-4 py-3 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500" placeholder="your@email.com">
              <button type="submit" class="bg-blue-600 text-white px-6 py-3 rounded-lg font-semibold hover:bg-blue-700">Subscribe</button>
            </form>
          </div>
        </section>
      `
    });

    // --- FAQ ---
    bm.add('faq', {
      label: 'FAQ Section',
      category: 'Sections',
      content: `
        <section class="py-16 px-4">
          <div class="max-w-3xl mx-auto">
            <h2 class="text-3xl font-bold text-center mb-12">Frequently Asked Questions</h2>
            <div class="space-y-4">
              <details class="bg-white rounded-lg shadow-md">
                <summary class="px-6 py-4 font-semibold cursor-pointer">What is your return policy?</summary>
                <p class="px-6 pb-4 text-gray-600">We offer a 30-day money-back guarantee on all purchases.</p>
              </details>
              <details class="bg-white rounded-lg shadow-md">
                <summary class="px-6 py-4 font-semibold cursor-pointer">How do I get started?</summary>
                <p class="px-6 pb-4 text-gray-600">Sign up for a free account and follow our quick start guide.</p>
              </details>
              <details class="bg-white rounded-lg shadow-md">
                <summary class="px-6 py-4 font-semibold cursor-pointer">Do you offer support?</summary>
                <p class="px-6 pb-4 text-gray-600">Yes! We have 24/7 support available via chat, email, and phone.</p>
              </details>
            </div>
          </div>
        </section>
      `
    });
  }

  /**
   * Bootstrap 5 blocks
   */
  function addBootstrapBlocks(bm) {
    // --- Layout ---
    bm.add('section', {
      label: 'Section',
      category: 'Layout',
      content: '<section class="py-5"><div class="container"></div></section>'
    });

    bm.add('container', {
      label: 'Container',
      category: 'Layout',
      content: '<div class="container"></div>'
    });

    bm.add('container-fluid', {
      label: 'Container Fluid',
      category: 'Layout',
      content: '<div class="container-fluid"></div>'
    });

    bm.add('row', {
      label: 'Row',
      category: 'Layout',
      content: '<div class="row"></div>'
    });

    bm.add('col-6', {
      label: '2 Columns',
      category: 'Layout',
      content: '<div class="row"><div class="col-md-6"></div><div class="col-md-6"></div></div>'
    });

    bm.add('col-4', {
      label: '3 Columns',
      category: 'Layout',
      content: '<div class="row"><div class="col-md-4"></div><div class="col-md-4"></div><div class="col-md-4"></div></div>'
    });

    bm.add('col-3', {
      label: '4 Columns',
      category: 'Layout',
      content: '<div class="row"><div class="col-md-3"></div><div class="col-md-3"></div><div class="col-md-3"></div><div class="col-md-3"></div></div>'
    });

    // --- Typography ---
    bm.add('heading-1', {
      label: 'Heading 1',
      category: 'Typography',
      content: '<h1 class="display-4">Heading 1</h1>'
    });

    bm.add('heading-2', {
      label: 'Heading 2',
      category: 'Typography',
      content: '<h2 class="display-5">Heading 2</h2>'
    });

    bm.add('heading-3', {
      label: 'Heading 3',
      category: 'Typography',
      content: '<h3 class="display-6">Heading 3</h3>'
    });

    bm.add('paragraph', {
      label: 'Paragraph',
      category: 'Typography',
      content: '<p class="lead">Your paragraph text goes here. Edit this text to add your own content.</p>'
    });

    bm.add('text-muted', {
      label: 'Muted Text',
      category: 'Typography',
      content: '<p class="text-muted">Secondary text with muted color.</p>'
    });

    // --- Buttons ---
    bm.add('button-primary', {
      label: 'Primary Button',
      category: 'Buttons',
      content: '<a href="#" class="btn btn-primary btn-lg">Button</a>'
    });

    bm.add('button-secondary', {
      label: 'Secondary Button',
      category: 'Buttons',
      content: '<a href="#" class="btn btn-secondary btn-lg">Button</a>'
    });

    bm.add('button-outline', {
      label: 'Outline Button',
      category: 'Buttons',
      content: '<a href="#" class="btn btn-outline-primary btn-lg">Button</a>'
    });

    bm.add('button-success', {
      label: 'Success Button',
      category: 'Buttons',
      content: '<a href="#" class="btn btn-success btn-lg">Button</a>'
    });

    bm.add('button-danger', {
      label: 'Danger Button',
      category: 'Buttons',
      content: '<a href="#" class="btn btn-danger btn-lg">Button</a>'
    });

    // --- Hero Sections ---
    bm.add('hero-simple', {
      label: 'Hero Simple',
      category: 'Sections',
      content: `
        <section class="py-5 bg-dark text-white text-center">
          <div class="container py-5">
            <h1 class="display-3 fw-bold mb-4">Welcome to Your Site</h1>
            <p class="lead mb-4">A beautiful subtitle that describes what you do and why visitors should care.</p>
            <a href="#" class="btn btn-primary btn-lg">Get Started</a>
          </div>
        </section>
      `
    });

    bm.add('hero-split', {
      label: 'Hero Split',
      category: 'Sections',
      content: `
        <section class="py-5">
          <div class="container">
            <div class="row align-items-center">
              <div class="col-md-6">
                <h1 class="display-4 fw-bold mb-3">Build Something Amazing</h1>
                <p class="lead text-muted mb-4">Create beautiful, responsive websites without writing code.</p>
                <a href="#" class="btn btn-primary btn-lg">Learn More</a>
              </div>
              <div class="col-md-6">
                <div class="bg-secondary rounded ratio ratio-16x9 d-flex align-items-center justify-content-center">
                  <span class="text-white">Image Placeholder</span>
                </div>
              </div>
            </div>
          </div>
        </section>
      `
    });

    bm.add('jumbotron', {
      label: 'Jumbotron',
      category: 'Sections',
      content: `
        <div class="p-5 mb-4 bg-light rounded-3">
          <div class="container py-5">
            <h1 class="display-4 fw-bold">Custom Jumbotron</h1>
            <p class="col-md-8 fs-4">Using a series of utilities, you can create this jumbotron.</p>
            <a href="#" class="btn btn-primary btn-lg">Call to action</a>
          </div>
        </div>
      `
    });

    // --- Cards ---
    bm.add('card', {
      label: 'Card',
      category: 'Components',
      content: `
        <div class="card" style="width: 18rem;">
          <div class="bg-secondary" style="height: 180px;"></div>
          <div class="card-body">
            <h5 class="card-title">Card Title</h5>
            <p class="card-text">Some quick example text to build on the card title.</p>
            <a href="#" class="btn btn-primary">Go somewhere</a>
          </div>
        </div>
      `
    });

    bm.add('cards-row', {
      label: 'Cards Row',
      category: 'Sections',
      content: `
        <section class="py-5">
          <div class="container">
            <div class="row g-4">
              <div class="col-md-4">
                <div class="card h-100">
                  <div class="bg-secondary" style="height: 180px;"></div>
                  <div class="card-body">
                    <h5 class="card-title">Card One</h5>
                    <p class="card-text">Description text for this card.</p>
                  </div>
                </div>
              </div>
              <div class="col-md-4">
                <div class="card h-100">
                  <div class="bg-secondary" style="height: 180px;"></div>
                  <div class="card-body">
                    <h5 class="card-title">Card Two</h5>
                    <p class="card-text">Description text for this card.</p>
                  </div>
                </div>
              </div>
              <div class="col-md-4">
                <div class="card h-100">
                  <div class="bg-secondary" style="height: 180px;"></div>
                  <div class="card-body">
                    <h5 class="card-title">Card Three</h5>
                    <p class="card-text">Description text for this card.</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>
      `
    });

    // --- Alerts ---
    bm.add('alert-primary', {
      label: 'Alert Primary',
      category: 'Components',
      content: '<div class="alert alert-primary" role="alert">A simple primary alert—check it out!</div>'
    });

    bm.add('alert-success', {
      label: 'Alert Success',
      category: 'Components',
      content: '<div class="alert alert-success" role="alert">A simple success alert—check it out!</div>'
    });

    bm.add('alert-warning', {
      label: 'Alert Warning',
      category: 'Components',
      content: '<div class="alert alert-warning" role="alert">A simple warning alert—check it out!</div>'
    });

    // --- Navigation ---
    bm.add('navbar', {
      label: 'Navbar',
      category: 'Navigation',
      content: `
        <nav class="navbar navbar-expand-lg navbar-light bg-light">
          <div class="container">
            <a class="navbar-brand fw-bold" href="#">YourBrand</a>
            <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav">
              <span class="navbar-toggler-icon"></span>
            </button>
            <div class="collapse navbar-collapse" id="navbarNav">
              <ul class="navbar-nav me-auto">
                <li class="nav-item"><a class="nav-link active" href="#">Home</a></li>
                <li class="nav-item"><a class="nav-link" href="#">About</a></li>
                <li class="nav-item"><a class="nav-link" href="#">Services</a></li>
                <li class="nav-item"><a class="nav-link" href="#">Contact</a></li>
              </ul>
              <a href="#" class="btn btn-primary">Sign Up</a>
            </div>
          </div>
        </nav>
      `
    });

    bm.add('navbar-dark', {
      label: 'Navbar Dark',
      category: 'Navigation',
      content: `
        <nav class="navbar navbar-expand-lg navbar-dark bg-dark">
          <div class="container">
            <a class="navbar-brand fw-bold" href="#">YourBrand</a>
            <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarDark">
              <span class="navbar-toggler-icon"></span>
            </button>
            <div class="collapse navbar-collapse" id="navbarDark">
              <ul class="navbar-nav me-auto">
                <li class="nav-item"><a class="nav-link active" href="#">Home</a></li>
                <li class="nav-item"><a class="nav-link" href="#">About</a></li>
                <li class="nav-item"><a class="nav-link" href="#">Services</a></li>
              </ul>
              <a href="#" class="btn btn-outline-light">Sign Up</a>
            </div>
          </div>
        </nav>
      `
    });

    // --- Footer ---
    bm.add('footer-simple', {
      label: 'Footer',
      category: 'Sections',
      content: `
        <footer class="py-4 bg-dark text-white">
          <div class="container">
            <div class="row align-items-center">
              <div class="col-md-4">
                <span class="fw-bold">YourBrand</span>
              </div>
              <div class="col-md-4 text-center">
                <a href="#" class="text-white-50 me-3">Home</a>
                <a href="#" class="text-white-50 me-3">About</a>
                <a href="#" class="text-white-50 me-3">Services</a>
                <a href="#" class="text-white-50">Contact</a>
              </div>
              <div class="col-md-4 text-end">
                <small class="text-white-50">© 2024 YourBrand</small>
              </div>
            </div>
          </div>
        </footer>
      `
    });

    // --- Forms ---
    bm.add('contact-form', {
      label: 'Contact Form',
      category: 'Forms',
      content: `
        <div class="card">
          <div class="card-body p-4">
            <h3 class="card-title mb-4">Contact Us</h3>
            <form>
              <div class="mb-3">
                <label class="form-label">Name</label>
                <input type="text" class="form-control" placeholder="Your name">
              </div>
              <div class="mb-3">
                <label class="form-label">Email</label>
                <input type="email" class="form-control" placeholder="your@email.com">
              </div>
              <div class="mb-3">
                <label class="form-label">Message</label>
                <textarea class="form-control" rows="4" placeholder="Your message"></textarea>
              </div>
              <button type="submit" class="btn btn-primary w-100">Send Message</button>
            </form>
          </div>
        </div>
      `
    });

    bm.add('newsletter', {
      label: 'Newsletter',
      category: 'Forms',
      content: `
        <section class="py-5 bg-light">
          <div class="container">
            <div class="row justify-content-center">
              <div class="col-md-6 text-center">
                <h3 class="mb-3">Subscribe to Our Newsletter</h3>
                <p class="text-muted mb-4">Get the latest updates delivered to your inbox.</p>
                <form class="d-flex gap-2">
                  <input type="email" class="form-control" placeholder="your@email.com">
                  <button type="submit" class="btn btn-primary">Subscribe</button>
                </form>
              </div>
            </div>
          </div>
        </section>
      `
    });

    // --- Accordion ---
    bm.add('accordion', {
      label: 'Accordion',
      category: 'Components',
      content: `
        <div class="accordion" id="accordionExample">
          <div class="accordion-item">
            <h2 class="accordion-header">
              <button class="accordion-button" type="button" data-bs-toggle="collapse" data-bs-target="#collapseOne">
                Accordion Item #1
              </button>
            </h2>
            <div id="collapseOne" class="accordion-collapse collapse show" data-bs-parent="#accordionExample">
              <div class="accordion-body">Content for the first item.</div>
            </div>
          </div>
          <div class="accordion-item">
            <h2 class="accordion-header">
              <button class="accordion-button collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#collapseTwo">
                Accordion Item #2
              </button>
            </h2>
            <div id="collapseTwo" class="accordion-collapse collapse" data-bs-parent="#accordionExample">
              <div class="accordion-body">Content for the second item.</div>
            </div>
          </div>
        </div>
      `
    });

    // --- Pricing ---
    bm.add('pricing-card', {
      label: 'Pricing Card',
      category: 'Components',
      content: `
        <div class="card text-center">
          <div class="card-header">
            <h4 class="my-0 fw-normal">Pro</h4>
          </div>
          <div class="card-body">
            <h1 class="card-title">$29 <small class="text-muted fw-light">/mo</small></h1>
            <ul class="list-unstyled mt-3 mb-4">
              <li>Unlimited projects</li>
              <li>Priority support</li>
              <li>Advanced analytics</li>
              <li>Custom domain</li>
            </ul>
            <a href="#" class="btn btn-lg btn-primary w-100">Get Started</a>
          </div>
        </div>
      `
    });
  }

  /**
   * Vanilla CSS blocks (no framework)
   */
  function addVanillaBlocks(bm) {
    // --- Layout ---
    bm.add('section', {
      label: 'Section',
      category: 'Layout',
      content: '<section style="padding: 60px 20px;"><div style="max-width: 1200px; margin: 0 auto;"></div></section>'
    });

    bm.add('container', {
      label: 'Container',
      category: 'Layout',
      content: '<div style="max-width: 1200px; margin: 0 auto; padding: 0 20px;"></div>'
    });

    bm.add('flex-row', {
      label: 'Flex Row',
      category: 'Layout',
      content: '<div style="display: flex; flex-direction: row; gap: 20px;"></div>'
    });

    bm.add('flex-col', {
      label: 'Flex Column',
      category: 'Layout',
      content: '<div style="display: flex; flex-direction: column; gap: 20px;"></div>'
    });

    bm.add('grid-2', {
      label: 'Grid 2 Cols',
      category: 'Layout',
      content: '<div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 24px;"></div>'
    });

    bm.add('grid-3', {
      label: 'Grid 3 Cols',
      category: 'Layout',
      content: '<div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 24px;"></div>'
    });

    // --- Typography ---
    bm.add('heading-1', {
      label: 'Heading 1',
      category: 'Typography',
      content: '<h1 style="font-size: 3rem; font-weight: bold; margin-bottom: 1rem;">Heading 1</h1>'
    });

    bm.add('heading-2', {
      label: 'Heading 2',
      category: 'Typography',
      content: '<h2 style="font-size: 2.25rem; font-weight: bold; margin-bottom: 1rem;">Heading 2</h2>'
    });

    bm.add('heading-3', {
      label: 'Heading 3',
      category: 'Typography',
      content: '<h3 style="font-size: 1.5rem; font-weight: 600; margin-bottom: 1rem;">Heading 3</h3>'
    });

    bm.add('paragraph', {
      label: 'Paragraph',
      category: 'Typography',
      content: '<p style="font-size: 1rem; line-height: 1.6; color: #555;">Your paragraph text goes here. Edit this text to add your own content.</p>'
    });

    // --- Buttons ---
    bm.add('button-primary', {
      label: 'Primary Button',
      category: 'Buttons',
      content: '<a href="#" style="display: inline-block; background: #2563eb; color: white; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: 600;">Button</a>'
    });

    bm.add('button-secondary', {
      label: 'Secondary Button',
      category: 'Buttons',
      content: '<a href="#" style="display: inline-block; background: #e5e7eb; color: #374151; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: 600;">Button</a>'
    });

    bm.add('button-outline', {
      label: 'Outline Button',
      category: 'Buttons',
      content: '<a href="#" style="display: inline-block; border: 2px solid #2563eb; color: #2563eb; padding: 10px 22px; border-radius: 8px; text-decoration: none; font-weight: 600;">Button</a>'
    });

    // --- Hero ---
    bm.add('hero-simple', {
      label: 'Hero Simple',
      category: 'Sections',
      content: `
        <section style="padding: 80px 20px; background: #1f2937; color: white; text-align: center;">
          <div style="max-width: 800px; margin: 0 auto;">
            <h1 style="font-size: 3rem; font-weight: bold; margin-bottom: 1.5rem;">Welcome to Your Site</h1>
            <p style="font-size: 1.25rem; color: #9ca3af; margin-bottom: 2rem;">A beautiful subtitle that describes what you do.</p>
            <a href="#" style="display: inline-block; background: #2563eb; color: white; padding: 12px 32px; border-radius: 8px; text-decoration: none; font-weight: 600;">Get Started</a>
          </div>
        </section>
      `
    });

    // --- Card ---
    bm.add('card', {
      label: 'Card',
      category: 'Components',
      content: `
        <div style="background: white; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); overflow: hidden; max-width: 350px;">
          <div style="background: #e5e7eb; height: 180px;"></div>
          <div style="padding: 24px;">
            <h3 style="font-size: 1.25rem; font-weight: 600; margin-bottom: 0.5rem;">Card Title</h3>
            <p style="color: #6b7280; margin-bottom: 1rem;">Some description text for this card.</p>
            <a href="#" style="color: #2563eb; text-decoration: none; font-weight: 600;">Learn more →</a>
          </div>
        </div>
      `
    });

    // --- Navbar ---
    bm.add('navbar', {
      label: 'Navbar',
      category: 'Navigation',
      content: `
        <nav style="padding: 16px 20px; background: white; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
          <div style="max-width: 1200px; margin: 0 auto; display: flex; justify-content: space-between; align-items: center;">
            <a href="#" style="font-size: 1.25rem; font-weight: bold; text-decoration: none; color: #111;">YourBrand</a>
            <div style="display: flex; gap: 24px;">
              <a href="#" style="color: #555; text-decoration: none;">Home</a>
              <a href="#" style="color: #555; text-decoration: none;">About</a>
              <a href="#" style="color: #555; text-decoration: none;">Services</a>
              <a href="#" style="color: #555; text-decoration: none;">Contact</a>
            </div>
            <a href="#" style="display: inline-block; background: #2563eb; color: white; padding: 8px 16px; border-radius: 6px; text-decoration: none; font-weight: 600;">Sign Up</a>
          </div>
        </nav>
      `
    });

    // --- Footer ---
    bm.add('footer-simple', {
      label: 'Footer',
      category: 'Sections',
      content: `
        <footer style="padding: 32px 20px; background: #1f2937; color: white;">
          <div style="max-width: 1200px; margin: 0 auto; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 20px;">
            <span style="font-weight: bold;">YourBrand</span>
            <div style="display: flex; gap: 24px;">
              <a href="#" style="color: #9ca3af; text-decoration: none;">Home</a>
              <a href="#" style="color: #9ca3af; text-decoration: none;">About</a>
              <a href="#" style="color: #9ca3af; text-decoration: none;">Contact</a>
            </div>
            <span style="color: #9ca3af; font-size: 0.875rem;">© 2024 YourBrand</span>
          </div>
        </footer>
      `
    });

    // --- Contact Form ---
    bm.add('contact-form', {
      label: 'Contact Form',
      category: 'Forms',
      content: `
        <form style="max-width: 500px; margin: 0 auto; padding: 32px; background: white; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
          <h3 style="font-size: 1.5rem; font-weight: bold; margin-bottom: 1.5rem;">Contact Us</h3>
          <div style="margin-bottom: 16px;">
            <label style="display: block; margin-bottom: 8px; font-weight: 500;">Name</label>
            <input type="text" placeholder="Your name" style="width: 100%; padding: 10px 14px; border: 1px solid #d1d5db; border-radius: 6px; box-sizing: border-box;">
          </div>
          <div style="margin-bottom: 16px;">
            <label style="display: block; margin-bottom: 8px; font-weight: 500;">Email</label>
            <input type="email" placeholder="your@email.com" style="width: 100%; padding: 10px 14px; border: 1px solid #d1d5db; border-radius: 6px; box-sizing: border-box;">
          </div>
          <div style="margin-bottom: 16px;">
            <label style="display: block; margin-bottom: 8px; font-weight: 500;">Message</label>
            <textarea placeholder="Your message" style="width: 100%; padding: 10px 14px; border: 1px solid #d1d5db; border-radius: 6px; height: 120px; box-sizing: border-box;"></textarea>
          </div>
          <button type="submit" style="width: 100%; padding: 12px; background: #2563eb; color: white; border: none; border-radius: 6px; font-weight: 600; cursor: pointer;">Send Message</button>
        </form>
      `
    });
  }

  // Expose function
  window.ActiveCanvasEditor.addCustomBlocks = addCustomBlocks;

})();
