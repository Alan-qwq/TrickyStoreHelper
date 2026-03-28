#!/system/bin/sh
TS_DIR="/data/adb/tricky_store"
TARGET_KEYBOX="$TS_DIR/keybox.xml"
TMP_DIR="/data/local/tmp/keybox_update"
TMP_RAW="$TMP_DIR/raw.tmp"
TMP_KEYBOX="$TMP_DIR/keybox_tmp.xml"

YURIKEY_URL="https://raw.githubusercontent.com/Yurii0307/yurikey/main/key"
TRICKYADDON_URL="https://raw.githubusercontent.com/KOWX712/Tricky-Addon-Update-Target-List/keybox/.extra"
INTEGRITYBOX_URL="https://raw.githubusercontent.com/MeowDump/MeowDump/refs/heads/main/NullVoid/OptimusPrime"
UPDATE_JSON_URL="https://raw.githubusercontent.com/Alan-qwq/TrickyStoreHelper/main/update.json"
SECURITY_BULLETIN_URL="https://source.android.com/docs/security/bulletin/pixel"

CURRENT_VERSION="1.1.0"
SCRIPT_PATH=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

TOYBOX_COMMANDS=""
BUSYBOX_COMMANDS=""

init_command_cache() {
  local _init_toybox_out=""
  local _init_busybox_out=""
  if command -v toybox >/dev/null 2>&1; then
    _init_toybox_out=$(toybox --list 2>/dev/null | tr '\n' ' ')
    TOYBOX_COMMANDS=" $_init_toybox_out "
  fi
  if command -v busybox >/dev/null 2>&1; then
    _init_busybox_out=$(busybox --list 2>/dev/null | tr '\n' ' ')
    BUSYBOX_COMMANDS=" $_init_busybox_out "
  fi
  unset _init_toybox_out _init_busybox_out
}

run() {
  local _cmd="$1"
  shift
  if [ -n "$TOYBOX_COMMANDS" ]; then
    case "$TOYBOX_COMMANDS" in
      *" $_cmd "*)
        toybox "$_cmd" "$@"
        return $?
        ;;
    esac
  fi
  if [ -n "$BUSYBOX_COMMANDS" ]; then
    case "$BUSYBOX_COMMANDS" in
      *" $_cmd "*)
        busybox "$_cmd" "$@"
        return $?
        ;;
    esac
  fi
  if command -v "$_cmd" >/dev/null 2>&1; then
    "$_cmd" "$@"
    return $?
  fi
  printf "${RED}[ERROR]${NC} 命令 '%s' 不可用（toybox/busybox/系统均未找到）\n" "$_cmd" >&2
  return 127
}

log_info() {
  printf "${GREEN}[INFO]${NC} %s\n" "$1"
}

log_warn() {
  printf "${YELLOW}[WARN]${NC} %s\n" "$1" >&2
}

log_error() {
  printf "${RED}[ERROR]${NC} %s\n" "$1" >&2
}

clear_screen() {
  printf "\033c"
}

version_ge() {
  local _ver1="$1"
  local _ver2="$2"
  local _i=1
  while [ "$_i" -le 5 ]; do
    local _n1=$(printf "%s" "$_ver1" | run cut -d. -f"$_i" 2>/dev/null)
    local _n2=$(printf "%s" "$_ver2" | run cut -d. -f"$_i" 2>/dev/null)
    _n1=${_n1:-0}
    _n2=${_n2:-0}
    _n1=$(printf "%s" "$_n1" | run sed 's/^0*//')
    _n1=${_n1:-0}
    _n2=$(printf "%s" "$_n2" | run sed 's/^0*//')
    _n2=${_n2:-0}
    if [ "$_n1" -gt "$_n2" ]; then return 0; fi
    if [ "$_n1" -lt "$_n2" ]; then return 1; fi
    _i=$((_i + 1))
  done
  return 0
}

show_decode_progress() {
  local _current="$1"
  local _total="$2"
  local _bar_len=20
  local _filled=$((_current * _bar_len / _total))
  local _empty=$((_bar_len - _filled))
  
  local _bar=""
  local _j=0
  while [ "$_j" -lt "$_filled" ]; do
    _bar="$_bar#"
    _j=$((_j + 1))
  done
  
  local _empty_bar=""
  _j=0
  while [ "$_j" -lt "$_empty" ]; do
    _empty_bar="$_empty_bar-"
    _j=$((_j + 1))
  done
  
  printf "${BLUE}[DECODE]${NC} [%s%s] %d/%d 层 \r" "$_bar" "$_empty_bar" "$_current" "$_total"
  if [ "$_current" -eq "$_total" ]; then printf "\n"; fi
}

