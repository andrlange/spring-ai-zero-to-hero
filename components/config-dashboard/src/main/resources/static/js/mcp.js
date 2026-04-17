// Stage 6 MCP dashboard — status polling, action dispatch, modal + inline invoke forms.

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

    // ===== Modal-based list handlers =====

    function openModal(title, iconClass) {
        document.getElementById('mcp-modal-title').textContent = title;
        var icon = document.getElementById('mcp-modal-icon');
        if (icon) icon.className = 'bi ' + iconClass;
        var modalEl = document.getElementById('mcp-inspector-modal');
        var modal = bootstrap.Modal.getOrCreateInstance(modalEl);
        modal.show();
    }

    function setModalLoading(msg) {
        document.getElementById('mcp-modal-body').innerHTML =
            '<div class="text-muted text-center mt-4"><div class="spinner-border spinner-border-sm" role="status"></div> ' +
            escapeHtml(msg) + '</div>';
    }

    function renderModalError(res) {
        var body = res && res.body || {};
        var html = '<div class="alert alert-warning" role="alert">';
        html += '<div><strong>' + escapeHtml(body.error || 'Error') + '</strong></div>';
        if (body.hint) html += '<div class="mt-1"><code>' + escapeHtml(body.hint) + '</code></div>';
        if (body.detail) html += '<div class="mt-2 small text-muted">' + escapeHtml(body.detail) + '</div>';
        html += '</div>';
        html += prettyJson(body);
        document.getElementById('mcp-modal-body').innerHTML = html;
    }

    window.mcpListTools = function(btn) {
        var id = btn.dataset.demoId;
        openModal('Tools — MCP ' + id, 'bi-tools');
        setModalLoading('Listing tools for MCP ' + id + '…');
        fetch('/dashboard/mcp/' + id + '/tools')
            .then(function(r) { return r.json().then(function(body) { return { ok: r.ok, body: body }; }); })
            .then(function(res) {
                if (!res.ok) { renderModalError(res); return; }
                renderToolsList(id, res.body);
            })
            .catch(function(e) { renderModalError({ body: { error: String(e && e.message || e) } }); });
    };

    window.mcpListResources = function(btn) {
        var id = btn.dataset.demoId;
        openModal('Resources — MCP ' + id, 'bi-files');
        setModalLoading('Listing resources for MCP ' + id + '…');
        fetch('/dashboard/mcp/' + id + '/resources')
            .then(function(r) { return r.json().then(function(body) { return { ok: r.ok, body: body }; }); })
            .then(function(res) {
                if (!res.ok) { renderModalError(res); return; }
                renderResourcesList(id, res.body);
            })
            .catch(function(e) { renderModalError({ body: { error: String(e && e.message || e) } }); });
    };

    window.mcpListPrompts = function(btn) {
        var id = btn.dataset.demoId;
        openModal('Prompts — MCP ' + id, 'bi-chat-left-dots');
        setModalLoading('Listing prompts for MCP ' + id + '…');
        fetch('/dashboard/mcp/' + id + '/prompts')
            .then(function(r) { return r.json().then(function(body) { return { ok: r.ok, body: body }; }); })
            .then(function(res) {
                if (!res.ok) { renderModalError(res); return; }
                renderPromptsList(id, res.body);
            })
            .catch(function(e) { renderModalError({ body: { error: String(e && e.message || e) } }); });
    };

    // ===== Modal content renderers =====

    function cardOpen() {
        return '<div class="mb-3 p-3" style="background:var(--spring-card);border:1px solid var(--spring-border);border-radius:6px">';
    }
    function cardClose() { return '</div>'; }

    function renderToolsList(demoId, body) {
        var tools = (body && body.tools) || [];
        if (!tools.length) {
            document.getElementById('mcp-modal-body').innerHTML = '<p class="text-muted">No tools reported by this server.</p>';
            return;
        }
        var html = '<p class="text-muted small mb-3">' + tools.length + ' tool' + (tools.length === 1 ? '' : 's') +
            ' advertised by MCP ' + escapeHtml(demoId) + '. Click <strong>Invoke</strong> to call a tool from the UI.</p>';
        tools.forEach(function(tool, idx) {
            var uid = 'tool-' + demoId + '-' + idx;
            html += cardOpen();
            html += '<div class="d-flex justify-content-between align-items-start gap-3 mb-2">';
            html += '<div class="flex-grow-1">';
            html += '<h6 class="mb-1" style="color:var(--spring-text)"><code>' + escapeHtml(tool.name || '') + '</code></h6>';
            html += '<p class="text-muted small mb-0">' + escapeHtml(tool.description || '') + '</p>';
            html += '</div>';
            html += '<button class="btn btn-sm btn-spring-green" data-uid="' + uid + '" onclick="mcpToggleInvoke(this)">' +
                '<i class="bi bi-play-fill"></i> Invoke</button>';
            html += '</div>';

            var schema = tool.inputSchema;
            if (schema) {
                html += '<details class="mt-2">';
                html += '<summary class="text-muted small" style="cursor:pointer">Input schema</summary>';
                html += '<div class="mt-2" style="font-size:11px">' + prettyJson(schema) + '</div>';
                html += '</details>';
            }

            html += '<div id="' + uid + '" class="mcp-invoke-form mt-3" style="display:none">' +
                renderInvokeForm(demoId, tool.name || '', schema, uid) + '</div>';
            html += cardClose();
        });
        document.getElementById('mcp-modal-body').innerHTML = html;
    }

    function renderInvokeForm(demoId, toolName, schema, uid) {
        var properties = (schema && schema.properties) || {};
        var required = (schema && schema.required) || [];
        var html = '<div class="mb-2 text-muted small">Arguments</div>';
        var keys = Object.keys(properties);
        if (!keys.length) {
            html += '<div class="text-muted small mb-2">No arguments required.</div>';
        }
        keys.forEach(function(key) {
            var prop = properties[key] || {};
            var isRequired = required.indexOf(key) >= 0;
            var type = prop.type || 'string';
            html += '<div class="mb-2">';
            html += '<label class="form-label small text-muted mb-1">' + escapeHtml(key) +
                (isRequired ? ' <span class="text-danger">*</span>' : '') +
                ' <span style="font-size:11px">' + escapeHtml(type) + '</span></label>';
            html += '<input type="text" class="form-control form-control-sm" ' +
                'data-arg-name="' + escapeHtml(key) + '" ' +
                'data-arg-type="' + escapeHtml(type) + '" ' +
                'placeholder="' + escapeHtml(prop.description || key) + '">';
            html += '</div>';
        });
        html += '<button class="btn btn-sm btn-spring-green" ' +
            'data-demo-id="' + escapeHtml(demoId) + '" ' +
            'data-tool-name="' + escapeHtml(toolName) + '" ' +
            'data-uid="' + uid + '" ' +
            'onclick="mcpSubmitInvoke(this)">Submit</button>';
        html += '<div class="mcp-invoke-result mt-2"></div>';
        return html;
    }

    window.mcpToggleInvoke = function(btn) {
        var uid = btn.dataset.uid;
        var form = document.getElementById(uid);
        if (!form) return;
        form.style.display = form.style.display === 'none' ? 'block' : 'none';
    };

    window.mcpSubmitInvoke = function(btn) {
        var demoId = btn.dataset.demoId;
        var toolName = btn.dataset.toolName;
        var uid = btn.dataset.uid;
        var form = document.getElementById(uid);
        if (!form) return;
        var resultEl = form.querySelector('.mcp-invoke-result');
        var args = {};
        form.querySelectorAll('input[data-arg-name]').forEach(function(inp) {
            var name = inp.dataset.argName;
            var type = inp.dataset.argType;
            var val = inp.value;
            if (!val) return;
            if (type === 'number' || type === 'integer') args[name] = Number(val);
            else if (type === 'boolean') args[name] = val === 'true';
            else args[name] = val;
        });
        resultEl.innerHTML = '<div class="text-muted small"><div class="spinner-border spinner-border-sm" role="status"></div> Invoking…</div>';
        fetch('/dashboard/mcp/' + demoId + '/invoke', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ tool: toolName, args: args })
        })
            .then(function(r) { return r.json().then(function(body) { return { ok: r.ok, body: body }; }); })
            .then(function(res) {
                var label = res.ok ? '<span class="text-success small">OK</span>'
                                   : '<span class="text-danger small">Error</span>';
                resultEl.innerHTML = '<div class="mb-1">' + label + '</div>' + prettyJson(res.body);
            })
            .catch(function(e) {
                resultEl.innerHTML = '<div class="text-danger small">Error: ' + escapeHtml(String(e && e.message || e)) + '</div>';
            });
    };

    function renderResourcesList(demoId, body) {
        var items = (body && (body.resources || body.resourceTemplates)) || [];
        if (!items.length) {
            document.getElementById('mcp-modal-body').innerHTML = '<p class="text-muted">No resources reported.</p>';
            return;
        }
        var html = '<p class="text-muted small mb-3">' + items.length + ' resource' +
            (items.length === 1 ? '' : 's') + ' advertised by MCP ' + escapeHtml(demoId) +
            '. Fill in a URI to read one.</p>';
        items.forEach(function(item, idx) {
            var uid = 'res-' + demoId + '-' + idx;
            var uri = item.uriTemplate || item.uri || '';
            html += cardOpen();
            html += '<h6 class="mb-1" style="color:var(--spring-text)"><code>' + escapeHtml(uri) + '</code></h6>';
            html += '<p class="text-muted small mb-2">' + escapeHtml(item.name || '') +
                (item.description ? ' — ' + escapeHtml(item.description) : '') + '</p>';
            html += '<div class="input-group input-group-sm mb-2">';
            html += '<span class="input-group-text">uri</span>';
            html += '<input type="text" class="form-control" id="' + uid + '-uri" value="' + escapeHtml(uri) + '">';
            html += '<button class="btn btn-spring-green" data-demo-id="' + escapeHtml(demoId) +
                '" data-uid="' + uid + '" onclick="mcpReadResource(this)">Read</button>';
            html += '</div>';
            html += '<div id="' + uid + '-result"></div>';
            html += cardClose();
        });
        document.getElementById('mcp-modal-body').innerHTML = html;
    }

    window.mcpReadResource = function(btn) {
        var demoId = btn.dataset.demoId;
        var uid = btn.dataset.uid;
        var uriInput = document.getElementById(uid + '-uri');
        var resultEl = document.getElementById(uid + '-result');
        if (!uriInput || !resultEl) return;
        var uri = uriInput.value;
        resultEl.innerHTML = '<div class="text-muted small"><div class="spinner-border spinner-border-sm" role="status"></div> Reading…</div>';
        fetch('/dashboard/mcp/' + demoId + '/resources/read?uri=' + encodeURIComponent(uri))
            .then(function(r) { return r.json().then(function(body) { return { ok: r.ok, body: body }; }); })
            .then(function(res) {
                var label = res.ok ? '<span class="text-success small">OK</span>'
                                   : '<span class="text-danger small">Error</span>';
                resultEl.innerHTML = '<div class="mb-1">' + label + '</div>' + prettyJson(res.body);
            })
            .catch(function(e) {
                resultEl.innerHTML = '<div class="text-danger small">Error: ' + escapeHtml(String(e && e.message || e)) + '</div>';
            });
    };

    function renderPromptsList(demoId, body) {
        var prompts = (body && body.prompts) || [];
        if (!prompts.length) {
            document.getElementById('mcp-modal-body').innerHTML = '<p class="text-muted">No prompts reported.</p>';
            return;
        }
        var html = '<p class="text-muted small mb-3">' + prompts.length + ' prompt' +
            (prompts.length === 1 ? '' : 's') + ' advertised by MCP ' + escapeHtml(demoId) + '.</p>';
        prompts.forEach(function(prompt, idx) {
            var uid = 'prm-' + demoId + '-' + idx;
            html += cardOpen();
            html += '<h6 class="mb-1" style="color:var(--spring-text)"><code>' + escapeHtml(prompt.name || '') + '</code></h6>';
            html += '<p class="text-muted small mb-2">' + escapeHtml(prompt.description || '') + '</p>';
            var args = prompt.arguments || [];
            if (args.length) {
                html += '<div class="mb-2 text-muted small">Arguments</div>';
                args.forEach(function(arg) {
                    html += '<div class="mb-2">';
                    html += '<label class="form-label small text-muted mb-1">' + escapeHtml(arg.name || '') +
                        (arg.required ? ' <span class="text-danger">*</span>' : '') + '</label>';
                    html += '<input type="text" class="form-control form-control-sm" ' +
                        'data-arg-name="' + escapeHtml(arg.name || '') + '" ' +
                        'placeholder="' + escapeHtml(arg.description || arg.name || '') + '">';
                    html += '</div>';
                });
            } else {
                html += '<div class="text-muted small mb-2">No arguments.</div>';
            }
            html += '<button class="btn btn-sm btn-spring-green" ' +
                'data-demo-id="' + escapeHtml(demoId) + '" ' +
                'data-prompt-name="' + escapeHtml(prompt.name || '') + '" ' +
                'data-uid="' + uid + '" onclick="mcpGetPrompt(this)">Get prompt</button>';
            html += '<div id="' + uid + '-result" class="mt-2"></div>';
            html += cardClose();
        });
        document.getElementById('mcp-modal-body').innerHTML = html;
    }

    window.mcpGetPrompt = function(btn) {
        var demoId = btn.dataset.demoId;
        var name = btn.dataset.promptName;
        var uid = btn.dataset.uid;
        var card = btn.closest('.mb-3');
        var resultEl = document.getElementById(uid + '-result');
        var args = {};
        card.querySelectorAll('input[data-arg-name]').forEach(function(inp) {
            if (inp.value) args[inp.dataset.argName] = inp.value;
        });
        resultEl.innerHTML = '<div class="text-muted small"><div class="spinner-border spinner-border-sm" role="status"></div> Getting prompt…</div>';
        fetch('/dashboard/mcp/' + demoId + '/prompts/get', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name: name, args: args })
        })
            .then(function(r) { return r.json().then(function(body) { return { ok: r.ok, body: body }; }); })
            .then(function(res) {
                var label = res.ok ? '<span class="text-success small">OK</span>'
                                   : '<span class="text-danger small">Error</span>';
                resultEl.innerHTML = '<div class="mb-1">' + label + '</div>' + prettyJson(res.body);
            })
            .catch(function(e) {
                resultEl.innerHTML = '<div class="text-danger small">Error: ' + escapeHtml(String(e && e.message || e)) + '</div>';
            });
    };

    // ===== Inspector-panel handlers (for 03 run + 04 trigger) =====

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
        el.innerHTML = header + prettyJson(res.body);
    }

    function escapeHtml(s) {
        return String(s == null ? '' : s)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    }

    // Pretty-print a JSON body, recursively unwrapping any nested JSON-string
    // fields (e.g. MCP's CallToolResult.content[0].text) and applying syntax
    // highlighting. Reuses helpers from response.js.
    function prettyJson(body) {
        try {
            if (typeof expandNestedJson === 'function' && typeof syntaxHighlightJson === 'function') {
                return '<pre class="response-json"><code>' +
                    syntaxHighlightJson(expandNestedJson(body)) + '</code></pre>';
            }
        } catch (e) { /* fall through */ }
        return '<pre class="response-json"><code>' +
            escapeHtml(JSON.stringify(body, null, 2)) + '</code></pre>';
    }
})();
