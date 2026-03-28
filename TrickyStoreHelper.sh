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

CURRENT_VERSION="1.0.0"
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
  init_command_cache__init_toybox_out=""
  init_command_cache__init_busybox_out=""
  if command -v toybox >/dev/null 2>&1; then
    init_command_cache__init_toybox_out=$(toybox --list 2>/dev/null | tr '\n' ' ')
    TOYBOX_COMMANDS=" $init_command_cache__init_toybox_out "
  fi
  if command -v busybox >/dev/null 2>&1; then
    init_command_cache__init_busybox_out=$(busybox --list 2>/dev/null | tr '\n' ' ')
    BUSYBOX_COMMANDS=" $init_command_cache__init_busybox_out "
  fi
  unset init_command_cache__init_toybox_out init_command_cache__init_busybox_out
}

run() {
  run__cmd="$1"
  shift
  if [ -n "$TOYBOX_COMMANDS" ]; then
    case "$TOYBOX_COMMANDS" in
      *" $run__cmd "*)
        toybox "$run__cmd" "$@"
        return $?
        ;;
    esac
  fi
  if [ -n "$BUSYBOX_COMMANDS" ]; then
    case "$BUSYBOX_COMMANDS" in
      *" $run__cmd "*)
        busybox "$run__cmd" "$@"
        return $?
        ;;
    esac
  fi
  if command -v "$run__cmd" >/dev/null 2>&1; then
    "$run__cmd" "$@"
    return $?
  fi
  printf "${RED}[ERROR]${NC} 命令 '%s' 不可用（toybox/busybox/系统均未找到）\n" "$run__cmd" >&2
  unset run__cmd
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
  version_ge__ver1="$1"
  version_ge__ver2="$2"
  version_ge__i=1
  while [ "$version_ge__i" -le 5 ]; do
    version_ge__n1=$(printf "%s" "$version_ge__ver1" | run cut -d. -f"$version_ge__i" 2>/dev/null)
    version_ge__n2=$(printf "%s" "$version_ge__ver2" | run cut -d. -f"$version_ge__i" 2>/dev/null)
    version_ge__n1=${version_ge__n1:-0}
    version_ge__n2=${version_ge__n2:-0}
    version_ge__n1=$(printf "%s" "$version_ge__n1" | run sed 's/^0*//')
    version_ge__n1=${version_ge__n1:-0}
    version_ge__n2=$(printf "%s" "$version_ge__n2" | run sed 's/^0*//')
    version_ge__n2=${version_ge__n2:-0}
    if [ "$version_ge__n1" -gt "$version_ge__n2" ]; then
      unset version_ge__ver1 version_ge__ver2 version_ge__i version_ge__n1 version_ge__n2
      return 0
    fi
    if [ "$version_ge__n1" -lt "$version_ge__n2" ]; then
      unset version_ge__ver1 version_ge__ver2 version_ge__i version_ge__n1 version_ge__n2
      return 1
    fi
    version_ge__i=$((version_ge__i + 1))
  done
  unset version_ge__ver1 version_ge__ver2 version_ge__i version_ge__n1 version_ge__n2
  return 0
}

show_decode_progress() {
  show_decode_progress__current="$1"
  show_decode_progress__total="$2"
  show_decode_progress__bar_len=20
  show_decode_progress__filled=$((show_decode_progress__current * show_decode_progress__bar_len / show_decode_progress__total))
  show_decode_progress__empty=$((show_decode_progress__bar_len - show_decode_progress__filled))
  
  show_decode_progress__bar=""
  show_decode_progress__j=0
  while [ "$show_decode_progress__j" -lt "$show_decode_progress__filled" ]; do
    show_decode_progress__bar="$show_decode_progress__bar#"
    show_decode_progress__j=$((show_decode_progress__j + 1))
  done
  
  show_decode_progress__empty_bar=""
  show_decode_progress__j=0
  while [ "$show_decode_progress__j" -lt "$show_decode_progress__empty" ]; do
    show_decode_progress__empty_bar="$show_decode_progress__empty_bar-"
    show_decode_progress__j=$((show_decode_progress__j + 1))
  done
  
  printf "${BLUE}[DECODE]${NC} [%s%s] %d/%d 层 \r" "$show_decode_progress__bar" "$show_decode_progress__empty_bar" "$show_decode_progress__current" "$show_decode_progress__total"
  if [ "$show_decode_progress__current" -eq "$show_decode_progress__total" ]; then
    printf "\n"
  fi
  unset show_decode_progress__current show_decode_progress__total show_decode_progress__bar_len show_decode_progress__filled show_decode_progress__empty show_decode_progress__bar show_decode_progress__empty_bar show_decode_progress__j
}