check_root() {
  local _check_root_uid=$(run id -u)
  if [ "$_check_root_uid" -ne 0 ]; then
    log_error "需要 Root 权限!"
    exit 1
  fi
  unset _check_root_uid
}

check_tools() {
  local _check_missing=""
  local _check_has_curl=0
  local _check_has_wget=0
  local _required_tools="id xxd base64 readlink grep sed awk sort wc head tr cat rm mkdir cp mv chmod touch ls pm dirname basename pwd cut date getprop sha256sum"

  case "$TOYBOX_COMMANDS" in *" wget "*) _check_has_wget=1 ;; esac
  case "$BUSYBOX_COMMANDS" in *" wget "*) _check_has_wget=1 ;; esac
  case "$TOYBOX_COMMANDS" in *" curl "*) _check_has_curl=1 ;; esac
  case "$BUSYBOX_COMMANDS" in *" curl "*) _check_has_curl=1 ;; esac

  if [ $_check_has_wget -eq 0 ] && [ $_check_has_curl -eq 0 ]; then
    if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
      _check_missing="$_check_missing wget/curl"
    fi
  fi

  for _tool in $_required_tools; do
    local _has_tool=0
    case "$TOYBOX_COMMANDS" in *" $_tool "*) _has_tool=1 ;; esac
    case "$BUSYBOX_COMMANDS" in *" $_tool "*) _has_tool=1 ;; esac
    if [ $_has_tool -eq 1 ] || command -v "$_tool" >/dev/null 2>&1; then
      continue
    fi
    _check_missing="$_check_missing $_tool"
  done

  if [ -n "$_check_missing" ]; then
    log_error "缺少必要工具: $_check_missing"
    exit 1
  fi

  unset _check_missing _check_has_curl _check_has_wget _required_tools _tool _has_tool
}

init_env() {
  run rm -rf "$TMP_DIR"
  run mkdir -p "$TMP_DIR"
  run mkdir -p "$TS_DIR"
}

get_script_path() {
  local _has_readlink=0
  local _script_dir=""
  local _script_name=""
  local _abs_dir=""
  SCRIPT_PATH=""

  case "$TOYBOX_COMMANDS" in *" readlink "*) _has_readlink=1 ;; esac
  case "$BUSYBOX_COMMANDS" in *" readlink "*) _has_readlink=1 ;; esac

  if [ $_has_readlink -eq 1 ] || command -v readlink >/dev/null 2>&1; then
    SCRIPT_PATH=$(run readlink -f "$0" 2>/dev/null)
  fi

  if [ -z "$SCRIPT_PATH" ] || [ ! -f "$SCRIPT_PATH" ]; then
    _script_dir=$(run dirname "$0" 2>/dev/null)
    _script_name=$(run basename "$0" 2>/dev/null)
    if [ -n "$_script_dir" ] && [ -n "$_script_name" ]; then
      _abs_dir=$(cd "$_script_dir" && run pwd 2>/dev/null)
      if [ -n "$_abs_dir" ]; then
        SCRIPT_PATH="$_abs_dir/$_script_name"
      fi
    fi
  fi

  if [ -z "$SCRIPT_PATH" ] || [ ! -f "$SCRIPT_PATH" ]; then
    SCRIPT_PATH="$0"
  fi

  if [ ! -w "$SCRIPT_PATH" ]; then
    log_error "脚本文件无写入权限，无法执行更新操作"
    unset _has_readlink _script_dir _script_name _abs_dir
    return 1
  fi

  unset _has_readlink _script_dir _script_name _abs_dir
  return 0
}

