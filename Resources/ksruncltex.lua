#!/usr/bin/env texlua

-- =========================================================================
-- cluttex 스크립트 경로 탐색 (cluttex_patched.lua 우선, 없으면 cluttex.lua)
-- =========================================================================
local function kpse_find_lua(name)
    local handle = io.popen("kpsewhich --format=lua " .. name, "r")
    if not handle then return nil end

    local path = handle:read("*l")
    handle:close()

    if path and path ~= "" then
        return path
    end
    return nil
end

local function get_cluttex_path()
    return kpse_find_lua("cluttex_patched.lua") or kpse_find_lua("cluttex.lua")
end

-- =========================================================================
-- 도움말 처리 로직
-- =========================================================================
local function print_custom_help()
    print("ksruncltex, a seamless running script for cluttex and minted")
    print("by Nova de Hi,\n")
    print("Usage: texlua ksruncltex.lua [--xelatex|--lualatex|--pdflatex] [--crop] [--missingchar] [cluttex options] <filename.tex>\n")
    print("Options:")
    print("  --crop             Crop the output PDF using pdfcrop after a successful run")
    print("  --missingchar      Save 'There is no ...' missing-character messages to")
    print("                     ksruncltex_missingchar.txt in the current folder")
    print("  --version          Show ksruncltex version, then cluttex's version")
    print("  --help             Show this help message")
    print("  --help --cluttex   Show this help message AND cluttex's native help message")
end

local show_help = false
local show_cluttex_help = false
local show_version = false

if #arg == 0 then
    print_custom_help()
    os.exit(1)
end

-- 입력된 터미널 인수에서 help 관련 옵션 파악 (매직 코멘트 파싱 전에 실행)
for i = 1, #arg do
    if arg[i] == "--help" or arg[i] == "-h" then
        show_help = true
    elseif arg[i] == "--cluttex" then
        show_cluttex_help = true
    elseif arg[i] == "--version" then
        show_version = true
    end
end

-- --version: ksruncltex 버전을 먼저 출력한 뒤 cluttex의 버전 출력
if show_version then
    print("ksruncltex revision 7 (2026-11-02)")

    local c_path = get_cluttex_path()
    local version_cmd
    if c_path then
        version_cmd = 'texlua "' .. c_path .. '" --version'
    else
        version_cmd = "cluttex --version"
    end
    os.execute(version_cmd)
    os.exit(0)
end

if show_help then
    print_custom_help()
    
    if show_cluttex_help then
        print("\n" .. string.rep("-", 60))
        print("[cluttex help]")
        print(string.rep("-", 60) .. "\n")
        
        local c_path = get_cluttex_path()
        local help_cmd
        if c_path then
            help_cmd = 'texlua "' .. c_path .. '" --help'
        else
            help_cmd = "cluttex --help"
        end
        -- cluttex의 도움말을 화면에 출력
        os.execute(help_cmd)
    end
    os.exit(0)
end

-- =========================================================================
-- 매직 코멘트 파싱 및 인자 처리
-- =========================================================================
local function parse_magic_args(str)
    local args = {}
    local in_quote = false
    local quote_char = ""
    local current_arg = ""
    
    for i = 1, #str do
        local c = str:sub(i, i)
        -- 따옴표 시작/종료 판별
        if (c == "'" or c == '"') then
            if in_quote and quote_char == c then
                in_quote = false
                quote_char = ""
            elseif not in_quote then
                in_quote = true
                quote_char = c
            end
            current_arg = current_arg .. c
        -- 공백을 만나고 따옴표 내부가 아니면 하나의 인수로 컷
        elseif c:match("%s") and not in_quote then
            if #current_arg > 0 then
                table.insert(args, current_arg)
                current_arg = ""
            end
        else
            current_arg = current_arg .. c
        end
    end
    -- 마지막에 남은 문자열 처리
    if #current_arg > 0 then
        table.insert(args, current_arg)
    end
    return args
end

