<!DOCTYPE html
    PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">

<head>
    <!-- 引入 JSON5 解析库 -->
    <script src="https://cdn.jsdelivr.net/npm/json5@2.2.3/dist/index.min.js"></script>
    <meta http-equiv="X-UA-Compatible" content="IE=Edge">
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <meta HTTP-EQUIV="Pragma" CONTENT="no-cache">
    <meta HTTP-EQUIV="Expires" CONTENT="-1">
    <link rel="shortcut icon" href="images/favicon.png">
    <link rel="icon" href="images/favicon.png">
    <title>Clash UI Management</title>
    <link rel="stylesheet" type="text/css" href="index_style.css">
    <link rel="stylesheet" type="text/css" href="form_style.css">
    <script language="JavaScript" type="text/javascript" src="/state.js"></script>
    <script language="JavaScript" type="text/javascript" src="/general.js"></script>
    <script language="JavaScript" type="text/javascript" src="/popup.js"></script>
    <script language="JavaScript" type="text/javascript" src="/help.js"></script>
    <script type="text/javascript" language="JavaScript" src="/validator.js"></script>

    <script src="https://cdnjs.cloudflare.com/ajax/libs/ace/1.36.5/ace.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/ace/1.36.5/theme-monokai.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/ace/1.36.5/mode-json.js"></script>

    <style>
        .error-marker {
            position: absolute;
            background: rgba(255, 0, 0, 0.2);
        }

        .highlightError {
            background: rgba(255, 0, 0, 0.2);
        }

        /* Override for specific tables */
        #clash_proxies span,
        #clash_proxy_groups span,
        #clash_rules span,
        #clash_dns span {
            background-color: transparent;
            /* color: inherit ; */
        }
    </style>
    <script>
        // JSON5=superjson;
        var custom_settings = <% get_custom_settings(); %>;
        var clash_settings = {};
        var clash_service_status = "stopped";
        var clash_proxies = {};
        var proxyHealthStatus = {};
        const fields = [
            { id: 'clash_external_controller', default: '', key: 'clash_external_controller', source: "custom", "type": "string"},
            // { id: 'clash_version', default: '', key: 'clash_version', source: "custom", "type": "string"},
            { id: 'clash_secret', default: '', key: 'clash_secret', source: "custom","type": "string" },
            { id: 'clash_socks_port', default: '0', key: 'socks-port', source: "clash", "type": "int" },
            { id: 'clash_allow_lan', default: '', key: 'allow-lan', source: "clash", "type": "bool" },
            { id: 'clash_mode', default: 'Rule', key: 'mode', source: "clash", "type": "string"},

            { id: 'clash_redir_port', default: '0', key: 'redir-port', source: "clash","type": "int" },
            { id: 'clash_tproxy_port', default: '0', key: 'tproxy-port', source: "clash","type": "int" },
            { id: 'clash_mixed_port', default: '0', key: 'mixed-port', source: "clash", "type": "int"},
            { id: 'clash_bind_address', default: '', key: 'bind-address', source: "clash", "type": "string"},
            { id: 'clash_port', default: '0', key: 'port', source: "clash", "type": "int"},
            { id: 'clash_ipv6', default: 'false', key: 'ipv6', source: "clash", "type": "bool"},
            { id: 'clash_log-level', default: 'info', key: 'log-level', source: "clash", "type": "string"},
            // { id: 'clash_proxy_groups', default: '', key: 'proxy-groups', source: "clash", }
        ];

        // 从 http://192.168.50.1:9090/configs 读取配置
        function fetchClashConfig() {
            let port = custom_settings.clash_external_controller.split(':')[1];
            let token = custom_settings.clash_secret;
            fetch(`http://${window.location.hostname}:${port}/yml/json`, {
                headers: new Headers({
                    'Authorization': `Bearer ${token}`
                })
            })
                .then(response => response.json())
                .then(data => {
                    console.log('Clash config:', data);
                    // Convert the fetched data to a JavaScript object
                    clash_settings = data;
                    clash_service_status = "running";
                    updateClashConfig(); // Reinitialize the form with the fetched data
                     fetchClashVersion();
                })
                .catch(error => {
                    clash_service_status = "stopped";
                    // console.error('Error fetching Clash config:', error);
                    document.getElementById('clash_service_status').value = 'stopped';
                    alert('Clash 服务检测异常，可能没启动: ' + error.message);
                });
        }
        // 从 http://192.168.50.1:9090/version 读取版本配置
        function fetchClashVersion() {
            document.getElementById('clash_version').innerText=custom_settings.clash_version;
        }

        // Fetch proxies list
        function fetchProxies() {
            let port = custom_settings.clash_external_controller.split(':')[1];
            let token = custom_settings.clash_secret;

            fetch(`http://${window.location.hostname}:${port}/proxies`, {
                headers: new Headers({
                    'Authorization': `Bearer ${token}`
                })
            })
            .then(response => response.json())
            .then(data => {
                clash_proxies = data;

                // Filter: only show actual proxy types (Shadowsocks, VMess, Trojan, HTTP, Socks5)
                // Exclude: system types + groups (Selector, URLTest, Fallback, LoadBalance, Relay)
                let allProxies = data.proxies || {};
                let proxyNodes = {};
                let excludeTypes = [
                    'Compatible', 'Direct', 'Pass', 'Reject', 'RejectDrop', 'RejectSimple',
                    'Selector', 'URLTest', 'Fallback', 'LoadBalance', 'Relay', 'FallbackSingle', 'Static'
                ];

                for (let name in allProxies) {
                    let proxy = allProxies[name];
                    // Include if not in exclude list
                    if (excludeTypes.indexOf(proxy.type) === -1) {
                        proxyNodes[name] = proxy;
                    }
                }

                clash_proxies.proxyNodes = proxyNodes;
                renderProxyList();

                // Auto test all proxies
                setTimeout(testAllProxies, 500);
            })
            .catch(error => {
                console.error('Error fetching proxies:', error);
            });
        }

        // Render proxy list with status
        function renderProxyList() {
            let container = document.getElementById('proxy_list_container');
            if (!container) return;

            let proxyNodes = clash_proxies.proxyNodes || {};

            if (Object.keys(proxyNodes).length === 0) {
                container.innerHTML = '<p>未找到代理节点</p>';
                return;
            }

            let html = '<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable">';
            html += '<thead><tr><th>名称</th><th>类型</th><th>状态</th><th>延迟</th><th>操作</th></tr></thead><tbody>';

            for (let name in proxyNodes) {
                let proxy = proxyNodes[name];
                let status = proxyHealthStatus[name] || { status: 'unknown', delay: null };
                let statusHtml = '';
                let rowStyle = '';
                if (status.status === 'ok') {
                    statusHtml = '<span style="font-size:16px;">✅ 可用</span>';
                    rowStyle = 'background:#e8f5e9;';
                } else if (status.status === 'error') {
                    statusHtml = '<span style="font-size:16px;">❌ 失败</span>';
                    rowStyle = 'background:#ffebee;';
                } else if (status.status === 'testing') {
                    statusHtml = '<span style="font-size:16px;">🔄 测试中...</span>';
                    rowStyle = 'background:#fff3e0;';
                } else {
                    statusHtml = '<span style="font-size:16px;">⏳ 待测试</span>';
                }
                let delayText = status.delay ? status.delay + 'ms' : '-';

                html += '<tr style="' + rowStyle + '" id="row_' + name + '">';
                html += '<td><strong>' + name + '</strong></td>';
                html += '<td>' + proxy.type + '</td>';
                html += '<td id="status_' + name + '">' + statusHtml + '</td>';
                html += '<td id="delay_' + name + '">' + delayText + '</td>';
                html += '<td><button type="button" class="button_gen" onclick="testProxy(\'' + name + '\')">🔄 测速</button></td>';
                html += '</tr>';
            }
            html += '</tbody></table>';
            container.innerHTML = html;
        }

        // Test single proxy latency
        function testProxy(name) {
            let port = custom_settings.clash_external_controller.split(':')[1];
            let token = custom_settings.clash_secret;
            let url = `http://${window.location.hostname}:${port}/proxies/${encodeURIComponent(name)}/delay?timeout=5000&url=http://www.gstatic.com/generate_204`;

            proxyHealthStatus[name] = { status: 'testing', delay: null };
            document.getElementById('status_' + name).innerHTML = '<span style="font-size:16px;">🔄 测试中...</span>';
            document.getElementById('delay_' + name).textContent = '-';
            document.getElementById('row_' + name).style.background = '#fff3e0';

            fetch(url, {
                headers: new Headers({
                    'Authorization': `Bearer ${token}`
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.delay) {
                    proxyHealthStatus[name] = { status: 'ok', delay: data.delay };
                    document.getElementById('status_' + name).innerHTML = '<span style="font-size:16px;">✅ 可用</span>';
                    document.getElementById('delay_' + name).textContent = data.delay + 'ms';
                    document.getElementById('row_' + name).style.background = '#e8f5e9';
                } else {
                    throw new Error('No delay data');
                }
            })
            .catch(error => {
                proxyHealthStatus[name] = { status: 'error', delay: null };
                document.getElementById('status_' + name).innerHTML = '<span style="font-size:16px;">❌ 失败</span>';
                document.getElementById('delay_' + name).textContent = '-';
                document.getElementById('row_' + name).style.background = '#ffebee';
                console.error('Delay test failed:', error);
            });
        }

        // Test all proxies
        function testAllProxies() {
            let proxyNodes = clash_proxies.proxyNodes || {};
            for (let name in proxyNodes) {
                testProxy(name);
            }
        }


        // 格式化代码
        function formatCode(editor) {
            try {
                // 判断一下 editor 是不是字符串，如果是字符串，就转换为 editor 对象
                if (typeof editor === 'string') {
                    editor = ace.edit(editor);
                }
                const parsed = JSON5.parse(editor.getValue());
                const formatted = JSON5.stringify(parsed, null, 2);
                editor.setValue(formatted);
                // editor.session.gotoLine(0);
                clearError(editor);
            } catch (e) {
                console.error(e);
                // showError(e);
            }
        }
        // 清除错误
        function clearError(editor) {
            // if (errorMarker) {
            //     editor.session.removeMarker(errorMarker);
            //     errorMarker = null;
            // }
            editor.session.setAnnotations([]);
        }

        function saveClashConfig(configData) {
            let token = custom_settings.clash_secret;
            let port = custom_settings.clash_external_controller.split(':')[1];
            console.log('Saving Clash config:');
            console.log( configData);
            fetch(`http://${window.location.hostname}:${port}/yml/json`, {
                method: 'PUT',
                headers: new Headers({
                    'Content-Type': 'application/json',

                    'Authorization': `Bearer ${token}`

                }),
                body: JSON.stringify(configData)
            })
                .then(response => {
                    if (!response.ok) {
                        return response.text().then(text => {
                            throw new Error(`HTTP error! status: ${response.status}, message: ${text}`);
                        });
                    }
                    return response.text();
                })
                .then(data => {
                    console.log('Config saved:', data);
                    // 提交成功后，重新加载配置
                    showLoading();
                    document.form.submit();
                })
                .catch(error => {
                    console.error('Error saving config:', error);
                    alert('保存配置失败: ' + error.message);
                });
        }
        function showEditorError(editor, error) {
            // clearError();
            console.log(editor.container.id + ' Error:', error);
            // 解析错误位置
            const match = error.message.match(/at\s+(\d+):(\d+)/);
            const pos = match ? {
                row: parseInt(match[1], 10) - 1,
                column: parseInt(match[2], 10) - 1
            } : { row: 0, column: 0 };
            // console.log('Error position:', pos);

            editor.session.setAnnotations([{
                row: pos.row,
                column: pos.column,
                text: error.message,
                type: "error"
            }]);
            // 添加错误标记
            errorMarker = editor.session.addMarker(
                new ace.Range(pos.row, pos.column, pos.row, Infinity),
                "error-marker",
                "text"
            );

        }
        function set_json_editor(editor_id, data) {
            console.log('Setting JSON data to editor:', editor_id, data);
            let editor = ace.edit(editor_id);

            editor.setValue(JSON5.stringify(data, null, 2), -1);
        }
        function get_json_data(editor_id) {
            let editor = ace.edit(editor_id);
            console.log('Getting JSON data from editor:', editor_id);
            let data = {};
            try {
                let value = editor.getValue().trim();
                if (!value) {
                    return {};
                }
                data = JSON5.parse(value);
                editor.session.setAnnotations([]);
            } catch (e) {
                showEditorError(editor, e);
                // 抛异常
                throw e;
            }
            return data;
        }
        function initial_json_editor(editor_id) {
            const editor = ace.edit(editor_id);
            editor.setTheme("ace/theme/monokai");
            editor.session.setMode("ace/mode/json5");
            editor.session.setUseWrapMode(true);
            editor.setShowPrintMargin(false);
            editor.session.setTabSize(2);
            editor.session.setUseSoftTabs(true);
            // 显示行号
            // editor.renderer.setOption("showLineNumbers", true);
            editor.renderer.setOption("showGutter", true);
            // 强制启用严格模式（可选）
            editor.session.on('changeAnnotation', function () {
                const annotations = editor.session.getAnnotations();
                annotations.forEach(ann => {
                    if (ann.text.match(/mapping values are not allowed/)) {
                        ann.type = "error";  // 将警告提升为错误
                    }
                });
            });
            // 显示错误
            editor.session.on('change', function () {
                console.log(editor.container.id +' editor changed');
                console.log(editor.getValue());
                try {
                    JSON5.parse(editor.getValue());
                    editor.session.setAnnotations([]);
                } catch (e) {
                    showEditorError(editor, e);
                }
            });
        }
        function initial() {
            SetCurrentPage();
            show_menu();

            // 等待 ace 加载完成
            function waitForAce() {
                if (typeof ace !== 'undefined') {
                    initial_json_editor("clash_proxies");
                    initial_json_editor("clash_proxy_groups");
                    initial_json_editor("clash_rules");
                    initial_json_editor("clash_dns");
                    document.querySelector(".tablinks").click();
                    fetchClashConfig();

                } else {
                    setTimeout(waitForAce, 100);
                }
            }
            waitForAce();
        }
        function updateClashConfig() {
            /* Update the form fields with the current values */
            fields.forEach(field => {
                let source = field.source == "custom" ? custom_settings : clash_settings;
                document.getElementById(field.id).value = source[field.key] || field.default;
            });
            document.getElementById('clash_service_status').value = clash_service_status;
            set_json_editor("clash_proxies", clash_settings['proxies']);
            set_json_editor("clash_proxy_groups", clash_settings['proxy-groups']);
            set_json_editor("clash_rules", clash_settings['rules']);
            set_json_editor("clash_dns", clash_settings['dns']);
            updateProxyCommands();
            fetchProxies();
        }

        function SetCurrentPage() {
            /* Set the proper return pages */
            document.form.next_page.value = window.location.pathname.substring(1);
            document.form.current_page.value = window.location.pathname.substring(1);
        }

        function applySettings() {
            /* Retrieve value from input fields, and store in object */
            fields.forEach(field => {
                let value = document.getElementById(field.id).value;
                if (value === '') {
                    alert(`${field.key} 不能为空`);
                    throw new Error(`${field.key} 不能为空`);
                }

                   // 这里一些字段必须是整型,按照filed.type判断和处理
                if(field.type == "int"){
                    value = parseInt(value);
                }else   if(field.type == "bool"){
                    value = value == "true";
                }


                if(field.source == "custom"){
                    custom_settings[field.key] = value;
                }
                else{
                    clash_settings[field.key] = value;
                }

                // field.source[field.key] = value;
            });
            try {
                clash_settings["dns"] = get_json_data("clash_dns");
                clash_settings["proxies"] = get_json_data("clash_proxies");
                clash_settings["proxy-groups"] = get_json_data("clash_proxy_groups");
                clash_settings["rules"] = get_json_data("clash_rules");
            } catch (e) {
                console.error('Error updating Clash settings:', e);
                return;
            }
            /* Store object as a string in the amng_custom hidden input field */
            document.getElementById('amng_custom').value = JSON.stringify(custom_settings);
            // console.log('Updating Clash settings:', clash_settings);
            saveClashConfig(clash_settings);
            /* Apply */

        }

        function restartService() {
            /* Restart the Clash service */
            showLoading();
            document.form.action_script.value = "restart_clash";
            document.form.submit();
        }

        function openTab(evt, tabName) {
            var i, tabcontent, tablinks;
            tabcontent = document.getElementsByClassName("tabcontent");
            for (i = 0; i < tabcontent.length; i++) {
                tabcontent[i].style.display = "none";
            }
            tablinks = document.getElementsByClassName("tablinks");
            for (i = 0; i < tablinks.length; i++) {
                tablinks[i].className = tablinks[i].className.replace(" active", "");
            }
            document.getElementById(tabName).style.display = "block";
            evt.currentTarget.className += " active";
        }

        // Update terminal proxy commands display
        function updateProxyCommands() {
            if (!custom_settings.clash_external_controller) return;

            var controller = custom_settings.clash_external_controller;
            var parts = controller.split(':');
            var port = parts[1] || "9090";

            var lanIp = window.location.hostname;
            var httpPortEl = document.getElementById('clash_port');
            var socksPortEl = document.getElementById('clash_socks_port');
            var httpPort = httpPortEl ? httpPortEl.value : port;
            var socksPort = socksPortEl ? socksPortEl.value : "7891";

            var cmd = "export https_proxy=http://" + lanIp + ":" + httpPort + " http_proxy=http://" + lanIp + ":" + httpPort + " all_proxy=socks5://" + lanIp + ":" + socksPort;

            var proxyCmdEl = document.getElementById('proxy_command');
            if (proxyCmdEl) {
                proxyCmdEl.textContent = cmd;
            }
        }

        // Copy proxy command to clipboard
        function copyProxyCommand() {
            var cmd = document.getElementById('proxy_command').textContent;
            if (navigator.clipboard && window.isSecureContext) {
                navigator.clipboard.writeText(cmd).then(function() {
                    alert('已复制到剪贴板');
                }, function(err) {
                    console.error('复制失败: ', err);
                });
            } else {
                // Fallback for non-HTTPS
                var textArea = document.createElement("textarea");
                textArea.value = cmd;
                textArea.style.position = "fixed";
                textArea.style.left = "-9999px";
                textArea.style.top = "-9999px";
                document.body.appendChild(textArea);
                textArea.focus();
                textArea.select();
                try {
                    document.execCommand('copy');
                    alert('已复制到剪贴板');
                } catch (err) {
                    console.error('复制失败: ', err);
                    alert('复制失败，请手动复制');
                }
                document.body.removeChild(textArea);
            }
        }

        // Open Web UI in new tab
        function openWebUI() {
            var controller = custom_settings.clash_external_controller || "127.0.0.1:9090";
            var parts = controller.split(':');
            var port = parts[1] || "9090";
            var lanIp = window.location.hostname;
            var webUiUrl = "http://" + lanIp + ":" + port + "/ui/";
            window.open(webUiUrl, '_blank');
        }


        // document.addEventListener("DOMContentLoaded", function () {

        //     const editor_clash_proxies = ace.edit("clash_proxies");
        //     editor_clash_proxies.setTheme("ace/theme/monokai");
        //     editor_clash_proxies.session.setMode("ace/mode/yaml");

        //     const editor_clash_rules = ace.edit("clash_rules");
        //     editor_clash_rules.setTheme("ace/theme/monokai");
        //     editor_clash_rules.session.setMode("ace/mode/yaml");

        //     document.querySelector(".tablinks").click();
        //     fetchClashConfig(); // Fetch the config on page load

        // });
    </script>
</head>

<body onload="initial();" class="bg">
    <div id="TopBanner"></div>
    <div id="Loading" class="popup_bg"></div>
    <iframe name="hidden_frame" id="hidden_frame" src="" width="0" height="0" frameborder="0"></iframe>
    <form method="post" name="form" action="start_apply.htm" target="hidden_frame">
        <input type="hidden" name="current_page" value="MyPage.asp">
        <input type="hidden" name="next_page" value="MyPage.asp">
        <input type="hidden" name="group_id" value="">
        <input type="hidden" name="modified" value="0">
        <input type="hidden" name="action_mode" value="apply">
        <input type="hidden" name="action_wait" value="5">
        <input type="hidden" name="first_time" value="">
        <input type="hidden" name="action_script" value="restart_clash">
        <input type="hidden" name="preferred_lang" id="preferred_lang" value="<% nvram_get(" preferred_lang"); %>">
        <input type="hidden" name="firmver" value="<% nvram_get(" firmver"); %>">
        <input type="hidden" name="amng_custom" id="amng_custom" value="">

        <table class="content" align="center" cellpadding="0" cellspacing="0">
            <tr>
                <td width="17">&nbsp;</td>
                <td valign="top" width="202">
                    <div id="mainMenu"></div>
                    <div id="subMenu"></div>
                </td>
                <td valign="top">
                    <div id="tabMenu" class="submenuBlock"></div>
                    <table width="98%" border="0" align="left" cellpadding="0" cellspacing="0">
                        <tr>
                            <td align="left" valign="top">
                                <table width="760px" border="0" cellpadding="5" cellspacing="0" bordercolor="#6b8fa3"
                                    class="FormTitle" id="FormTitle">
                                    <tr>
                                        <td bgcolor="#4D595D" colspan="3" valign="top">
                                            <div>&nbsp;</div>
                                            <div class="formfonttitle">Clash UI Management</div>
                                            <div style="margin:10px 0 10px 5px;" class="splitLine"></div>
                                            <div class="formfontdesc">Manage Clash configuration and services</div>

                                            <!-- Tabs for different sections -->
                                            <div class="tabs">
                                                <button type="button" class="tablinks tabClicked"
                                                    onclick="openTab(event, 'BasicInfo')">Basic Info</button>
                                                <button type="button" class="tablinks tabClicked"
                                                    onclick="openTab(event, 'ProxyStatus')">代理节点</button>
                                                <button type="button" class="tablinks tabClicked"
                                                    onclick="openTab(event, 'ProxyConfig')">Proxy Configuration</button>
                                                <button type="button" class="tablinks tabClicked"
                                                    onclick="openTab(event, 'RuleConfig')">Rule Configuration</button>
                                                <button type="button" class="tablinks tabClicked"
                                                    onclick="openTab(event, 'DNSConfig')">DNS Configuration</button>
                                            </div>

                                            <br>
                                            <!-- Proxy Configuration Tab -->
                                            <div id="BasicInfo" class="tabcontent">
                                                <table width="100%" border="1" align="center" cellpadding="4"
                                                    cellspacing="0" bordercolor="#6b8fa3" class="FormTable">
                                                    <tr>
                                                        <th>Clash Service Status</th>
                                                        <td>
                                                            <select id="clash_service_status"
                                                                title="Clash Service Status">
                                                                <option value="stopped">Stopped</option>
                                                                <option value="running">Running</option>
                                                            </select>
                                                            <span>服务的状态</span>
                                                        </td>
                                                    </tr>
                                                    <tr>
                                                        <th>clash version</th>
                                                        <td>

                                                            <span  id="clash_version" >Clash 核心的版本信息</span>
                                                        </td>
                                                    </tr>
                                                    <tr>
                                                        <th>External Controller</th>
                                                        <td>
                                                            <input type="text" maxlength="20" class="input_25_table"
                                                                id="clash_external_controller" autocorrect="off"
                                                                autocapitalize="off" title="External Controller"
                                                                placeholder="Enter External Controller">
                                                            <span>Restful api 服务的监听地址</span>
                                                        </td>
                                                    </tr>
                                                    <tr>
                                                        <th>Restful API Authorization</th>
                                                        <td>
                                                            <input type="text" maxlength="20" class="input_25_table"
                                                                id="clash_secret" autocorrect="off" autocapitalize="off"
                                                                title="Bearer Tokensr"
                                                                placeholder="Enter Bearer Tokens">
                                                            <span>Restful Api 认证的 token</span>
                                                        </td>
                                                    </tr>
                                                    <tr>
                                                        <th>Http(s) Port</th>
                                                        <td>
                                                            <input type="text" maxlength="5" class="input_6_table"
                                                                id="clash_port" autocorrect="off" autocapitalize="off"
                                                                title="Http(s) Port"
                                                                onkeypress="return validator.isNumber(this,event);"
                                                                placeholder="Enter Port">
                                                            <span id="">Default: 0。 Http(s)协议的代理端口。</span>
                                                        </td>
                                                    </tr>
                                                    <tr>
                                                        <th>Socks Port</th>
                                                        <td>
                                                            <input type="text" maxlength="5" class="input_6_table"
                                                                id="clash_socks_port" autocorrect="off"
                                                                autocapitalize="off" title="Socks Port"
                                                                onkeypress="return validator.isNumber(this,event);"
                                                                placeholder="Enter Socks Port">
                                                            <span id="clash_socks_port_default">Default: 7891</span>
                                                        </td>
                                                    </tr>
                                                    <tr>
                                                        <th>Redir Port</th>
                                                        <td>
                                                            <input type="text" maxlength="5" class="input_25_table"
                                                                id="clash_redir_port" autocorrect="off"
                                                                autocapitalize="off" title="Redir Port"
                                                                placeholder="Enter Redir Port">
                                                            <span> "0":表示未开启这个服务 </span>
                                                        </td>
                                                    </tr>
                                                    <tr>
                                                        <th>TProxy Port</th>
                                                        <td>
                                                            <input type="text" maxlength="5" class="input_6_table"
                                                                id="clash_tproxy_port" autocorrect="off"
                                                                autocapitalize="off" title="TProxy Port"
                                                                placeholder="Enter TProxy Port">
                                                            <span> "0":表示未开启这个服务 </span>
                                                        </td>
                                                    </tr>
                                                    <tr>
                                                        <th>Mixed Port</th>
                                                        <td>
                                                            <input type="text" maxlength="5" class="input_6_table"
                                                                id="clash_mixed_port" autocorrect="off"
                                                                autocapitalize="off" title="Mixed Port"
                                                                placeholder="Enter Mixed Port">
                                                            <span> "0":表示未开启这个服务 </span>
                                                        </td>
                                                    </tr>

                                                    <tr>
                                                        <th>Allow LAN</th>
                                                        <td>
                                                            <select id="clash_allow_lan" title="Allow LAN">
                                                                <option value="true" title="True">true</option>
                                                                <option value="false" title="False">false</option>
                                                            </select>
                                                            <span>设置为 true 以允许来自其他 LAN IP 地址的连接</span>
                                                        </td>
                                                    </tr>
                                                    <tr>
                                                        <th>Ipv6</th>
                                                        <td>
                                                            <select id="clash_ipv6" title="Ipv6">
                                                                <option value="true" title="True">true</option>
                                                                <option value="false" title="False">false</option>
                                                            </select>
                                                            <span>当设置为 false 时, 解析器不会将主机名解析为 IPv6 地址。</span>
                                                        </td>
                                                    </tr>

                                                    <tr>
                                                        <th>Log level</th>
                                                        <td>
                                                            <select id="clash_log-level" title="Log Level">
                                                                <option value="info" title="True">info</option>
                                                                <option value="warning" title="Warning">warning</option>
                                                                <option value="error" title="Error">error</option>
                                                                <option value="debug" title="Debug">debug</option>
                                                                <option value="silent" title="Silent">silent</option>

                                                            </select>
                                                            <span>日志级别</span>
                                                        </td>
                                                    </tr>


                                                    <tr>
                                                        <th>Bind Address</th>
                                                        <td>
                                                            <input type="text" maxlength="15" class="input_25_table"
                                                                id="clash_bind_address" autocorrect="off"
                                                                autocapitalize="off" title="Bind Address"
                                                                placeholder="Enter Bind Address">
                                                            <span> "*"":允许任意 IP 地址的机器访问。 "0.0.0.0":允许本地局域网的访问。
                                                                "192.168.122.11":仅允许特定某个IPv4地址。
                                                                "[aaaa::a8aa:ff:fe09:57d8]": 仅允许单个 IPv6 地址。</span>
                                                        </td>
                                                    </tr>
                                                    <tr>
                                                        <th>Clash Mode</th>
                                                        <td>
                                                            <select id="clash_mode" title="工作模式">
                                                                <option value="rule" title="规则判断">rule</option>
                                                                <option value="global" title="全局代理">global</option>
                                                                <option value="direct" title="全部直连">direct</option>
                                                            </select>
                                                            <span>仅当 `allow-lan` 为 `true` 时有效。 rule: 基于规则的数据包路由。global:
                                                                所有数据包将被转发到单个节点。direct: 直接将数据包转发到互联网 </span>

                                                        </td>
                                                    </tr>
                                                    <tr>
                                                        <th>终端代理配置</th>
                                                        <td>
                                                            <div style="margin-bottom: 8px;">
                                                                <code id="proxy_command" style="background: #2d2d2d; color: #f8f8f2; padding: 8px; border-radius: 4px; display: block; word-break: break-all; font-family: monospace; font-size: 12px;">export https_proxy=http://192.168.1.1:7890 http_proxy=http://192.168.1.1:7890 all_proxy=socks5://192.168.1.1:7891</code>
                                                            </div>
                                                            <button type="button" class="button_gen" onclick="copyProxyCommand();">复制命令</button>
                                                            <button type="button" class="button_gen" onclick="openWebUI();">打开 Web UI</button>
                                                            <span>在终端中运行此命令即可使用代理</span>
                                                        </td>
                                                    </tr>

                                                </table>
                                            </div>

                                            <!-- Proxy Status Tab -->
                                            <div id="ProxyStatus" class="tabcontent">
                                                <div>&nbsp;</div>
                                                <div class="formfonttitle">
                                                    代理节点状态
                                                </div>
                                                <div style="margin:10px 0 10px 5px;" class="splitLine"></div>
                                                <div class="formfontdesc">
                                                    查看代理节点连接状态和延迟测速
                                                </div>

                                                <div style="margin: 10px 0;">
                                                    <button type="button" class="button_gen" onclick="testAllProxies();">测速全部节点</button>
                                                    <button type="button" class="button_gen" onclick="fetchProxies();">刷新列表</button>
                                                </div>

                                                <div id="proxy_list_container">
                                                    <p>点击"刷新列表"加载代理节点</p>
                                                </div>
                                            </div>


                                            <div id="ProxyConfig" class="tabcontent">

                                                <div>&nbsp;</div>
                                                <div class="formfonttitle">
                                                    Clash 代理服务设置
                                                </div>

                                                <div style="margin:10px 0 10px 5px;" class="splitLine"></div>
                                                <div class="formfontdesc">
                                                    补充说明
                                                </div>

                                                <table width="100%" border="1" align="center" cellpadding="4"
                                                    cellspacing="0" bordercolor="#6b8fa3" class="FormTable">
                                                    <thead>
                                                        <tr>
                                                            <td colspan="4">
                                                                代理服务器配置（proxy）
                                                                <button type="button"
                                                                    onclick="formatCode('clash_proxies');">格式化</button>
                                                            </td>
                                                        </tr>
                                                    </thead>
                                                    <tbody>
                                                        <tr>

                                                            <td colspan="4">
                                                                <div id="clash_proxies"
                                                                    style="height: 400px; width: 100%;"></div>
                                                            </td>
                                                        </tr>
                                                    </tbody>
                                                </table>
                                                <table width="100%" border="1" align="center" cellpadding="4"
                                                    cellspacing="0" bordercolor="#6b8fa3" class="FormTable">
                                                    <thead>
                                                        <tr>
                                                            <td colspan="4">
                                                                代理组（proxy-groups）
                                                                <button type="button"
                                                                onclick="formatCode('clash_proxy_groups');">格式化</button>
                                                            </td>

                                                        </tr>
                                                    </thead>
                                                    <tbody>
                                                        <tr>

                                                            <td colspan="4">
                                                                <div id="clash_proxy_groups"
                                                                    style="height: 400px; width: 100%;"></div>
                                                            </td>
                                                        </tr>
                                                    </tbody>
                                                </table>
                                            </div>
                                            <!-- Rule Configuration Tab -->
                                            <div id="RuleConfig" class="tabcontent">

                                                <div>&nbsp;</div>
                                                <div class="formfonttitle">
                                                    Clash 规则配置
                                                </div>
                                                <div style="margin:10px 0 10px 5px;" class="splitLine"></div>
                                                <div class="formfontdesc">
                                                    补充说明
                                                </div>

                                                <table width="100%" border="1" align="center" cellpadding="4"
                                                    cellspacing="0" bordercolor="#6b8fa3" class="FormTable">
                                                    <thead>
                                                        <tr>
                                                            <td colspan="4">
                                                                Json 格式配置（必须是合法的 Json）
                                                                <button type="button"
                                                                onclick="formatCode('clash_rules');">格式化</button>
                                                            </td>
                                                        </tr>
                                                    </thead>
                                                    <tbody>
                                                        <tr>

                                                            <td colspan="4">
                                                                <div id="clash_rules"
                                                                    style="height: 400px; width: 100%;"></div>
                                                            </td>
                                                        </tr>
                                                    </tbody>
                                                </table>
                                            </div>

                                            <!-- DNS Configuration Tab -->
                                            <div id="DNSConfig" class="tabcontent">

                                                <div>&nbsp;</div>
                                                <div class="formfonttitle">
                                                    Clash DNS 配置
                                                </div>
                                                <div style="margin:10px 0 10px 5px;" class="splitLine"></div>
                                                <div class="formfontdesc">
                                                    补充说明
                                                </div>

                                                <table width="100%" border="1" align="center" cellpadding="4"
                                                    cellspacing="0" bordercolor="#6b8fa3" class="FormTable">
                                                    <thead>
                                                        <tr>
                                                            <td colspan="4">
                                                                Json 格式配置（必须是合法的 Json）
                                                                <button type="button"
                                                                onclick="formatCode('clash_dns');">格式化</button>
                                                            </td>
                                                        </tr>
                                                    </thead>
                                                    <tbody>
                                                        <tr>

                                                            <td colspan="4">
                                                                <div id="clash_dns" style="height: 400px; width: 100%;">
                                                                </div>
                                                            </td>
                                                        </tr>
                                                    </tbody>
                                                </table>

                                            </div>

                                            <div class="apply_gen">
                                                <input name="button" type="button" class="button_gen"
                                                    onclick="applySettings();" value="应用配置&重启Clash服务" />
                                                <input name="button" type="button" class="button_gen" onclick="restartService();" value="仅重启Clash服务"/>

                                            </div>
    </form>

    <div>
        <table class="apply_gen">
            <tr class="apply_gen" valign="top">
            </tr>
        </table>
    </div>
    </td>
    </tr>
    </table>
    </td>
    <td width="10" align="center" valign="top"></td>
    </tr>
    </table>
    <div id="footer"></div>
    <script>
        function openTab(evt, tabName) {
            var i, tabcontent, tablinks;
            tabcontent = document.getElementsByClassName("tabcontent");
            for (i = 0; i < tabcontent.length; i++) {
                tabcontent[i].style.display = "none";
            }
            tablinks = document.getElementsByClassName("tablinks");
            for (i = 0; i < tablinks.length; i++) {
                tablinks[i].className = tablinks[i].className.replace(" active", "");
            }
            document.getElementById(tabName).style.display = "block";
            evt.currentTarget.className += " active";
        }

        // Ensure the first tab is displayed by default
        document.addEventListener("DOMContentLoaded", function () {
            // fetchClashConfig(); // Fetch the config on page load
            document.querySelector(".tablinks").click();
        });
    </script>
</body>

</html>
