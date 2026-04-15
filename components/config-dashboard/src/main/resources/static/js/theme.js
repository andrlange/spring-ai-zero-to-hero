// IIFE — runs in <head> before render to prevent flash of wrong theme
(function() {
    var saved = localStorage.getItem('theme');
    if (saved === 'light') {
        document.documentElement.setAttribute('data-theme', 'light');
        document.documentElement.setAttribute('data-bs-theme', 'light');
    }
})();

// After DOM ready — wire up toggle button and smooth transitions
document.addEventListener('DOMContentLoaded', function() {
    var toggle = document.getElementById('theme-toggle');
    if (!toggle) return;

    // Enable transitions after first paint (prevents flash animation on page load)
    requestAnimationFrame(function() {
        document.documentElement.classList.add('theme-transitions');
    });

    toggle.addEventListener('click', function() {
        var isLight = document.documentElement.getAttribute('data-theme') === 'light';
        var newTheme = isLight ? 'dark' : 'light';

        if (newTheme === 'light') {
            document.documentElement.setAttribute('data-theme', 'light');
            document.documentElement.setAttribute('data-bs-theme', 'light');
        } else {
            document.documentElement.removeAttribute('data-theme');
            document.documentElement.setAttribute('data-bs-theme', 'dark');
        }

        localStorage.setItem('theme', newTheme);

        // Re-initialize Mermaid with matching theme
        if (typeof mermaid !== 'undefined') {
            mermaid.initialize({
                theme: newTheme === 'light' ? 'default' : 'dark',
                startOnLoad: false
            });
            document.querySelectorAll('.mermaid').forEach(function(el) {
                var original = el.getAttribute('data-original');
                if (original) {
                    el.removeAttribute('data-processed');
                    el.innerHTML = original;
                }
            });
            mermaid.run();
        }
    });
});