download_file() {
  local _url="$1"
  local _dest="$2"
  local _success=1
  local _has_wget=0

  run rm -f "$_dest"

  case "$TOYBOX_COMMANDS" in *" wget "*) _has_wget=1 ;; esac
  case "$BUSYBOX_COMMANDS" in *" wget "*) _has_wget=1 ;; esac

  if [ $_has_wget -eq 1 ] || command -v wget >/dev/null 2>&1; then
    log_info "正在使用 wget 下载…"
    if run wget -T 10 -t 2 --no-check-certificate -q -O "$_dest" "$_url"; then
      _success=0
    fi
  fi

  if [ $_success -ne 0 ]; then
    log_warn "wget 下载失败，尝试使用 curl 下载…"
    if run curl -fL -sS --connect-timeout 10 --retry 2 "$_url" -o "$_dest"; then
      _success=0
    fi
  fi

  if [ $_success -eq 0 ] && [ -s "$_dest" ]; then
    log_info "下载完成"
    return 0
  else
    log_error "下载失败或文件为空: $_url"
    run rm -f "$_dest"
    return 1
  fi
}

check_update() {
  local _update_tmp="$TMP_DIR/update.json"
  local _remote_version=""
  local _update_url=""
  local _update_log=""
  local _need_update=""
  local _remote_sha256=""
  local _is_need_update=0
  local _confirm=""
  local _new_script="$TMP_DIR/new_tricky_helper.sh"
  local _file_hash=""

  clear_screen
  run sleep 1
  log_info "正在检查更新..."

  if ! get_script_path; then
    unset _update_tmp _remote_version _update_url _update_log _need_update _remote_sha256 _is_need_update _confirm _new_script _file_hash
    return 1
  fi

  log_info "正在拉取远程更新配置..."
  if ! download_file "$UPDATE_JSON_URL" "$_update_tmp"; then
    log_error "更新配置文件获取失败，请检查网络连接后重试"
    unset _update_tmp _remote_version _update_url _update_log _need_update _remote_sha256 _is_need_update _confirm _new_script _file_hash
    return 1
  fi

  log_info "正在解析更新信息..."
  _remote_version=$(run grep -o '"version": *"[^"]*"' "$_update_tmp" | run sed 's/"version": *"//;s/"//g')
  _update_url=$(run grep -o '"update_url": *"[^"]*"' "$_update_tmp" | run sed 's/"update_url": *"//;s/"//g')
  _update_log=$(run grep -o '"update_log": *"[^"]*"' "$_update_tmp" | run sed 's/"update_log": *"//;s/"//g')
  _need_update=$(run grep -o '"need_update": *"[^"]*"' "$_update_tmp" | run sed 's/"need_update": *"//;s/"//g')
  _remote_sha256=$(run grep -o '"sha256sum": *"[^"]*"' "$_update_tmp" | run sed 's/"sha256sum": *"//;s/"//g')

  if [ -z "$_remote_version" ] || [ -z "$_update_url" ] || [ -z "$_remote_sha256" ]; then
    log_error "更新配置解析失败，缺少版本号、下载地址或哈希校验字段"
    unset _update_tmp _remote_version _update_url _update_log _need_update _remote_sha256 _is_need_update _confirm _new_script _file_hash
    return 1
  fi

  printf "\n${CYAN}当前版本:${NC} v%s\n" "$CURRENT_VERSION"
  printf "${CYAN}最新版本:${NC} v%s\n\n" "$_remote_version"

  if ! version_ge "$CURRENT_VERSION" "$_remote_version"; then
    if [ "$_need_update" = "true" ]; then
      _is_need_update=1
    else
      log_warn "发现新版本，但远程配置关闭了强制更新，跳过更新"
    fi
  fi

  if [ "$_is_need_update" -eq 0 ]; then
    log_info "✅ 当前已是最新版本，无需更新"
    unset _update_tmp _remote_version _update_url _update_log _need_update _remote_sha256 _is_need_update _confirm _new_script _file_hash
    return 0
  fi

  printf "${YELLOW}===== 发现可用新版本 =====${NC}\n"
  printf "${CYAN}新版本号:${NC} v%s\n" "$_remote_version"
  printf "${CYAN}更新内容:${NC} %s\n" "$_update_log"
  printf "${YELLOW}==========================${NC}\n\n"

  printf "%s" "是否立即更新到最新版本？[y/n] "
  read _confirm
  case "$_confirm" in
    [Yy]*)
      log_info "正在下载新版本安装包..."
      if ! download_file "$_update_url" "$_new_script"; then
        log_error "新版本脚本下载失败，更新已终止"
        unset _update_tmp _remote_version _update_url _update_log _need_update _remote_sha256 _is_need_update _confirm _new_script _file_hash
        return 1
      fi

      if [ ! -s "$_new_script" ]; then
        log_error "下载的新版本文件为空，更新已终止"
        run rm -f "$_new_script"
        unset _update_tmp _remote_version _update_url _update_log _need_update _remote_sha256 _is_need_update _confirm _new_script _file_hash
        return 1
      fi

      log_info "正在校验新版本文件哈希..."
      _file_hash=$(run sha256sum "$_new_script" | run awk '{print $1}')
      
      if [ -z "$_file_hash" ]; then
        log_error "文件哈希计算失败，更新已终止"
        run rm -f "$_new_script"
        unset _update_tmp _remote_version _update_url _update_log _need_update _remote_sha256 _is_need_update _confirm _new_script _file_hash
        return 1
      fi

      if [ "$_file_hash" != "$_remote_sha256" ]; then
        log_error "❌ 文件哈希校验不通过！"
        log_error "预期哈希: $_remote_sha256"
        log_error "实际哈希: $_file_hash"
        log_error "文件可能被篡改、下载不完整或配置错误，更新已自动终止"
        run rm -f "$_new_script"
        unset _update_tmp _remote_version _update_url _update_log _need_update _remote_sha256 _is_need_update _confirm _new_script _file_hash
        return 1
      fi

      log_info "✅ 哈希校验通过，文件安全完整"
      log_info "正在替换脚本文件..."
      if ! run cp -f "$_new_script" "$SCRIPT_PATH"; then
        log_error "脚本文件替换失败，请检查目录权限"
        run rm -f "$_new_script"
        unset _update_tmp _remote_version _update_url _update_log _need_update _remote_sha256 _is_need_update _confirm _new_script _file_hash
        return 1
      fi

      run chmod 755 "$SCRIPT_PATH"
      if [ $? -ne 0 ]; then
        log_warn "脚本执行权限设置失败"
      fi

      run rm -f "$_new_script"
      log_info "✅ 脚本更新成功！"
      echo "脚本更新完毕，请重新执行脚本"
      run sleep 1
      unset _update_tmp _remote_version _update_url _update_log _need_update _remote_sha256 _is_need_update _confirm _new_script _file_hash
      exit 0
      ;;
    *)
      log_warn "已取消更新，返回主菜单"
      run rm -f "$_new_script"
      unset _update_tmp _remote_version _update_url _update_log _need_update _remote_sha256 _is_need_update _confirm _new_script _file_hash
      return 0
      ;;
  esac
}

