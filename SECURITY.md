# Security / 安全政策

Never attach live credentials, BMC access details, tokens or raw inventory to a public
issue. Use GitHub's private vulnerability reporting if enabled. Otherwise open a minimal
issue asking for a private contact channel without exploit details or private data.
No response-time guarantee is made by this personally maintained project.

Do not use this initial version as a security boundary or assume hardware interoperability.
TLS verification is mandatory; a custom CA must come from an independently trusted source.
Session creation/deletion modifies remote state. Callers must have explicit authorization.
Session tokens remain in process memory until released; memory zeroization is not promised.
Applications must manage cleanup after cancellation and avoid logging raw resource JSON.

请勿在公开 issue 中上传真实凭据、BMC 连接信息、令牌或原始清单。若仓库启用了 GitHub
私密漏洞报告，请使用该渠道；否则只提交请求私密联系方式的最小 issue，不披露利用细节
或私人数据。个人维护项目不保证响应时限。

不要将初版库当作安全边界，也不要假定已与硬件互通。TLS 验证不可关闭；自定义 CA 必须
来自独立可信来源。会话创建与删除会修改远端状态，调用方必须事先获得授权。
令牌保存在进程内存中，库不承诺安全擦除。调用方应负责取消后的清理并避免记录原始 JSON。