check_root() {
  check_root__check_root_uid=$(run id -u)
  if [ "$check_root__check_root_uid" -ne 0 ]; then
    log_error "需要 Root 权限!"
    exit 1
  fi
  unset check_root__check_root_uid
}

check_tools() {
  check_tools__check_missing=""
  check_tools__check_has_curl=0
  check_tools__check_has_wget=0
  check_tools__required_tools="id xxd base64 readlink grep sed awk sort wc head tr cat rm mkdir cp mv chmod touch ls pm dirname basename pwd cut date getprop sha256sum"

  case "$TOYBOX_COMMANDS" in *" wget "*) check_tools__check_has_wget=1 ;; esac
  case "$BUSYBOX_COMMANDS" in *" wget "*) check_tools__check_has_wget=1 ;; esac
  case "$TOYBOX_COMMANDS" in *" curl "*) check_tools__check_has_curl=1 ;; esac
  case "$BUSYBOX_COMMANDS" in *" curl "*) check_tools__check_has_curl=1 ;; esac

  if [ "$check_tools__check_has_wget" -eq 0 ] && [ "$check_tools__check_has_curl" -eq 0 ]; then
    if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
      check_tools__check_missing="$check_tools__check_missing wget/curl"
    fi
  fi

  for check_tools__tool in $check_tools__required_tools; do
    check_tools__has_tool=0
    case "$TOYBOX_COMMANDS" in *" $check_tools__tool "*) check_tools__has_tool=1 ;; esac
    case "$BUSYBOX_COMMANDS" in *" $check_tools__tool "*) check_tools__has_tool=1 ;; esac
    if [ "$check_tools__has_tool" -eq 1 ] || command -v "$check_tools__tool" >/dev/null 2>&1; then
      continue
    fi
    check_tools__check_missing="$check_tools__check_missing $check_tools__tool"
  done

  if [ -n "$check_tools__check_missing" ]; then
    log_error "缺少必要工具: $check_tools__check_missing"
    exit 1
  fi

  unset check_tools__check_missing check_tools__check_has_curl check_tools__check_has_wget check_tools__required_tools check_tools__tool check_tools__has_tool
}

init_env() {
  run rm -rf "$TMP_DIR"
  run mkdir -p "$TMP_DIR"
  run mkdir -p "$TS_DIR"
}

get_script_path() {
  get_script_path__has_readlink=0
  get_script_path__script_dir=""
  get_script_path__script_name=""
  get_script_path__abs_dir=""
  SCRIPT_PATH=""

  case "$TOYBOX_COMMANDS" in *" readlink "*) get_script_path__has_readlink=1 ;; esac
  case "$BUSYBOX_COMMANDS" in *" readlink "*) get_script_path__has_readlink=1 ;; esac

  if [ "$get_script_path__has_readlink" -eq 1 ] || command -v readlink >/dev/null 2>&1; then
    SCRIPT_PATH=$(run readlink -f "$0" 2>/dev/null)
  fi

  if [ -z "$SCRIPT_PATH" ] || [ ! -f "$SCRIPT_PATH" ]; then
    get_script_path__script_dir=$(run dirname "$0" 2>/dev/null)
    get_script_path__script_name=$(run basename "$0" 2>/dev/null)
    if [ -n "$get_script_path__script_dir" ] && [ -n "$get_script_path__script_name" ]; then
      get_script_path__abs_dir=$(cd "$get_script_path__script_dir" && run pwd 2>/dev/null)
      if [ -n "$get_script_path__abs_dir" ]; then
        SCRIPT_PATH="$get_script_path__abs_dir/$get_script_path__script_name"
      fi
    fi
  fi

  if [ -z "$SCRIPT_PATH" ] || [ ! -f "$SCRIPT_PATH" ]; then
    SCRIPT_PATH="$0"
  fi

  if [ ! -w "$SCRIPT_PATH" ]; then
    log_error "脚本文件无写入权限，无法执行更新操作"
    unset get_script_path__has_readlink get_script_path__script_dir get_script_path__script_name get_script_path__abs_dir
    return 1
  fi

  unset get_script_path__has_readlink get_script_path__script_dir get_script_path__script_name get_script_path__abs_dir
  return 0
}

