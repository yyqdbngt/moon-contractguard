# Moon ContractGuard architecture

Status: development plan; functionality must be checked against release documentation.

目标：回答“接口升级是否破坏调用方”和“实际响应是否符合约定”，产出可在 CI 使用的测试报告。

核心模块：OpenAPI 3.0 JSON 适配；引用图解析；参数与 schema 模型；兼容性差异分类；样例和边界请求生成；请求/响应校验；本地 HTTP 执行适配；结果报告。复用 HTTP/schema 库时记录版本和来源，核心契约与兼容性语义自行实现。

三个场景：订单接口升级导致字段、枚举与状态码变化；前后端联调检查分页与错误响应；第三方服务适配对录制响应与本地桩做验证。每场景都包含已知兼容变更和已知破坏变更，测试真实运行的本地服务。

验收：预标注的兼容性语料分类一致；三场景捕获预先植入的破坏变更；对数百 operations 的规格记录处理耗时。失败验证覆盖引用循环、不存在引用、不支持关键字、响应类型错与参数缺失。未知语义明确拒绝或标记未检查，不能静默作为通过。十月不承诺完整 OpenAPI/YAML/所有 JSON Schema 草案。
