require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ]

  # Replaces the browser clipboard so tests never touch the real one, and records what was copied.
  def stub_clipboard
    page.execute_script(<<~JS)
      window.__copied = [];
      Object.defineProperty(navigator, "clipboard", {
        configurable: true,
        value: { writeText: (text) => { window.__copied.push(text); return Promise.resolve(); } }
      });
    JS
  end

  def copied_texts = page.evaluate_script("window.__copied")
end