download_file() {
  download_file__url="$1"
  download_file__dest="$2"
  download_file__success=1
  download_file__has_wget=0

  run rm -f "$download_file__dest"

  case "$TOYBOX_COMMANDS" in *" wget "*) download_file__has_wget=1 ;; esac
  case "$BUSYBOX_COMMANDS" in *" wget "*) download_file__has_wget=1 ;; esac

  if [ "$download_file__has_wget" -eq 1 ] || command -v wget >/dev/null 2>&1; then
    log_info "正在使用 wget 下载…"
    if run wget -T 10 -t 2 --no-check-certificate -q -O "$download_file__dest" "$download_file__url"; then
      download_file__success=0
    fi
  fi

  if [ "$download_file__success" -ne 0 ]; then
    log_warn "wget 下载失败，尝试使用 curl 下载…"
    if run curl -fL -sS --connect-timeout 10 --retry 2 "$download_file__url" -o "$download_file__dest"; then
      download_file__success=0
    fi
  fi

  if [ "$download_file__success" -eq 0 ] && [ -s "$download_file__dest" ]; then
    log_info "下载完成"
    unset download_file__url download_file__dest download_file__success download_file__has_wget
    return 0
  else
    log_error "下载失败或文件为空: $download_file__url"
    run rm -f "$download_file__dest"
    unset download_file__url download_file__dest download_file__success download_file__has_wget
    return 1
  fi
}