fetch_yurikey() {
  log_info "[1/2] 正在下载 Yurikey 源..."
  if ! download_file "$YURIKEY_URL" "$TMP_RAW"; then
    return 1
  fi
  log_info "[2/2] 正在解码..."
  # 预处理去除换行/空白，提升解码兼容性
  if ! run tr -d '\n\r ' < "$TMP_RAW" | run base64 -d > "$TMP_KEYBOX" 2>/dev/null; then
    log_error "解码失败"
    return 1
  fi
  if [ ! -s "$TMP_KEYBOX" ]; then
    log_error "解码后文件为空"
    return 1
  fi
  return 0
}

fetch_tricky_addon() {
  log_info "[1/2] 正在下载 Tricky Addon 源..."
  if ! download_file "$TRICKYADDON_URL" "$TMP_RAW"; then
    return 1
  fi
  log_info "[2/2] 正在解码..."
  # 预处理去除换行/空白，提升解码兼容性
  if ! run tr -d '\n\r ' < "$TMP_RAW" | run xxd -r -p | run base64 -d > "$TMP_KEYBOX" 2>/dev/null; then
    log_error "解码失败"
    return 1
  fi
  if [ ! -s "$TMP_KEYBOX" ]; then
    log_error "解码后文件为空"
    return 1
  fi
  return 0
}

