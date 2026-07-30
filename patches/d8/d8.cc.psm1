Import-Module (Join-Path $PSScriptRoot "..\utils.psm1")

function Patch {
    param([string]$Content)

    $Content = Add-LineBelow -Content $Content `
        -Patterns @('#include .+') `
        -Insert @"
#include <cstring>
"@

    $Content = Edit-FunctionBody -Content $Content `
        -FunctionName "Local<ObjectTemplate> Shell::CreateGlobalTemplate" `
        -Converter {
        param($Body)
        $Body = Add-BeforeReturn -Body $Body `
            -Insert @"
  global_template->Set(isolate, "loadBytecode",
                       FunctionTemplate::New(isolate, LoadBytecode));
"@
        return $Body
    }

    # CHI chen disassemble.cc (loadBytecode).
    # KHONG chen metadata.cc (DumpOpcodes): no goi BYTECODE_LIST(V, V_TSA) - dang
    # 2 tham so cua V8 13.x. V8 12.4 chi nhan 1 tham so, gay:
    #   too many arguments provided to function-like macro invocation
    #   unknown type name 'BYTECODE_LIST'
    # dumpOpcodes khong can cho viec decompile .jsc, chi can loadBytecode.
    # (3 file codegen/*, common/globals.h bao "Unchanged" cung thuoc phan nay.)
    $implements = Get-Content `
        -Path (Join-Path $PSScriptRoot "disassemble.cc") `
        -Raw
    $Content = Add-LineBelow -Content $Content `
        -Patterns @('void Shell::Print\(', '^}$') `
        -Insert $implements

    return $Content
}
