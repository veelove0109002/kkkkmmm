# 发布测试说明

## 🧪 测试发布流程

这个文档用于测试自动化发布系统是否正常工作。

### 修复的问题

1. **前端构建路径错误** ✅
   - 修复了 `frontend-build` artifact 路径问题
   - 使用正确的 `static/` 目录而不是 `ui/dist/`
   - 使用 `npm run build:device` 进行设备特定构建

2. **工作流改进** ✅
   - 添加构建输出验证步骤
   - 优雅处理缺失的前端 artifacts
   - 添加 `continue-on-error` 和 `if-no-files-found` 处理

### 测试步骤

1. 创建测试标签：
   ```bash
   git tag -a v0.1.0-test -m "Test release v0.1.0"
   git push origin v0.1.0-test
   ```

2. 检查 GitHub Actions 是否成功运行

3. 验证发布是否包含所有预期文件：
   - `jetkvm-arm-linux`
   - `jetkvm-x86_64-linux`
   - `jetkvm-arm-linux.sha256`
   - `jetkvm-x86_64-linux.sha256`

### 预期结果

- ✅ 前端构建成功
- ✅ ARM 和 X86_64 二进制文件构建成功
- ✅ SHA256 校验文件生成
- ✅ GitHub Release 自动创建
- ✅ 所有文件正确上传

如果测试成功，可以删除此测试发布和标签。