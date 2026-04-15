// Format a gateway body string for display:
// - Try to parse as JSON and pretty-print
// - Recursively expand nested JSON strings (e.g. tool arguments, tool results)
// - Unescape literal \n and \" from raw text
// - Strip trailing newlines
function formatJsonString(str) {
    if (!str) return str;
    try {
        var parsed = JSON.parse(str);
        var expanded = expandNestedJson(parsed);
        return syntaxHighlightJson(expanded);
    } catch (e) {
        // Not valid JSON — unescape common escape sequences
    }
    str = str.replace(/\\n/g, '\n').replace(/\\"/g, '"').replace(/\\\\/g, '\\');
    return str.replace(/\n+$/, '');
}

// Produce syntax-highlighted HTML from a parsed JSON value
function syntaxHighlightJson(obj) {
    var json = JSON.stringify(obj, null, 2);
    if (!json) return '';
    // Unescape \n inside strings for display, then HTML-escape everything
    json = json.replace(/\\n/g, '\n').replace(/\\"/g, '"');
    json = json.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    // Colorize tokens (order matters: keys first, then values)
    return json.replace(
        /("(?:[^"\\]|\\.)*")\s*:/g,
        '<span class="json-key">$1</span>:'
    ).replace(
        /:\s*("(?:[^"\\]|\\.)*")/g,
        function(match, val) { return ': <span class="json-string">' + val + '</span>'; }
    ).replace(
        /:\s*(-?\d+\.?\d*)/g,
        ': <span class="json-number">$1</span>'
    ).replace(
        /:\s*(true|false)/g,
        ': <span class="json-bool">$1</span>'
    ).replace(
        /:\s*(null)/g,
        ': <span class="json-null">$1</span>'
    );
}

// Recursively walk a parsed object and expand any string values that are valid JSON
function expandNestedJson(obj) {
    if (typeof obj === 'string') {
        try {
            var inner = JSON.parse(obj);
            if (typeof inner === 'object' && inner !== null) {
                return expandNestedJson(inner);
            }
        } catch (e) { /* not JSON, return as-is */ }
        return obj.replace(/\n+$/, '');
    }
    if (Array.isArray(obj)) {
        return obj.map(expandNestedJson);
    }
    if (typeof obj === 'object' && obj !== null) {
        var result = {};
        for (var key in obj) {
            if (obj.hasOwnProperty(key)) {
                result[key] = expandNestedJson(obj[key]);
            }
        }
        return result;
    }
    return obj;
}

// Documentation state
var _currentDocData = null;

// Copy curl command to clipboard
function copyCurl() {
    var curlLine = document.getElementById('curl-line-text');
    if (!curlLine) return;
    navigator.clipboard.writeText(curlLine.textContent).then(function() {
        var btn = document.getElementById('copy-btn');
        if (!btn) return;
        var original = btn.innerHTML;
        btn.innerHTML = '<i class="bi bi-check2"></i> Copied!';
        setTimeout(function() { btn.innerHTML = original; }, 1500);
    });
}