check_update() {
  check_update__update_tmp="$TMP_DIR/update.json"
  check_update__remote_version=""
  check_update__update_url=""
  check_update__update_log=""
  check_update__need_update=""
  check_update__remote_sha256=""
  check_update__is_need_update=0
  check_update__confirm=""
  check_update__new_script="$TMP_DIR/new_tricky_helper.sh"
  check_update__file_hash=""

  clear_screen
  run sleep 1
  log_info "正在检查更新..."

  if ! get_script_path; then
    unset check_update__update_tmp check_update__remote_version check_update__update_url check_update__update_log check_update__need_update check_update__remote_sha256 check_update__is_need_update check_update__confirm check_update__new_script check_update__file_hash
    return 1
  fi

  log_info "正在拉取远程更新配置..."
  if ! download_file "$UPDATE_JSON_URL" "$check_update__update_tmp"; then
    log_error "更新配置文件获取失败，请检查网络连接后重试"
    unset check_update__update_tmp check_update__remote_version check_update__update_url check_update__update_log check_update__need_update check_update__remote_sha256 check_update__is_need_update check_update__confirm check_update__new_script check_update__file_hash
    return 1
  fi

  log_info "正在解析更新信息..."
  check_update__remote_version=$(run grep -o '"version": *"[^"]*"' "$check_update__update_tmp" | run sed 's/"version": *"//;s/"//g')
  check_update__update_url=$(run grep -o '"update_url": *"[^"]*"' "$check_update__update_tmp" | run sed 's/"update_url": *"//;s/"//g')
  check_update__update_log=$(run grep -o '"update_log": *"[^"]*"' "$check_update__update_tmp" | run sed 's/"update_log": *"//;s/"//g')
  check_update__need_update=$(run grep -o '"need_update": *"[^"]*"' "$check_update__update_tmp" | run sed 's/"need_update": *"//;s/"//g')
  check_update__remote_sha256=$(run grep -o '"sha256sum": *"[^"]*"' "$check_update__update_tmp" | run sed 's/"sha256sum": *"//;s/"//g')

  if [ -z "$check_update__remote_version" ] || [ -z "$check_update__update_url" ] || [ -z "$check_update__remote_sha256" ]; then
    log_error "更新配置解析失败，缺少版本号、下载地址或哈希校验字段"
    unset check_update__update_tmp check_update__remote_version check_update__update_url check_update__update_log check_update__need_update check_update__remote_sha256 check_update__is_need_update check_update__confirm check_update__new_script check_update__file_hash
    return 1
  fi

  printf "\n${CYAN}当前版本:${NC} v%s\n" "$CURRENT_VERSION"
  printf "${CYAN}最新版本:${NC} v%s\n\n" "$check_update__remote_version"

  if ! version_ge "$CURRENT_VERSION" "$check_update__remote_version"; then
    if [ "$check_update__need_update" = "true" ]; then
      check_update__is_need_update=1
    else
      log_warn "发现新版本，但远程配置关闭了强制更新，跳过更新"
    fi
  fi

  if [ "$check_update__is_need_update" -eq 0 ]; then
    log_info "✅ 当前已是最新版本，无需更新"
    unset check_update__update_tmp check_update__remote_version check_update__update_url check_update__update_log check_update__need_update check_update__remote_sha256 check_update__is_need_update check_update__confirm check_update__new_script check_update__file_hash
    return 0
  fi

  printf "${YELLOW}===== 发现可用新版本 =====${NC}\n"
  printf "${CYAN}新版本号:${NC} v%s\n" "$check_update__remote_version"
  printf "${CYAN}更新内容:${NC} %s\n" "$check_update__update_log"
  printf "${YELLOW}==========================${NC}\n\n"

  printf "%s" "是否立即更新到最新版本？[y/n] "
  read check_update__confirm
  case "$check_update__confirm" in
    [Yy]*)
      log_info "正在下载新版本安装包..."
      if ! download_file "$check_update__update_url" "$check_update__new_script"; then
        log_error "新版本脚本下载失败，更新已终止"
        unset check_update__update_tmp check_update__remote_version check_update__update_url check_update__update_log check_update__need_update check_update__remote_sha256 check_update__is_need_update check_update__confirm check_update__new_script check_update__file_hash
        return 1
      fi

      if [ ! -s "$check_update__new_script" ]; then
        log_error "下载的新版本文件为空，更新已终止"
        run rm -f "$check_update__new_script"
        unset check_update__update_tmp check_update__remote_version check_update__update_url check_update__update_log check_update__need_update check_update__remote_sha256 check_update__is_need_update check_update__confirm check_update__new_script check_update__file_hash
        return 1
      fi

      log_info "正在校验新版本文件哈希..."
      check_update__file_hash=$(run sha256sum "$check_update__new_script" | run awk '{print $1}')
      
      if [ -z "$check_update__file_hash" ]; then
        log_error "文件哈希计算失败，更新已终止"
        run rm -f "$check_update__new_script"
        unset check_update__update_tmp check_update__remote_version check_update__update_url check_update__update_log check_update__need_update check_update__remote_sha256 check_update__is_need_update check_update__confirm check_update__new_script check_update__file_hash
        return 1
      fi

      if [ "$check_update__file_hash" != "$check_update__remote_sha256" ]; then
        log_error "❌ 文件哈希校验不通过！"
        log_error "预期哈希: $check_update__remote_sha256"
        log_error "实际哈希: $check_update__file_hash"
        log_error "文件可能被篡改、下载不完整或配置错误，更新已自动终止"
        run rm -f "$check_update__new_script"
        unset check_update__update_tmp check_update__remote_version check_update__update_url check_update__update_log check_update__need_update check_update__remote_sha256 check_update__is_need_update check_update__confirm check_update__new_script check_update__file_hash
        return 1
      fi

      log_info "✅ 哈希校验通过，文件安全完整"
      log_info "正在替换脚本文件..."
      if ! run cp -f "$check_update__new_script" "$SCRIPT_PATH"; then
        log_error "脚本文件替换失败，请检查目录权限"
        run rm -f "$check_update__new_script"
        unset check_update__update_tmp check_update__remote_version check_update__update_url check_update__update_log check_update__need_update check_update__remote_sha256 check_update__is_need_update check_update__confirm check_update__new_script check_update__file_hash
        return 1
      fi

      run chmod 755 "$SCRIPT_PATH"
      if [ $? -ne 0 ]; then
        log_warn "脚本执行权限设置失败"
      fi

      run rm -f "$check_update__new_script"
      log_info "✅ 脚本更新成功！"
      printf "%s\n" "脚本更新完毕，请重新执行脚本"
      run sleep 1
      unset check_update__update_tmp check_update__remote_version check_update__update_url check_update__update_log check_update__need_update check_update__remote_sha256 check_update__is_need_update check_update__confirm check_update__new_script check_update__file_hash
      exit 0
      ;;
    *)
      log_warn "已取消更新，返回主菜单"
      run rm -f "$check_update__new_script"
      unset check_update__update_tmp check_update__remote_version check_update__update_url check_update__update_log check_update__need_update check_update__remote_sha256 check_update__is_need_update check_update__confirm check_update__new_script check_update__file_hash
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
  fetch_integritybox__process_file="$TMP_DIR/process.tmp"
  fetch_integritybox__next_file="$TMP_DIR/process.next"
  fetch_integritybox__i=1
  fetch_integritybox__clean_file="$TMP_DIR/clean.tmp"

  log_info "[1/3] 正在下载 IntegrityBox 源..."
  if ! download_file "$INTEGRITYBOX_URL" "$TMP_RAW"; then
    unset fetch_integritybox__process_file fetch_integritybox__next_file fetch_integritybox__i fetch_integritybox__clean_file
    return 1
  fi
  run tr -d '\n\r ' < "$TMP_RAW" > "$fetch_integritybox__process_file"

  log_info "[2/3] 正在解码 (10层Base64)..."
  while [ "$fetch_integritybox__i" -le 10 ]; do
    if [ ! -s "$fetch_integritybox__process_file" ]; then
      log_error "解码中断：第 $fetch_integritybox__i 层数据为空"
      unset fetch_integritybox__process_file fetch_integritybox__next_file fetch_integritybox__i fetch_integritybox__clean_file
      return 1
    fi
    show_decode_progress "$fetch_integritybox__i" 10
    run tr -d '\n\r ' < "$fetch_integritybox__process_file" > "$fetch_integritybox__clean_file"
    if ! run base64 -d "$fetch_integritybox__clean_file" > "$fetch_integritybox__next_file" 2>/dev/null; then
      log_error "第 $fetch_integritybox__i 层 Base64 解码失败"
      unset fetch_integritybox__process_file fetch_integritybox__next_file fetch_integritybox__i fetch_integritybox__clean_file
      return 1
    fi
    run mv -f "$fetch_integritybox__next_file" "$fetch_integritybox__process_file"
    fetch_integritybox__i=$((fetch_integritybox__i + 1))
  done

  log_info "[3/3] 正在格式转换..."
  if ! run cat "$fetch_integritybox__process_file" | run xxd -r -p | run tr 'A-Za-z' 'N-ZA-Mn-za-m' > "$TMP_KEYBOX"; then
    log_error "最终格式转换失败"
    unset fetch_integritybox__process_file fetch_integritybox__next_file fetch_integritybox__i fetch_integritybox__clean_file
    return 1
  fi
  if [ ! -s "$TMP_KEYBOX" ]; then
    log_error "最终文件为空"
    unset fetch_integritybox__process_file fetch_integritybox__next_file fetch_integritybox__i fetch_integritybox__clean_file
    return 1
  fi
  unset fetch_integritybox__process_file fetch_integritybox__next_file fetch_integritybox__i fetch_integritybox__clean_file
  return 0
}

