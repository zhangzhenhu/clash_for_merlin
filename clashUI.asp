<!DOCTYPE html
    PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">

<head>
    <!-- <script src="https://cdn.jsdelivr.net/npm/js-yaml@4.1.0/dist/js-yaml.min.js"></script> -->
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
    <script src="https://cdnjs.cloudflare.com/ajax/libs/ace/1.36.5/mode-json5.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/ace/1.36.5/worker-json.js"></script> 
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
        var custom_settings = <% get_custom_settings(); %>;
        var clash_settings = {};
        var clash_service_status = "stopped";
        const fields = [
            { id: 'clash_external_controller', default: '', key: 'clash_external_controller', source: "custom", },
            { id: 'clash_secret', default: '', key: 'clash_secret', source: "custom", },
            { id: 'clash_socks_port', default: '0', key: 'socks-port', source: "clash", },
            { id: 'clash_allow_lan', default: '', key: 'allow-lan', source: "clash", },
            { id: 'clash_mode', default: '', key: 'mode', source: "clash", },

            { id: 'clash_redir_port', default: '0', key: 'redir-port', source: "clash", },
            { id: 'clash_tproxy_port', default: '0', key: 'tproxy-port', source: "clash", },
            { id: 'clash_mixed_port', default: '0', key: 'mixed-port', source: "clash", },
            { id: 'clash_bind_address', default: '', key: 'bind-address', source: "clash", },
            { id: 'clash_port', default: '0', key: 'port', source: "clash", },
            { id: 'clash_ipv6', default: 'false', key: 'ipv6', source: "clash", },
            { id: 'clash_log-level', default: 'info', key: 'log-level', source: "clash", },
            { id: 'clash_proxy_groups', default: '', key: 'proxy-groups', source: "clash", }
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
                })
                .catch(error => {
                    clash_service_status = "stopped";
                    // console.error('Error fetching Clash config:', error);
                    document.getElementById('clash_service_status').value = 'stopped';
                    alert('Clash 服务检测异常，可能没启动: ' + error.message);
                });
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
            fetch(`http://${window.location.hostname}:${port}/yml/json`, {
                method: 'PUT',
                headers: new Headers({
                    'Content-Type': 'application/json',

                    'Authorization': `Bearer ${token}`

                }),
                body: JSON.stringify(configData)
            })
                .then(response => response.text())
                .then(data => {
                    console.log('Config saved:', data);
                    // 提交成功后，重新加载配置
                    showLoading();
                    document.form.submit();
                })
                .catch(error => {
                    console.error('Error saving config:', error);
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

            let editor = ace.edit(editor_id);

            editor.setValue(JSON5.stringify(data, null, 2), -1);
        }
        function get_json_data(editor_id) {
            let editor = ace.edit(editor_id);
            try {
                let value = editor.getValue().trim();
                if (!value) {
                    return {};
                }
                let data = JSON5.parse(value);
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
                // console.log(editor.getValue());
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
            initial_json_editor("clash_proxies");
            initial_json_editor("clash_proxy_groups");
            initial_json_editor("clash_rules");
            initial_json_editor("clash_dns");
            document.querySelector(".tablinks").click();
            fetchClashConfig(); // Fetch the config on page load
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
                field.source[field.key] = value;
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
                                                                <option value="running">Running</option>
                                                                <option value="stopped">Stopped</option>
                                                            </select>
                                                            <span>服务的状态</span>
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

                                                </table>
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