// Select an endpoint from the left panel
function selectEndpoint(el) {
    // Remove active from all
    document.querySelectorAll('.endpoint-item').forEach(function(item) {
        item.classList.remove('active');
    });
    el.classList.add('active');

    var path = el.dataset.path;
    var method = el.dataset.method;
    var description = el.dataset.description || '';
    var viewType = el.dataset.viewType || 'text';
    var paramsJson = el.dataset.params || '[]';

    // Update param bar
    var paramBar = document.getElementById('param-bar');
    if (!paramBar) return;

    var params;
    try { params = JSON.parse(paramsJson); } catch(e) { params = []; }

    var html = '<div class="d-flex align-items-center gap-2 mb-2">';
    html += '<span class="method-badge method-' + method.toLowerCase() + '">' + method + '</span>';
    html += '<code style="color:var(--spring-text)">' + escapeHtml(path) + '</code>';
    html += '</div>';
    if (description) {
        html += '<p class="text-muted small mb-3">' + escapeHtml(description) + '</p>';
    }
    html += '<form id="endpoint-form" onsubmit="tryEndpoint(); return false;">';
    html += '<input type="hidden" name="path" value="' + escapeHtml(path) + '">';
    html += '<input type="hidden" name="viewType" value="' + escapeHtml(viewType) + '">';
    html += '<div class="d-flex gap-2 align-items-end flex-wrap">';
    params.forEach(function(p) {
        html += '<div class="flex-grow-1">';
        html += '<label class="form-label small text-muted mb-1">' + escapeHtml(p.name) + '</label>';
        if (p.allowedValues && p.allowedValues.length > 0) {
            html += '<select class="form-select form-select-sm" name="' + escapeHtml(p.name) + '" onchange="refreshCurl()">';
            p.allowedValues.forEach(function(val) {
                var selected = val === (p.example || '') ? ' selected' : '';
                html += '<option value="' + escapeHtml(val) + '"' + selected + '>' + escapeHtml(val) + '</option>';
            });
            html += '</select>';
        } else {
            html += '<input type="text" class="form-control form-control-sm" name="' + escapeHtml(p.name) + '" value="" placeholder="' + escapeHtml(p.example || p.name) + '" oninput="refreshCurl()" onkeydown="handleParamKey(event)">';
        }
        html += '</div>';
    });
    html += '<button type="submit" class="btn btn-spring-green btn-sm" style="white-space:nowrap"><i class="bi bi-play-fill"></i> Try it</button>';
    html += '</div>';
    if (params.some(function(p) { return p.description; })) {
        html += '<div class="mt-1">';
        params.forEach(function(p) {
            if (p.description) {
                html += '<div class="form-text small" style="color:var(--spring-muted);font-size:11px">';
                html += '<span class="text-muted">' + escapeHtml(p.name) + ':</span> ' + escapeHtml(p.description);
                html += '</div>';
            }
        });
        html += '</div>';
    }
    html += '</form>';
    paramBar.innerHTML = html;

    // Clear response
    var responsePanel = document.getElementById('response-panel');
    if (responsePanel) responsePanel.innerHTML = '<p class="text-muted text-center mt-4">Click "Try it" to call this endpoint</p>';

    // Reset gateway panel
    resetGatewayPanel();

    // Update curl line after form is in the DOM
    refreshCurl();

    // Fetch inline documentation
    var codeSnippetEl = document.getElementById('code-snippet');
    if (codeSnippetEl) codeSnippetEl.style.display = 'none';
    _currentDocData = null;

    fetch('/dashboard/docs?path=' + encodeURIComponent(path))
        .then(function(resp) { return resp.ok ? resp.json() : null; })
        .then(function(data) {
            if (!data) return;
            _currentDocData = data;
            var snippetEl = document.getElementById('code-snippet');
            var contentEl = document.getElementById('code-snippet-content');
            if (snippetEl && contentEl && data.codeSnippet) {
                contentEl.innerHTML = docMarked.parse(data.codeSnippet);
                snippetEl.style.display = 'block';
            }
        })
        .catch(function() { /* docs are optional */ });
}

// Build curl line from current form state
function refreshCurl() {
    var form = document.getElementById('endpoint-form');
    if (!form) return;

    var path = form.querySelector('[name="path"]').value;
    var url = window.location.origin + path;
    var queryParts = [];

    form.querySelectorAll('input[type="text"], select').forEach(function(input) {
        var val = input.value || input.placeholder || '';
        if (val && val !== input.name) {
            // Use + for spaces in curl (more readable than %20 since URL is quoted)
            queryParts.push(input.name + '=' + encodeURIComponent(val).replace(/%20/g, '+'));
        }
    });
    if (queryParts.length > 0) url += '?' + queryParts.join('&');

    var curlText = document.getElementById('curl-line-text');
    if (curlText) curlText.textContent = 'curl "' + url + '"';
}