validate_keybox() {
  validate_keybox__file="$1"
  if [ ! -s "$validate_keybox__file" ]; then
    log_error "生成的 Keybox 文件无效 (空文件)"
    unset validate_keybox__file
    return 1
  fi
  if ! run grep -q "<?xml" "$validate_keybox__file" || \
     ! run grep -q "<AndroidAttestation>" "$validate_keybox__file" || \
     ! run grep -q "BEGIN CERTIFICATE" "$validate_keybox__file"; then
    log_error "Keybox 内容校验失败"
    unset validate_keybox__file
    return 1
  fi
  validate_keybox__size=$(run wc -c < "$validate_keybox__file" 2>/dev/null | run tr -d ' ')
  log_info "校验通过，文件大小: $validate_keybox__size 字节"
  unset validate_keybox__file validate_keybox__size
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
    printf "%s\n" "..."
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
    read keybox_manage_menu__sub_choice

    case "$keybox_manage_menu__sub_choice" in
      1) fetch_yurikey && validate_keybox "$TMP_KEYBOX" && install_keybox ;;
      2) fetch_tricky_addon && validate_keybox "$TMP_KEYBOX" && install_keybox ;;
      3) fetch_integritybox && validate_keybox "$TMP_KEYBOX" && install_keybox ;;
      4) show_current ;;
      0) unset keybox_manage_menu__sub_choice; return 0 ;;
      *) printf "%s\n" "无效选项" ;;
    esac

    printf "\n%s" "按回车继续..."
    read keybox_manage_menu__dummy
  done
  unset keybox_manage_menu__sub_choice keybox_manage_menu__dummy
}