fetch_integritybox() {
  local _process_file="$TMP_DIR/process.tmp"
  local _next_file="$TMP_DIR/process.next"
  local _i=1
  local _clean_file="$TMP_DIR/clean.tmp"

  log_info "[1/3] 正在下载 IntegrityBox 源..."
  if ! download_file "$INTEGRITYBOX_URL" "$TMP_RAW"; then
    return 1
  fi
  # 预处理去除所有换行/空白，避免base64解码失败
  run tr -d '\n\r ' < "$TMP_RAW" > "$_process_file"

  log_info "[2/3] 正在解码 (10层Base64)..."
  while [ $_i -le 10 ]; do
    if [ ! -s "$_process_file" ]; then
      log_error "解码中断：第 $_i 层数据为空"
      return 1
    fi
    show_decode_progress $_i 10
    # 每层解码前都预处理，确保无非法字符
    run tr -d '\n\r ' < "$_process_file" > "$_clean_file"
    if ! run base64 -d "$_clean_file" > "$_next_file" 2>/dev/null; then
      log_error "第 $_i 层 Base64 解码失败"
      return 1
    fi
    run mv -f "$_next_file" "$_process_file"
    _i=$((_i + 1))
  done

  log_info "[3/3] 正在格式转换..."
  if ! run cat "$_process_file" | run xxd -r -p | run tr 'A-Za-z' 'N-ZA-Mn-za-m' > "$TMP_KEYBOX"; then
    log_error "最终格式转换失败"
    return 1
  fi
  if [ ! -s "$TMP_KEYBOX" ]; then
    log_error "最终文件为空"
    return 1
  fi
  return 0
}

validate_keybox() {
  local _file="$1"
  if [ ! -s "$_file" ]; then
    log_error "生成的 Keybox 文件无效 (空文件)"
    return 1
  fi
  if ! run grep -q "<?xml" "$_file" || \
     ! run grep -q "<AndroidAttestation>" "$_file" || \
     ! run grep -q "BEGIN CERTIFICATE" "$_file"; then
    log_error "Keybox 内容校验失败"
    return 1
  fi
  local _size=$(run wc -c < "$_file" 2>/dev/null | run tr -d ' ')
  log_info "校验通过，文件大小: $_size 字节"
  return 0
}

install_keybox() {
  if run mv -f "$TMP_KEYBOX" "$TARGET_KEYBOX"; then
    run chmod 644 "$TARGET_KEYBOX"
    log_info "✅ Keybox 更新成功！"
    return 0
  else
    log_error "写入文件失败"
    return 1
  fi
}

show_current() {
  if [ -f "$TARGET_KEYBOX" ]; then
    printf "${CYAN}当前文件:${NC} %s\n" "$TARGET_KEYBOX"
    run ls -lh "$TARGET_KEYBOX"
    printf "${CYAN}头部预览:${NC}\n"
    run head -n 5 "$TARGET_KEYBOX"
    echo "..."
  else
    printf "${YELLOW}未找到 Keybox 文件${NC}\n"
  fi
}

keybox_manage_menu() {
  while true; do
    clear_screen
    printf "${PURPLE}选择keybox源${NC}\n"
    printf "${GREEN}[1]${NC} Yurikey 源\n"
    printf "${GREEN}[2]${NC} Tricky Addon 源\n"
    printf "${GREEN}[3]${NC} IntegrityBox 源\n"
    printf "${CYAN}[4]${NC} 查看当前Keybox状态\n"
    printf "${RED}[0]${NC} 返回主菜单\n"
    printf "%s" "请选择: "
    read _sub_choice

    case "$_sub_choice" in
      1) fetch_yurikey && validate_keybox "$TMP_KEYBOX" && install_keybox ;;
      2) fetch_tricky_addon && validate_keybox "$TMP_KEYBOX" && install_keybox ;;
      3) fetch_integritybox && validate_keybox "$TMP_KEYBOX" && install_keybox ;;
      4) show_current ;;
      0) return 0 ;;
      *) echo "无效选项" ;;
    esac

    printf "\n%s" "按回车继续..."
    read _dummy
  done
}