function tryEndpoint() {
    var form = document.getElementById('endpoint-form');
    if (!form) return;

    var path = form.querySelector('[name="path"]').value;
    var viewType = form.querySelector('[name="viewType"]').value;
    var responsePanel = document.getElementById('response-panel');
    if (!responsePanel) return;

    // Update curl line with current values
    refreshCurl();

    // Capture user input for chat view before clearing
    var userMessage = '';
    if (viewType === 'chat') {
        var textInputs = form.querySelectorAll('input[type="text"]');
        textInputs.forEach(function(input) {
            var val = input.value || input.placeholder || '';
            if (val && val !== input.name) userMessage += val;
        });
    }

    // Build proxy URL — use placeholder (example) as fallback when input is empty
    var proxyUrl = '/dashboard/proxy?path=' + encodeURIComponent(path);
    form.querySelectorAll('input[type="text"], select').forEach(function(input) {
        var val = input.value || input.placeholder || '';
        if (val && val !== input.name) proxyUrl += '&' + input.name + '=' + encodeURIComponent(val);
    });

    // Chat view: initialize chat container if needed, add user bubble, show loading
    if (viewType === 'chat') {
        if (!document.getElementById('chat-messages')) {
            responsePanel.innerHTML = '<div id="chat-messages" style="display:flex;flex-direction:column;gap:12px"></div>';
        }
        var chatMessages = document.getElementById('chat-messages');
        if (userMessage) {
            chatMessages.innerHTML += '<div style="align-self:flex-end;max-width:75%;background:var(--spring-green);color:#fff;padding:8px 14px;border-radius:14px 14px 2px 14px;font-size:13px">' + escapeHtml(userMessage) + '</div>';
        }
        chatMessages.innerHTML += '<div id="chat-loading" style="align-self:flex-start;color:var(--spring-muted);font-size:13px"><div class="spinner-border spinner-border-sm" role="status"></div> Thinking...</div>';
        responsePanel.scrollTop = responsePanel.scrollHeight;

        // Clear text inputs for next message
        form.querySelectorAll('input[type="text"]').forEach(function(input) { input.value = ''; });
        refreshCurl();
    } else {
        // Show loading for non-chat views
        responsePanel.innerHTML = '<div class="text-center text-muted mt-4"><div class="spinner-border spinner-border-sm" role="status"></div> Loading...</div>';
    }

    // Special handling for streaming — use fetch + ReadableStream to preserve whitespace
    if (viewType === 'streaming') {
        var streamUrl = path;
        var queryParts = [];
        form.querySelectorAll('input[type="text"], select').forEach(function(input) {
            if (input.value) queryParts.push(input.name + '=' + encodeURIComponent(input.value));
        });
        if (queryParts.length > 0) streamUrl += '?' + queryParts.join('&');

        responsePanel.innerHTML = '<div class="d-flex justify-content-between align-items-center mb-2"><span class="text-muted small text-uppercase">Response</span><span class="text-muted small" id="stream-status">Streaming...</span></div><pre class="response-text" id="stream-output"></pre>';
        var output = document.getElementById('stream-output');
        var statusEl = document.getElementById('stream-status');
        var startTime = performance.now();

        fetch(streamUrl)
            .then(function(resp) {
                var reader = resp.body.getReader();
                var decoder = new TextDecoder();
                function read() {
                    reader.read().then(function(result) {
                        if (result.done) {
                            var elapsed = Math.round(performance.now() - startTime);
                            statusEl.textContent = 'Done (' + elapsed + 'ms)';
                            fetchGatewayAudit();
                            return;
                        }
                        var chunk = decoder.decode(result.value, {stream: true});
                        // Strip SSE "data:" prefixes if present, preserving content
                        var text = chunk.replace(/^data:/gm, '').replace(/^\n$/gm, '');
                        output.textContent += text;
                        read();
                    });
                }
                read();
            })
            .catch(function(err) {
                output.textContent += '\n\nError: ' + err.message;
            });
        return;
    }

    // Regular fetch
    var startTime = performance.now();
    fetch(proxyUrl)
        .then(function(resp) {
            var elapsed = Math.round(performance.now() - startTime);
            var statusClass = resp.ok ? 'text-success' : 'text-danger';
            return resp.text().then(function(body) {
                var header = '<div class="d-flex justify-content-between align-items-center mb-2">';
                header += '<span class="text-muted small text-uppercase">Response</span>';
                header += '<span><span class="' + statusClass + ' small">' + resp.status + ' ' + (resp.ok ? 'OK' : 'Error') + '</span>';
                header += ' <span class="text-muted small ms-2">' + elapsed + 'ms</span></span></div>';

                var content = '';

                // Similarity view — render Score objects as horizontal bars
                if (viewType === 'similarity') {
                    try {
                        var scores = JSON.parse(body);
                        if (Array.isArray(scores) && scores.length > 0) {
                            content = '<div class="response-text">';
                            scores.forEach(function(item, idx) {
                                var score = item.similarity || 0;
                                var pct = Math.round(score * 100);
                                var a = item.a || '';
                                var b = item.b || '';
                                var label = a + '  ↔  ' + b;
                                var barColor = pct > 80 ? 'var(--spring-green)' : pct > 60 ? '#d4a84a' : '#6b9bd2';
                                content += '<div class="mb-2 d-flex align-items-center gap-2" style="font-size:13px">';
                                content += '<div style="min-width:50px;text-align:right;font-family:var(--spring-mono);color:var(--spring-green)">' + score.toFixed(3) + '</div>';
                                content += '<div style="width:60px;height:8px;background:var(--spring-border);border-radius:4px;flex-shrink:0">';
                                content += '<div style="width:' + pct + '%;height:100%;background:' + barColor + ';border-radius:4px"></div>';
                                content += '</div>';
                                content += '<div class="text-truncate" style="flex:1;color:var(--spring-text)" title="' + escapeHtml(label) + '">' + escapeHtml(label) + '</div>';
                                content += '</div>';
                            });
                            content += '</div>';
                            responsePanel.innerHTML = header + content;
                            return;
                        }
                    } catch(e) { /* fall through to generic rendering */ }
                }

                // Auto-detect JSON: if response starts with [ or {, try to parse and format it
                var isJson = viewType === 'json' || /^\s*[\[{]/.test(body);
                if (isJson) {
                    try {
                        var parsed = JSON.parse(body);
                        if (viewType !== 'json' && Array.isArray(parsed) && parsed.every(function(item) { return typeof item === 'string'; })) {
                            // Array of strings — render as numbered list
                            content = '<div class="response-text">';
                            parsed.forEach(function(item, idx) {
                                if (parsed.length > 1) {
                                    content += '<div class="mb-3"><span class="text-muted small">#' + (idx + 1) + '</span><pre class="mb-0 mt-1" style="white-space:pre-wrap">' + escapeHtml(item.trim()) + '</pre></div>';
                                } else {
                                    content += '<pre style="white-space:pre-wrap">' + escapeHtml(item.trim()) + '</pre>';
                                }
                            });
                            content += '</div>';
                        } else if (viewType !== 'json' && Array.isArray(parsed) && parsed.every(function(item) { return typeof item === 'object' && item !== null; })) {
                            // Array of objects — render as cards
                            content = '<div class="response-text">';
                            parsed.forEach(function(item, idx) {
                                content += '<div class="mb-3 p-3" style="background:var(--spring-bg);border:1px solid var(--spring-border);border-radius:6px">';
                                if (parsed.length > 1) content += '<div class="text-muted small mb-2">#' + (idx + 1) + '</div>';
                                Object.keys(item).forEach(function(key) {
                                    var val = item[key];
                                    var displayVal = (typeof val === 'string' && val.length > 200)
                                        ? '<pre style="white-space:pre-wrap;margin:4px 0 0;font-size:12px">' + escapeHtml(val) + '</pre>'
                                        : '<span style="color:var(--spring-text)">' + escapeHtml(String(val)) + '</span>';
                                    content += '<div class="mb-1"><span class="text-muted small" style="min-width:80px;display:inline-block">' + escapeHtml(key) + ':</span> ' + displayVal + '</div>';
                                });
                                content += '</div>';
                            });
                            content += '</div>';
                        } else {
                            content = '<pre class="response-json"><code>' + escapeHtml(JSON.stringify(parsed, null, 2)) + '</code></pre>';
                        }
                    } catch(e) {
                        content = '<pre class="response-text">' + escapeHtml(body) + '</pre>';
                    }
                } else {
                    content = '<pre class="response-text">' + escapeHtml(body) + '</pre>';
                }

                if (viewType === 'chat') {
                    // Remove loading indicator, append AI bubble
                    var loading = document.getElementById('chat-loading');
                    if (loading) loading.remove();
                    var chatMessages = document.getElementById('chat-messages');
                    if (chatMessages) {
                        var aiText = body;
                        // Try to unwrap JSON string arrays
                        try {
                            var parsed2 = JSON.parse(body);
                            if (typeof parsed2 === 'string') aiText = parsed2;
                            if (Array.isArray(parsed2) && parsed2.length === 1 && typeof parsed2[0] === 'string') aiText = parsed2[0];
                        } catch(e2) {}
                        chatMessages.innerHTML += '<div style="align-self:flex-start;max-width:75%;background:var(--spring-card);border:1px solid var(--spring-border);color:var(--spring-text);padding:8px 14px;border-radius:14px 14px 14px 2px;font-size:13px"><pre style="white-space:pre-wrap;margin:0;font-family:var(--spring-font);font-size:13px">' + escapeHtml(aiText.trim()) + '</pre><div class="text-muted" style="font-size:10px;margin-top:4px;text-align:right">' + elapsed + 'ms</div></div>';
                        responsePanel.scrollTop = responsePanel.scrollHeight;
                    }
                } else {
                    responsePanel.innerHTML = header + content;
                }
                fetchGatewayAudit();
            });
        })
        .catch(function(err) {
            if (viewType === 'chat') {
                var loading = document.getElementById('chat-loading');
                if (loading) loading.remove();
                var chatMessages = document.getElementById('chat-messages');
                if (chatMessages) {
                    chatMessages.innerHTML += '<div style="align-self:flex-start;max-width:75%;background:var(--error-bg);border:1px solid var(--error-border);color:var(--error-text);padding:8px 14px;border-radius:14px 14px 14px 2px;font-size:13px">Error: ' + escapeHtml(err.message) + '</div>';
                }
            } else {
                responsePanel.innerHTML = '<div class="text-danger mt-4"><i class="bi bi-exclamation-triangle"></i> Error: ' + escapeHtml(err.message) + '</div>';
            }
        });
}

function handleParamKey(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
        event.preventDefault();
        tryEndpoint();
    }
}

function escapeHtml(text) {
    if (text == null) return '';
    var div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Documentation modal
function showDocModal() {
    if (!_currentDocData || !_currentDocData.fullSection) return;
    var modal = document.getElementById('doc-modal');
    var body = document.getElementById('doc-modal-body');
    if (!modal || !body) return;

    body.innerHTML = docMarked.parse(_currentDocData.fullSection);

    // Render mermaid diagrams
    var mermaidEls = body.querySelectorAll('.mermaid');
    if (mermaidEls.length > 0) {
        mermaid.run({ nodes: mermaidEls });
    }

    modal.style.display = 'flex';
    document.body.style.overflow = 'hidden';
}

function closeDocModal(event) {
    if (event && event.target !== event.currentTarget) return;
    var modal = document.getElementById('doc-modal');
    if (modal) modal.style.display = 'none';
    document.body.style.overflow = '';
}

document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') closeDocModal();
});