-- \documentclass 이전에 나오는 %! KSRC 탐색
local function get_magic_args(filename)
    local fname = filename
    if not fname:match("%.tex$") then
        fname = fname .. ".tex"
    end

    local f = io.open(fname, "r")
    if not f then return {} end

    local parsed_args = {}
    for line in f:lines() do
        if line:match("\\documentclass") then
            break
        end
        local opts = line:match("^%%!%s*KSRC%s+(.+)")
        if opts then
            parsed_args = parse_magic_args(opts)
            break
        end
    end
    f:close()
    return parsed_args
end

local input_args = {}

-- 인자가 1개(파일명)만 들어온 경우, 매직 코멘트를 추출해 인수로 치환
if #arg == 1 then
    local filename = arg[1]
    local m_args = get_magic_args(filename)
    
    -- 매직 코멘트에서 찾은 인자들을 먼저 넣고
    for i = 1, #m_args do
        table.insert(input_args, m_args[i])
    end
    -- 마지막에 파일명 추가
    table.insert(input_args, filename)
else
    -- 명시적인 인자가 주어졌다면 매직 코멘트 무시하고 터미널 인자 그대로 사용
    for i = 1, #arg do
        table.insert(input_args, arg[i])
    end
end

-- 추출된 input_args를 순회하며 엔진과 내부 플래그, cluttex 인자 분리
local engine = "lualatex"
local do_crop = false
local do_missingchar = false
local cluttex_args = {}

for i = 1, #input_args do
    local a = input_args[i]
    if a == "--xelatex" or a == "--lualatex" or a == "--pdflatex" then
        engine = string.sub(a, 3) -- 앞의 '--' 제거
    elseif a == "--crop" then
        do_crop = true
    elseif a == "--missingchar" then
        do_missingchar = true
    elseif a == "--cluttex" then
        -- --help 없이 --cluttex만 들어왔을 경우 방어 처리 (무시)
    else
        table.insert(cluttex_args, a)
    end
end

-- =========================================================================
-- 실행 명령어 구성 및 Fallback 적용
-- =========================================================================
local cluttex_path = get_cluttex_path()
local cmd_tbl = {}

if cluttex_path then
    print("[Info] Found cluttex: " .. cluttex_path)
    cmd_tbl = {"texlua", cluttex_path, "-e", engine}
else
    print("[Warning] cluttex_patched.lua / cluttex.lua not found. Falling back to the cluttex command.")
    cmd_tbl = {"cluttex", "-e", engine}
end

for i = 1, #cluttex_args do
    table.insert(cmd_tbl, cluttex_args[i])
end

local function build_cmd_string(t)
    local res = {}
    for i = 1, #t do
        local v = t[i]
        if string.find(v, "%s") then
            table.insert(res, '"' .. v .. '"')
        else
            table.insert(res, v)
        end
    end
    return table.concat(res, " ")
end

local function run_command(t)
    local cmd_display = build_cmd_string(t)
    print("\n[Run] " .. cmd_display .. "\n")
    
    local cmd_exec = cmd_display .. " 2>&1"
    local handle = io.popen(cmd_exec, "r")
    
    if not handle then
        print("명령 실행 실패: " .. cmd_exec)
        return 1, ""
    end
    
    local output_tbl = {}
    -- 실시간 로그 출력 및 저장
    for line in handle:lines() do
        print(line)
        table.insert(output_tbl, line)
    end
    
    -- Lua 5.2+ (texlua 포함)에서는 close()가 반환 코드들을 제공함
    local success, reason, exit_code = handle:close()
    
    if type(exit_code) ~= "number" then
        exit_code = success and 0 or 1
    end
    
    return exit_code, table.concat(output_tbl, "\n")
end

-- =========================================================================
-- 실행 및 재시도 로직 (minted 및 보조파일 에러 대응)
-- =========================================================================
local MAX_RETRIES = 1
local attempt = 0
local final_returncode = 0
local final_output = ""

