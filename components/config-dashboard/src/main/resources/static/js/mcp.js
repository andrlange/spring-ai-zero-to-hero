// Stage 6 MCP dashboard — status polling, action dispatch, inspector rendering.

(function() {
    var POLL_MS = 3000;
    var demoIds = [];

    document.addEventListener('DOMContentLoaded', function() {
        document.querySelectorAll('[id^="mcp-card-"]').forEach(function(el) {
            demoIds.push(el.dataset.demoId);
        });
        pollAllStatuses();
        setInterval(pollAllStatuses, POLL_MS);
    });

    function pollAllStatuses() {
        demoIds.forEach(function(id) {
            fetch('/dashboard/mcp/' + id + '/status')
                .then(function(r) { return r.ok ? r.json() : null; })
                .then(function(data) { if (data) applyStatus(data); })
                .catch(function() { applyStatus({ id: id, status: 'down', startCommand: '' }); });
        });
    }

    function applyStatus(data) {
        var pill = document.getElementById('mcp-status-' + data.id);
        var text = document.getElementById('mcp-status-text-' + data.id);
        var hintBox = document.getElementById('mcp-offline-hint-' + data.id);
        var hintCmd = document.getElementById('mcp-offline-cmd-' + data.id);
        if (!pill) return;

        var up = data.status === 'up';
        pill.style.background = up ? 'var(--spring-green)' : 'var(--spring-muted)';
        if (text) text.textContent = up ? 'running' : 'not running';
        if (hintBox) hintBox.style.display = up ? 'none' : 'flex';
        if (hintCmd && data.startCommand) hintCmd.textContent = data.startCommand;

        var card = document.getElementById('mcp-card-' + data.id);
        if (card) {
            card.querySelectorAll('.mcp-action-btn').forEach(function(b) {
                b.disabled = !up;
            });
        }
    }

    window.copyMcpCommand = function(id) {
        var cmd = document.getElementById('mcp-offline-cmd-' + id);
        if (!cmd) return;
        navigator.clipboard.writeText(cmd.textContent);
    };

    window.mcpListTools = function(btn) {
        var id = btn.dataset.demoId;
        setInspectorLoading('Listing tools for MCP ' + id + '…');
        fetch('/dashboard/mcp/' + id + '/tools')
            .then(function(r) { return r.json().then(function(body) { return { ok: r.ok, body: body }; }); })
            .then(function(res) { renderInspector(res, 'Tools'); })
            .catch(function(e) { renderInspector({ ok: false, body: { error: String(e && e.message || e) } }, 'Tools'); });
    };

    window.mcpListResources = function(btn) {
        var id = btn.dataset.demoId;
        setInspectorLoading('Listing resources for MCP ' + id + '…');
        fetch('/dashboard/mcp/' + id + '/resources')
            .then(function(r) { return r.json().then(function(body) { return { ok: r.ok, body: body }; }); })
            .then(function(res) { renderInspector(res, 'Resources'); })
            .catch(function(e) { renderInspector({ ok: false, body: { error: String(e && e.message || e) } }, 'Resources'); });
    };

    window.mcpListPrompts = function(btn) {
        var id = btn.dataset.demoId;
        setInspectorLoading('Listing prompts for MCP ' + id + '…');
        fetch('/dashboard/mcp/' + id + '/prompts')
            .then(function(r) { return r.json().then(function(body) { return { ok: r.ok, body: body }; }); })
            .then(function(res) { renderInspector(res, 'Prompts'); })
            .catch(function(e) { renderInspector({ ok: false, body: { error: String(e && e.message || e) } }, 'Prompts'); });
    };

    window.mcp04Trigger = function(btn) {
        setInspectorLoading('Triggering dynamic registration on MCP 04…');
        fetch('/dashboard/mcp/04/update-tools', { method: 'POST' })
            .then(function(r) { return r.json().then(function(body) { return { ok: r.ok, body: body }; }); })
            .then(function(res) { renderInspector(res, 'Dynamic registration'); })
            .catch(function(e) { renderInspector({ ok: false, body: { error: String(e && e.message || e) } }, 'Dynamic registration'); });
    };

    window.mcp03Run = function(mode) {
        setInspectorLoading('Running MCP client demo in ' + mode + ' mode…');
        fetch('/dashboard/mcp/03/run?mode=' + encodeURIComponent(mode), { method: 'POST' })
            .then(function(r) { return r.json().then(function(body) { return { ok: r.ok, body: body }; }); })
            .then(function(res) { renderInspector(res, 'MCP Client demo (' + mode + ')'); })
            .catch(function(e) { renderInspector({ ok: false, body: { error: String(e && e.message || e) } }, 'MCP Client demo (' + mode + ')'); });
    };

    window.mcpShowDocs = function(id) {
        fetch('/dashboard/docs?path=' + encodeURIComponent('/dashboard/mcp/' + id + '/tools'))
            .then(function(r) { return r.ok ? r.json() : null; })
            .then(function(data) {
                if (!data) return;
                var body = document.getElementById('doc-modal-body');
                if (body) body.innerHTML = docMarked.parse(data.fullSection || '');
                var modal = document.getElementById('doc-modal');
                if (modal) modal.style.display = 'flex';
            });
    };

    window.closeDocModal = function(event) {
        if (event && event.target !== event.currentTarget) return;
        var modal = document.getElementById('doc-modal');
        if (modal) modal.style.display = 'none';
    };

    function setInspectorLoading(msg) {
        var el = document.getElementById('mcp-inspector');
        if (!el) return;
        el.innerHTML = '<div class="text-muted text-center mt-4"><div class="spinner-border spinner-border-sm" role="status"></div> ' + escapeHtml(msg) + '</div>';
    }

    function renderInspector(res, title) {
        var el = document.getElementById('mcp-inspector');
        if (!el) return;
        var header = '<div class="d-flex justify-content-between align-items-center mb-2">' +
            '<span class="text-muted small text-uppercase fw-bold">' + escapeHtml(title) + '</span>' +
            '<span class="' + (res.ok ? 'text-success' : 'text-danger') + ' small">' +
            (res.ok ? 'OK' : 'Error') + '</span></div>';
        if (!res.ok && res.body && res.body.hint) {
            header += '<div class="alert alert-warning" role="alert">' +
                '<div>' + escapeHtml(res.body.error || 'error') + '</div>' +
                '<div class="mt-1"><code>' + escapeHtml(res.body.hint) + '</code></div></div>';
        }
        var content = '<pre class="response-json"><code>' +
            escapeHtml(JSON.stringify(res.body, null, 2)) + '</code></pre>';
        el.innerHTML = header + content;
    }

    function escapeHtml(s) {
        return String(s == null ? '' : s)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    }
})();