update_target_txt() {
  local _target_file="$TS_DIR/target.txt"
  local _suffix=""
  local _mode_choice=""
  local _pkg_third=""
  local _pkg_system=""
  local _packages=""
  local _include_system_app="com.google.android.gms com.google.android.gsf com.android.vending com.oplus.deepthinker com.heytap.speechassist com.coloros.sceneservice"

  clear_screen

  while true; do
    clear_screen
    printf "${CYAN}选择密钥注入模式${NC}\n"
    printf "${GREEN}[1]${NC} 正常模式\n"
    printf "${YELLOW}[2]${NC} 生成证书链（!）\n"
    printf "${YELLOW}[3]${NC} 修改证书链（?）\n"
    printf "${RED}[0]${NC} 退出\n"
    printf "%s" "请选择模式: "
    read _mode_choice
    case "$_mode_choice" in
      1) _suffix=""; break ;;
      2) _suffix="!"; break ;;
      3) _suffix="?"; break ;;
      0) return 0 ;;
      *)
        printf "${RED}无效选项，请重新选择${NC}\n"
        run sleep 1
        ;;
    esac
  done

  clear_screen
  log_info "正在获取应用列表..."

  _pkg_third=$(run pm list packages -3 2>/dev/null | run awk -F: '{print $2}' 2>/dev/null)

  for _app in $_include_system_app; do
    if run pm list packages -s 2>/dev/null | run grep -xq "package:$_app"; then
      _pkg_system=$(printf "%s\n%s" "$_pkg_system" "$_app")
      log_info "已添加系统应用：$_app"
    else
      log_warn "系统中未找到应用：$_app，已跳过"
    fi
  done

  _packages=$(printf "%s%s" "$_pkg_third" "$_pkg_system" | run sort -u | run grep -v '^$')

  if [ -z "$_packages" ]; then
    log_error "未获取到任何应用包名"
    run sleep 2
    return 1
  fi

  local _app_count=$(echo "$_packages" | run wc -l)
  log_info "共获取到 $_app_count 个应用"
  log_info "正在写入 $_target_file ..."

  run mkdir -p "$TS_DIR"

  echo "$_packages" | while read -r _pkg; do
    if [ -n "$_pkg" ]; then
      echo "${_pkg}${_suffix}"
    fi
  done > "$_target_file"

  if [ $? -eq 0 ] && [ -s "$_target_file" ]; then
    local _final_count=$(run wc -l < "$_target_file")
    log_info "✅ target.txt 更新成功！共写入 $_final_count 条包名"
    printf "${CYAN}文件路径:${NC} %s\n" "$_target_file"
    printf "${CYAN}内容预览:${NC}\n"
    run head -n 10 "$_target_file"
    if [ $_final_count -gt 10 ]; then
      echo "... 共 $_final_count 个应用"
    fi
  else
    log_error "写入文件失败，请检查目录权限"
    return 1
  fi
  return 0
}

get_latest_security_patch() {
  local _security_patch=""
  _security_patch=$(run wget -T 15 --no-check-certificate -qO- "$SECURITY_BULLETIN_URL" 2>/dev/null | \
                   run sed -n 's/.*<td>\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)<\/td>.*/\1/p' | \
                   run head -n 1)

  if [ -z "$_security_patch" ]; then
    _security_patch=$(run curl --connect-timeout 15 -Ls "$SECURITY_BULLETIN_URL" 2>/dev/null | \
                     run sed -n 's/.*<td>\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)<\/td>.*/\1/p' | \
                     run head -n 1)
  fi

  if [ -n "$_security_patch" ]; then
    echo "$_security_patch"
    return 0
  else
    log_warn "获取官方安全补丁失败，使用系统当前补丁"
    run getprop ro.build.version.security_patch
    return 1
  fi
}