// ===== Gateway Panel =====
var GATEWAY_URL = 'http://localhost:7777/audit/latest';
var _lastGatewayAuditId = null;

function resetGatewayPanel() {
    var panel = document.getElementById('gateway-panel');
    if (!panel) return;
    panel.style.display = 'none';
    var body = document.getElementById('gateway-body');
    if (body) body.style.display = 'none';
    var chevron = document.getElementById('gateway-chevron');
    if (chevron) chevron.className = 'bi bi-chevron-down';
    var reqBody = document.getElementById('gateway-request-body');
    if (reqBody) reqBody.textContent = '—';
    var resBody = document.getElementById('gateway-response-body');
    if (resBody) resBody.textContent = '—';
    var meta = document.getElementById('gateway-request-meta');
    if (meta) meta.textContent = '';
    // Snapshot current audit ID so we can detect fresh entries after the next call
    fetch(GATEWAY_URL).then(function(r) {
        if (!r.ok || r.status === 204) { _lastGatewayAuditId = null; return; }
        return r.json();
    }).then(function(data) {
        _lastGatewayAuditId = data ? data.id : null;
    }).catch(function() { _lastGatewayAuditId = null; });
}

function toggleGatewayPanel() {
    var body = document.getElementById('gateway-body');
    var chevron = document.getElementById('gateway-chevron');
    if (!body) return;
    if (body.style.display === 'none') {
        body.style.display = 'block';
        if (chevron) chevron.className = 'bi bi-chevron-up';
    } else {
        body.style.display = 'none';
        if (chevron) chevron.className = 'bi bi-chevron-down';
    }
}