update_target_txt() {
  update_target_txt__target_file="$TS_DIR/target.txt"
  update_target_txt__suffix=""
  update_target_txt__mode_choice=""
  update_target_txt__pkg_third=""
  update_target_txt__pkg_system=""
  update_target_txt__packages=""
  update_target_txt__include_system_app="com.google.android.gms com.google.android.gsf com.android.vending com.oplus.deepthinker com.heytap.speechassist com.coloros.sceneservice"

  clear_screen

  while true; do
    clear_screen
    printf "${CYAN}选择密钥注入模式${NC}\n"
    printf "${GREEN}[1]${NC} 正常模式\n"
    printf "${YELLOW}[2]${NC} 生成证书链（!）\n"
    printf "${YELLOW}[3]${NC} 修改证书链（?）\n"
    printf "${RED}[0]${NC} 退出\n"
    printf "%s" "请选择模式: "
    read update_target_txt__mode_choice
    case "$update_target_txt__mode_choice" in
      1) update_target_txt__suffix=""; break ;;
      2) update_target_txt__suffix="!"; break ;;
      3) update_target_txt__suffix="?"; break ;;
      0) unset update_target_txt__target_file update_target_txt__suffix update_target_txt__mode_choice update_target_txt__pkg_third update_target_txt__pkg_system update_target_txt__packages update_target_txt__include_system_app; return 0 ;;
      *)
        printf "${RED}无效选项，请重新选择${NC}\n"
        run sleep 1
        ;;
    esac
  done

  clear_screen
  log_info "正在获取应用列表..."

  update_target_txt__pkg_third=$(run pm list packages -3 2>/dev/null | run awk -F: '{print $2}' 2>/dev/null)

  for update_target_txt__app in $update_target_txt__include_system_app; do
    if run pm list packages -s 2>/dev/null | run grep -xq "package:$update_target_txt__app"; then
      update_target_txt__pkg_system=$(printf "%s\n%s" "$update_target_txt__pkg_system" "$update_target_txt__app")
      log_info "已添加系统应用：$update_target_txt__app"
    else
      log_warn "系统中未找到应用：$update_target_txt__app，已跳过"
    fi
  done

  update_target_txt__packages=$(printf "%s%s" "$update_target_txt__pkg_third" "$update_target_txt__pkg_system" | run sort -u | run grep -v '^$')

  if [ -z "$update_target_txt__packages" ]; then
    log_error "未获取到任何应用包名"
    run sleep 2
    unset update_target_txt__target_file update_target_txt__suffix update_target_txt__mode_choice update_target_txt__pkg_third update_target_txt__pkg_system update_target_txt__packages update_target_txt__include_system_app update_target_txt__app
    return 1
  fi

  update_target_txt__app_count=$(printf "%s\n" "$update_target_txt__packages" | run wc -l)
  log_info "共获取到 $update_target_txt__app_count 个应用"
  log_info "正在写入 $update_target_txt__target_file ..."

  run mkdir -p "$TS_DIR"

  printf "%s\n" "$update_target_txt__packages" | while read -r update_target_txt__pkg; do
    if [ -n "$update_target_txt__pkg" ]; then
      printf "%s%s\n" "$update_target_txt__pkg" "$update_target_txt__suffix"
    fi
  done > "$update_target_txt__target_file"

  if [ $? -eq 0 ] && [ -s "$update_target_txt__target_file" ]; then
    update_target_txt__final_count=$(run wc -l < "$update_target_txt__target_file")
    log_info "✅ target.txt 更新成功！共写入 $update_target_txt__final_count 条包名"
    printf "${CYAN}文件路径:${NC} %s\n" "$update_target_txt__target_file"
    printf "${CYAN}内容预览:${NC}\n"
    run head -n 10 "$update_target_txt__target_file"
    if [ "$update_target_txt__final_count" -gt 10 ]; then
      printf "... 共 %s 个应用\n" "$update_target_txt__final_count"
    fi
  else
    log_error "写入文件失败，请检查目录权限"
    unset update_target_txt__target_file update_target_txt__suffix update_target_txt__mode_choice update_target_txt__pkg_third update_target_txt__pkg_system update_target_txt__packages update_target_txt__include_system_app update_target_txt__app update_target_txt__app_count update_target_txt__final_count update_target_txt__pkg
    return 1
  fi
  unset update_target_txt__target_file update_target_txt__suffix update_target_txt__mode_choice update_target_txt__pkg_third update_target_txt__pkg_system update_target_txt__packages update_target_txt__include_system_app update_target_txt__app update_target_txt__app_count update_target_txt__final_count update_target_txt__pkg
  return 0
}


