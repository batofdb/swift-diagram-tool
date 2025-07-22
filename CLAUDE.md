## 🚨 CRITICAL OPERATING RULES (ALWAYS APPLY)

### File Path Management
**CRITICAL**: Always use relative directory paths when working with project files. Do not execute commands that would create duplicate directories or nested structures.

**IMPORTANT**: All file operations (Read, Write, Edit, MultiEdit, LS, Glob, Grep, etc.) MUST use relative paths from the project root `/Users/francisb/Documents/Documents - Francis's MacBook Pro/Develop/ShareFit/`. Never use absolute paths unless absolutely necessary.

Examples:
- ✅ Good: `Sources/Views/Timer/TimerView.swift`
- ❌ Bad: `Sources/Views/Sources/Views/Timer/TimerView.swift`
- ❌ Bad: `/Users/francisb/Documents/Documents - Francis's MacBook Pro/Develop/ShareFit/Sources/Views/Timer/TimerView.swift`
- ✅ Good: `Models/TimerMode.swift`
- ❌ Bad: `Models/Models/TimerMode.swift`

**File Tool Usage Rules:**
- Read tool: `Read("Sources/Views/ExampleView.swift")` ✅
- Write tool: `Write("Sources/Views/NewView.swift", content)` ✅
- Edit tool: `Edit("Models/DataModel.swift", old, new)` ✅
- LS tool: `LS("Sources/Views")` ✅
- Glob tool: `Glob("**/*.swift")` ✅

### File Creation Guidelines
**CRITICAL**: When creating new files, choose the appropriate method based on file type:

✅ **PREFERRED METHOD** - Use Write tool for Swift/code files:
```
Write("path/to/file.swift", content)
```

✅ **ALTERNATIVE METHOD** - Use bash heredoc for shell scripts/config files:
```bash
cat > path/to/file.sh << 'EOF'
file content here
EOF
```

**IMPORTANT FILE CREATION RULES**:
- **Swift files**: Always use Write tool to avoid escape character issues
- **Shell scripts/configs**: Use bash heredoc method
- **NEVER include EOF markers in file content** - they are heredoc delimiters only
- **Verify file creation** with `ls -la` in the target directory

**Why Write tool is preferred for Swift files**:
- Prevents escape character corruption (`\!` instead of `!`)
- Avoids EOF marker pollution in file content
- Maintains proper Swift syntax highlighting and formatting
- Ensures clean, readable code without bash artifacts

**Verification**: Always verify file creation with `ls -la` in the target directory. If the file doesn't appear, it was created in the wrong location.