while attempt <= MAX_RETRIES do
    local returncode, output = run_command(cmd_tbl)
    final_returncode = returncode
    final_output = output  -- 마지막 시도의 출력만 missing char 추출에 사용
    
    if returncode == 0 then
        break
    end
    
    local lower_output = string.lower(output)
    
    -- minted 특이 케이스 감지 (4번째 인자 true: plain text search)
    local is_minted_error = string.find(lower_output, "package minted error", 1, true) 
                        and string.find(lower_output, "cannot locate file", 1, true)
                        and string.find(lower_output, ".listing", 1, true)
                        and string.find(lower_output, "kpsewhich failed", 1, true)
                        
    -- 임시 파일(.aux, .toc, .out 등) 꼬임 시그니처 (runaway argument 제외)
    local aux_error_signatures = {
        "scanning use of \\@writefile",
        "file ended while scanning use of"
    }
    
    local is_aux_error = false
    for i = 1, #aux_error_signatures do
        if string.find(lower_output, aux_error_signatures[i], 1, true) then
            is_aux_error = true
            break
        end
    end
                        
    if (is_minted_error or is_aux_error) and attempt < MAX_RETRIES then
        local error_type = ""
        if is_minted_error then
            error_type = "minted .listing"
        else
            error_type = "임시파일(.aux/.toc 등) 꼬임"
        end
        
        print("\n" .. string.rep("=", 60))
        print(string.format("[!] %s 오류 감지. --fresh 옵션으로 재시도합니다... (%d/%d)", error_type, attempt + 1, MAX_RETRIES))
        print(string.rep("=", 60) .. "\n")
        
        local has_fresh = false
        for i = 1, #cmd_tbl do
            if cmd_tbl[i] == "--fresh" then
                has_fresh = true
                break
            end
        end
        
        if not has_fresh then
            -- 통상적으로 파일명이 배열의 마지막에 위치하므로, 파일명 직전에 --fresh를 삽입
            table.insert(cmd_tbl, #cmd_tbl, "--fresh")
        end
        
        attempt = attempt + 1
    else
        break
    end
end

-- =========================================================================
-- 후처리 로직 (missing character 수집)
-- =========================================================================
if do_missingchar then
    local out_name = "ksruncltex_missingchar.txt"
    local seen = {}
    local found = {}

    for line in (final_output .. "\n"):gmatch("([^\r\n]*)\r?\n") do
        -- "Missing character: There is no X (U+XXXX) in font ..." 형태에서 "There is no"부터 추출
        local msg = line:match("(There is no .*)")
        if msg and not seen[msg] then
            seen[msg] = true
            table.insert(found, msg)
        end
    end

    local f = io.open(out_name, "w")
    if f then
        for i = 1, #found do
            f:write(found[i], "\n")
        end
        f:close()
        print("\n[Info] Missing character messages: " .. #found .. " unique line(s) saved to " .. out_name)
    else
        print("\n[Warning] Could not write " .. out_name)
    end
end

-- =========================================================================
-- 후처리 로직 (pdfcrop)
-- =========================================================================
if final_returncode == 0 and do_crop then
    -- cluttex_args의 맨 마지막 요소를 파일명으로 유추
    local raw_filename = cluttex_args[#cluttex_args]
    if raw_filename then
        -- 확장자 .tex 제거 후 .pdf 구성
        local base_name = raw_filename:gsub("%.tex$", "")
        local pdf_file = base_name .. ".pdf"
        
        -- 공백이 포함된 파일명에 대비해 쿼테이션 처리
        local crop_cmd = string.format('pdfcrop "%s" "%s"', pdf_file, pdf_file)
        
        print("\n" .. string.rep("-", 60))
        print("[Post-Process] Cropping PDF output...")
        print("[Run] " .. crop_cmd)
        print(string.rep("-", 60) .. "\n")
        
        local crop_success = os.execute(crop_cmd)
        if not crop_success then
            print("[Warning] pdfcrop execution failed. Check if pdfcrop is installed.")
        end
    end
end

os.exit(final_returncode)