get_latest_security_patch() {
  get_latest_security_patch__security_patch=""
  get_latest_security_patch__security_patch=$(run wget -T 15 --no-check-certificate -qO- "$SECURITY_BULLETIN_URL" 2>/dev/null | \
                   run sed -n 's/.*<td>\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)<\/td>.*/\1/p' | \
                   run head -n 1)

  if [ -z "$get_latest_security_patch__security_patch" ]; then
    get_latest_security_patch__security_patch=$(run curl --connect-timeout 15 -Ls "$SECURITY_BULLETIN_URL" 2>/dev/null | \
                     run sed -n 's/.*<td>\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)<\/td>.*/\1/p' | \
                     run head -n 1)
  fi

  if [ -n "$get_latest_security_patch__security_patch" ]; then
    printf "%s\n" "$get_latest_security_patch__security_patch"
    unset get_latest_security_patch__security_patch
    return 0
  else
    log_warn "获取官方安全补丁失败，使用系统当前补丁"
    run getprop ro.build.version.security_patch
    unset get_latest_security_patch__security_patch
    return 1
  fi
}

set_trickystore_security() {
  set_trickystore_security__TARGET_PATCH="$1"
  if [ -z "$set_trickystore_security__TARGET_PATCH" ]; then
    set_trickystore_security__TARGET_PATCH=$(run getprop ro.build.version.security_patch)
    log_warn "未指定补丁日期，使用系统当前补丁：$set_trickystore_security__TARGET_PATCH"
  fi

  set_trickystore_security__FORMATTED=$(printf "%s" "$set_trickystore_security__TARGET_PATCH" | run sed 's/-//g')
  set_trickystore_security__TODAY=$(run date +%Y%m%d)
  set_trickystore_security__PATCH_1Y_LATER=$((set_trickystore_security__FORMATTED + 10000))

  if [ -n "$set_trickystore_security__FORMATTED" ] && [ "$set_trickystore_security__TODAY" -lt "$set_trickystore_security__PATCH_1Y_LATER" ]; then
    log_info "安全补丁有效：$set_trickystore_security__TARGET_PATCH，开始写入TrickyStore"
  else
    log_error "安全补丁已过期或无效，取消设置"
    unset set_trickystore_security__TARGET_PATCH set_trickystore_security__FORMATTED set_trickystore_security__TODAY set_trickystore_security__PATCH_1Y_LATER
    return 1
  fi

  set_trickystore_security__TS_PROP="/data/adb/modules/tricky_store/module.prop"
  set_trickystore_security__TS_VERSION=0
  if [ -f "$set_trickystore_security__TS_PROP" ]; then
    set_trickystore_security__TS_VERSION=$(run grep "versionCode=" "$set_trickystore_security__TS_PROP" | run cut -d'=' -f2)
    case "$set_trickystore_security__TS_VERSION" in
      *[!0-9]*) set_trickystore_security__TS_VERSION=0 ;;
    esac
  fi

  if [ -f "$set_trickystore_security__TS_PROP" ] && run grep -q "James" "$set_trickystore_security__TS_PROP" && ! run grep -q "beakthoven" "$set_trickystore_security__TS_PROP"; then
    set_trickystore_security__SEC_FILE="$TS_DIR/devconfig.toml"
    if [ -f "$set_trickystore_security__SEC_FILE" ]; then
      if run grep -q "^securityPatch" "$set_trickystore_security__SEC_FILE"; then
        run sed "s/^securityPatch .*/securityPatch = \"$set_trickystore_security__TARGET_PATCH\"/" "$set_trickystore_security__SEC_FILE" > "$set_trickystore_security__SEC_FILE.tmp" && run mv -f "$set_trickystore_security__SEC_FILE.tmp" "$set_trickystore_security__SEC_FILE"
      else
        if ! run grep -q "^\\[deviceProps\\]" "$set_trickystore_security__SEC_FILE"; then
          printf "securityPatch = \"%s\"\n" "$set_trickystore_security__TARGET_PATCH" >> "$set_trickystore_security__SEC_FILE"
        else
          run sed "s/^\[deviceProps\]/securityPatch = \"$set_trickystore_security__TARGET_PATCH\"\n&/" "$set_trickystore_security__SEC_FILE" > "$set_trickystore_security__SEC_FILE.tmp" && run mv -f "$set_trickystore_security__SEC_FILE.tmp" "$set_trickystore_security__SEC_FILE"
        fi
      fi
      log_info "已写入 James 版 TrickyStore: $set_trickystore_security__SEC_FILE"
    else
      log_error "未找到 James 版配置文件 $set_trickystore_security__SEC_FILE"
      unset set_trickystore_security__TARGET_PATCH set_trickystore_security__FORMATTED set_trickystore_security__TODAY set_trickystore_security__PATCH_1Y_LATER set_trickystore_security__TS_PROP set_trickystore_security__TS_VERSION set_trickystore_security__SEC_FILE
      return 1
    fi
  elif [ "$set_trickystore_security__TS_VERSION" -ge 158 ] || run grep -q "beakthoven" "$set_trickystore_security__TS_PROP" 2>/dev/null; then
    set_trickystore_security__SEC_FILE="$TS_DIR/security_patch.txt"
    printf "system=prop\nboot=%s\nvendor=%s\n" "$set_trickystore_security__TARGET_PATCH" "$set_trickystore_security__TARGET_PATCH" > "$set_trickystore_security__SEC_FILE"
    run chmod 644 "$set_trickystore_security__SEC_FILE"
    log_info "已写入新版 TrickyStore: $set_trickystore_security__SEC_FILE"
  else
    run resetprop ro.build.version.security_patch "$set_trickystore_security__TARGET_PATCH"
    run resetprop ro.vendor.build.security_patch "$set_trickystore_security__TARGET_PATCH"
    log_info "旧版TrickyStore，已修改系统安全补丁属性"
  fi
  unset set_trickystore_security__TARGET_PATCH set_trickystore_security__FORMATTED set_trickystore_security__TODAY set_trickystore_security__PATCH_1Y_LATER set_trickystore_security__TS_PROP set_trickystore_security__TS_VERSION set_trickystore_security__SEC_FILE
  return 0
}

