/**
 * ActiveCanvas Editor - Custom Blocks
 */

(function() {
  'use strict';

  window.ActiveCanvasEditor = window.ActiveCanvasEditor || {};

  /**
   * Register all custom blocks with the editor
   * @param {Object} editor - GrapeJS editor instance
   */
  function addCustomBlocks(editor) {
    const bm = editor.BlockManager;

    // --- Layout Blocks ---
    bm.add('section', {
      label: 'Section',
      category: 'Layout',
      content: '<section class="py-16 px-4"><div class="max-w-6xl mx-auto"></div></section>',
      attributes: { class: 'gjs-fonts gjs-f-b1' }
    });

    bm.add('container', {
      label: 'Container',
      category: 'Layout',
      content: '<div class="max-w-6xl mx-auto px-4"></div>',
      attributes: { class: 'gjs-fonts gjs-f-b1' }
    });

    bm.add('div', {
      label: 'Div Block',
      category: 'Layout',
      content: '<div></div>',
      attributes: { class: 'gjs-fonts gjs-f-b1' }
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
                <p class="text-gray-600">Description of this amazing feature and why it matters to your users.</p>
              </div>
              <div class="text-center p-6">
                <div class="w-12 h-12 bg-blue-600 rounded-lg mx-auto mb-4"></div>
                <h3 class="text-xl font-semibold mb-2">Feature Two</h3>
                <p class="text-gray-600">Description of this amazing feature and why it matters to your users.</p>
              </div>
              <div class="text-center p-6">
                <div class="w-12 h-12 bg-blue-600 rounded-lg mx-auto mb-4"></div>
                <h3 class="text-xl font-semibold mb-2">Feature Three</h3>
                <p class="text-gray-600">Description of this amazing feature and why it matters to your users.</p>
              </div>
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
            <a href="#" class="text-blue-600 font-semibold">Learn more &rarr;</a>
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
              <div class="bg-gray-200 h-48 flex items-center justify-center">
                <span class="text-gray-500">Image</span>
              </div>
              <div class="p-6">
                <h3 class="text-xl font-semibold mb-2">Card One</h3>
                <p class="text-gray-600">Description text for this card.</p>
              </div>
            </div>
            <div class="bg-white rounded-lg shadow-md overflow-hidden">
              <div class="bg-gray-200 h-48 flex items-center justify-center">
                <span class="text-gray-500">Image</span>
              </div>
              <div class="p-6">
                <h3 class="text-xl font-semibold mb-2">Card Two</h3>
                <p class="text-gray-600">Description text for this card.</p>
              </div>
            </div>
            <div class="bg-white rounded-lg shadow-md overflow-hidden">
              <div class="bg-gray-200 h-48 flex items-center justify-center">
                <span class="text-gray-500">Image</span>
              </div>
              <div class="p-6">
                <h3 class="text-xl font-semibold mb-2">Card Three</h3>
                <p class="text-gray-600">Description text for this card.</p>
              </div>
            </div>
          </div>
        </section>
      `
    });

    // --- CTA Sections ---
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
            <div class="text-gray-400 text-sm">&copy; 2024 YourBrand. All rights reserved.</div>
          </div>
        </footer>
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

    // --- Contact Form ---
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

    // --- Newsletter ---
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
                <p class="px-6 pb-4 text-gray-600">We offer a 30-day money-back guarantee on all purchases. Simply contact our support team for a full refund.</p>
              </details>
              <details class="bg-white rounded-lg shadow-md">
                <summary class="px-6 py-4 font-semibold cursor-pointer">How do I get started?</summary>
                <p class="px-6 pb-4 text-gray-600">Sign up for a free account and follow our quick start guide to begin using our platform in minutes.</p>
              </details>
              <details class="bg-white rounded-lg shadow-md">
                <summary class="px-6 py-4 font-semibold cursor-pointer">Do you offer customer support?</summary>
                <p class="px-6 pb-4 text-gray-600">Yes! We have 24/7 customer support available via chat, email, and phone for all paid plans.</p>
              </details>
            </div>
          </div>
        </section>
      `
    });
  }

  // Expose function
  window.ActiveCanvasEditor.addCustomBlocks = addCustomBlocks;

})();