function openGatewayModal() {
    var reqBody = document.getElementById('gateway-request-body');
    var resBody = document.getElementById('gateway-response-body');
    var meta = document.getElementById('gateway-request-meta');
    var modalReq = document.getElementById('modal-gateway-request-body');
    var modalRes = document.getElementById('modal-gateway-response-body');
    var modalMeta = document.getElementById('modal-gateway-request-meta');
    if (modalReq && reqBody) modalReq.innerHTML = reqBody.innerHTML;
    if (modalRes && resBody) modalRes.innerHTML = resBody.innerHTML;
    if (modalMeta && meta) modalMeta.textContent = meta.textContent;
    var modal = new bootstrap.Modal(document.getElementById('gatewayModal'));
    modal.show();
}

function fetchGatewayAudit() {
    var panel = document.getElementById('gateway-panel');
    if (!panel) return;

    // Brief delay to let the gateway finish logging
    setTimeout(function() {
        fetch(GATEWAY_URL)
            .then(function(resp) {
                if (!resp.ok || resp.status === 204) return null;
                return resp.json();
            })
            .then(function(data) {
                if (!data) return;
                // Only show if this is a fresh entry (different from snapshot taken on endpoint select)
                if (data.id === _lastGatewayAuditId) return;

                panel.style.display = 'block';

                // Request meta
                var metaEl = document.getElementById('gateway-request-meta');
                if (metaEl) {
                    metaEl.textContent = data.request.method + ' ' + data.request.uri;
                }

                // Request body — pretty-print and syntax-highlight JSON
                var reqBodyEl = document.getElementById('gateway-request-body');
                if (reqBodyEl) {
                    reqBodyEl.innerHTML = formatJsonString(data.request.body);
                }

                // Response body — pretty-print and syntax-highlight JSON
                var resBodyEl = document.getElementById('gateway-response-body');
                if (resBodyEl) {
                    resBodyEl.innerHTML = formatJsonString(data.response.body);
                }

                // Auto-expand
                var body = document.getElementById('gateway-body');
                var chevron = document.getElementById('gateway-chevron');
                if (body) body.style.display = 'block';
                if (chevron) chevron.className = 'bi bi-chevron-up';
            })
            .catch(function() {
                // Gateway not running — hide panel silently
                panel.style.display = 'none';
            });
    }, 500);
}