config_security_patch() {
  clear_screen
  log_info "获取安卓官方最新安全补丁"
  config_security_patch__LATEST_PATCH=$(get_latest_security_patch)
  if [ -z "$config_security_patch__LATEST_PATCH" ]; then
    log_error "无法获取有效安全补丁日期"
    printf "\n%s" "按回车继续..."
    read config_security_patch__dummy
    unset config_security_patch__LATEST_PATCH config_security_patch__dummy
    return 1
  fi
  log_info "最新安全补丁：$config_security_patch__LATEST_PATCH"

  log_info "配置 TrickyStore 安全补丁"
  if set_trickystore_security "$config_security_patch__LATEST_PATCH"; then
    log_info "✅ 安全补丁配置完成！"
  else
    log_error "❌ 安全补丁配置失败"
  fi

  printf "\n%s" "按回车继续..."
  read config_security_patch__dummy
  unset config_security_patch__LATEST_PATCH config_security_patch__dummy
}


cleanup() {
  run rm -rf "$TMP_DIR"
  log_info "临时文件已清理"
}

main() {
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
    read main__main_choice

    case "$main__main_choice" in
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
      0) unset main__main_choice; exit 0 ;;
      *) printf "%s\n" "无效选项" ;;
    esac

    printf "\n%s" "按回车继续..."
    read main__dummy
  done
  unset main__main_choice main__dummy
}

main