set_trickystore_security() {
  local _TARGET_PATCH="$1"
  if [ -z "$_TARGET_PATCH" ]; then
    _TARGET_PATCH=$(run getprop ro.build.version.security_patch)
    log_warn "未指定补丁日期，使用系统当前补丁：$_TARGET_PATCH"
  fi

  local _FORMATTED=$(echo "$_TARGET_PATCH" | run sed 's/-//g')
  local _TODAY=$(run date +%Y%m%d)
  local _PATCH_1Y_LATER=$((_FORMATTED + 10000))

  if [ -n "$_FORMATTED" ] && [ "$_TODAY" -lt "$_PATCH_1Y_LATER" ]; then
    log_info "安全补丁有效：$_TARGET_PATCH，开始写入TrickyStore"
  else
    log_error "安全补丁已过期或无效，取消设置"
    return 1
  fi

  local _TS_PROP="/data/adb/modules/tricky_store/module.prop"
  local _TS_VERSION=0
  if [ -f "$_TS_PROP" ]; then
    _TS_VERSION=$(run grep "versionCode=" "$_TS_PROP" | run cut -d'=' -f2)
    case "$_TS_VERSION" in
      *[!0-9]*) _TS_VERSION=0 ;;
    esac
  fi

  if [ -f "$_TS_PROP" ] && run grep -q "James" "$_TS_PROP" && ! run grep -q "beakthoven" "$_TS_PROP"; then
    local _SEC_FILE="$TS_DIR/devconfig.toml"
    if [ -f "$_SEC_FILE" ]; then
      if run grep -q "^securityPatch" "$_SEC_FILE"; then
        run sed "s/^securityPatch .*/securityPatch = \"$_TARGET_PATCH\"/" "$_SEC_FILE" > "$_SEC_FILE.tmp" && run mv -f "$_SEC_FILE.tmp" "$_SEC_FILE"
      else
        if ! run grep -q "^\\[deviceProps\\]" "$_SEC_FILE"; then
          echo "securityPatch = \"$_TARGET_PATCH\"" >> "$_SEC_FILE"
        else
          run sed "s/^\[deviceProps\]/securityPatch = \"$_TARGET_PATCH\"\n&/" "$_SEC_FILE" > "$_SEC_FILE.tmp" && run mv -f "$_SEC_FILE.tmp" "$_SEC_FILE"
        fi
      fi
      log_info "已写入 James 版 TrickyStore: $_SEC_FILE"
    else
      log_error "未找到 James 版配置文件 $_SEC_FILE"
      return 1
    fi
  elif [ "$_TS_VERSION" -ge 158 ] || run grep -q "beakthoven" "$_TS_PROP" 2>/dev/null; then
    local _SEC_FILE="$TS_DIR/security_patch.txt"
    printf "system=prop\nboot=%s\nvendor=%s\n" "$_TARGET_PATCH" "$_TARGET_PATCH" > "$_SEC_FILE"
    run chmod 644 "$_SEC_FILE"
    log_info "已写入新版 TrickyStore: $_SEC_FILE"
  else
    run resetprop ro.build.version.security_patch "$_TARGET_PATCH"
    run resetprop ro.vendor.build.security_patch "$_TARGET_PATCH"
    log_info "旧版TrickyStore，已修改系统安全补丁属性"
  fi
  return 0
}

config_security_patch() {
  clear_screen
  log_info "获取安卓官方最新安全补丁"
  local _LATEST_PATCH=$(get_latest_security_patch)
  if [ -z "$_LATEST_PATCH" ]; then
    log_error "无法获取有效安全补丁日期"
    printf "\n%s" "按回车继续..."
    read _dummy
    return 1
  fi
  log_info "最新安全补丁：$_LATEST_PATCH"

  log_info "配置 TrickyStore 安全补丁"
  if set_trickystore_security "$_LATEST_PATCH"; then
    log_info "✅ 安全补丁配置完成！"
  else
    log_error "❌ 安全补丁配置失败"
  fi

  printf "\n%s" "按回车继续..."
  read _dummy
}

cleanup() {
  run rm -rf "$TMP_DIR"
  log_info "临时文件已清理"
}

main() {
  local _main_choice=""

  init_command_cache
  check_root
  check_tools
  init_env

  trap cleanup EXIT INT TERM

  while true; do
    clear_screen
    printf "${CYAN}TrickyStore辅助脚本 v%s\nby 酷安 ALAN_233${NC}\n" "$CURRENT_VERSION"
    printf "${GREEN}[1]${NC} 一键更新有效密钥\n"
    printf "${GREEN}[2]${NC} 一键配置target.txt包名\n"
    printf "${GREEN}[3]${NC} 设置最新安全补丁\n"
    printf "${PURPLE}[4]${NC} 查看作者酷安\n"
    printf "${PURPLE}[5]${NC} 检查更新\n"
    printf "${RED}[0]${NC} 退出\n"
    printf "%s" "请选择: "
    read _main_choice

    case "$_main_choice" in
      1) keybox_manage_menu ;;
      2) update_target_txt ;;
      3) config_security_patch ;;
      4)
        log_info "正在跳转作者酷安主页..."
        if ! run am start -a android.intent.action.VIEW -d "https://www.coolapk.com/u/38346436" 2>/dev/null; then
          log_error "跳转失败，请手动访问：https://www.coolapk.com/u/38346436"
        fi
        ;;
      5) check_update ;;
      0) exit 0 ;;
      *) echo "无效选项" ;;
    esac

    printf "\n%s" "按回车继续..."
    read _dummy
  done
}

main
