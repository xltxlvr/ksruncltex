# ksruncltex

**ksruncltex**는 [cluttex](https://github.com/minoki/cluttex)와 `minted`를 매끄럽게 함께 쓸 수 있도록 도와주는 실행 스크립트입니다. cluttex를 호출하는 얇은 래퍼(wrapper)로, 자주 쓰는 엔진 선택·매직 코멘트·자동 재시도·PDF 여백 자르기·누락 글자 수집 같은 기능을 제공합니다.

- 작성: Nova de Hi
- 지원 환경: Windows, macOS, Linux (TeX Live 또는 MiKTeX)

## 주요 기능

- **cluttex 자동 탐색**: `kpsewhich`로 `cluttex_patched.lua`를 먼저 찾고, 없으면 `cluttex.lua`를 찾아 `texlua`로 실행합니다. 둘 다 없으면 `cluttex` 명령을 호출합니다.
- **엔진 선택**: `--lualatex`(기본값), `--xelatex`, `--pdflatex`
- **매직 코멘트**: 소스 파일 맨 앞에 `%! KSRC ...`로 옵션을 적어 두면, 파일명만 넘겨도 그 옵션으로 실행합니다.
- **자동 재시도**: `minted`의 `.listing` 파일 오류나 보조 파일(`.aux`, `.toc` 등) 꼬임이 감지되면 `--fresh` 옵션을 붙여 한 번 더 실행합니다.
- **PDF 자르기**: `--crop`을 주면 성공적으로 컴파일한 뒤 `pdfcrop`으로 결과 PDF의 여백을 잘라 냅니다.
- **누락 글자 수집**: `--missingchar`를 주면 화면에 나온 `There is no ...` 메시지만 모아 `ksruncltex_missingchar.txt`로 저장합니다.

## 요구 사항

- TeX Live 또는 MiKTeX (`kpsewhich`, `texlua`가 PATH에 있어야 합니다)
- cluttex (최신 TeX Live에는 포함되어 있습니다)
- `--crop`을 쓰려면 `pdfcrop`이 필요합니다.

## 설치

배포 패키지에는 설치 스크립트와 `Resources` 폴더가 함께 들어 있습니다. 두 가지가 같은 위치에 있어야 합니다.

### Windows

```bat
install.bat
```

### macOS / Linux

```sh
sh install.sh
```

### 설치 옵션

| 옵션 | 설명 |
| --- | --- |
| (없음) | ksruncltex를 설치합니다. 이미 설치되어 있으면 그 위치를 업데이트합니다. |
| `--uninstall` | 설치된 ksruncltex를 제거합니다. |
| `--reinstall` | 제거한 뒤 다시 깨끗하게 설치합니다. |

### 설치 동작

- `ksruncltex.lua`는 기존 설치 위치(쓰기 가능한 경우) 또는 `TEXMFHOME/scripts/ksruncltex`에 복사됩니다. `TEXMFHOME`을 확인할 수 없으면 별도의 TEXMF 루트를 등록합니다.
- 명령행에서 `ksruncltex`로 실행할 수 있도록 런처가 설치됩니다. Windows에서는 `ksruncltex.bat`, macOS/Linux에서는 `ksruncltex` 스크립트이며, TeX의 bin 폴더(또는 기존 런처 위치)에 놓입니다. 쓰기 권한이 없으면 관리자 권한으로 다시 실행해 보세요.
- macOS에서 TeXShop을 쓰고 있고 `Resources`에 `ksRunCluttex.engine`이 있으면, TeXShop의 Engines 폴더에 함께 설치됩니다.
- 설치가 끝나면 파일명 데이터베이스(`mktexlsr` 또는 `initexmf --update-fndb`)를 갱신합니다.
- 예전 버전에서 쓰던 `cluttex_patched.lua`가 남아 있으면 설치 시작 단계에서 삭제합니다. 이제 설치 스크립트는 `ksruncltex.lua`만 복사합니다.

설치 후 새 터미널(명령 프롬프트)을 열어 다음 명령으로 확인합니다.

```
ksruncltex --version
ksruncltex --help
```

## 사용법

```
ksruncltex [--xelatex|--lualatex|--pdflatex] [--crop] [--missingchar] [cluttex options] <filename.tex>
```

`texlua ksruncltex.lua ...` 형태로 직접 실행해도 됩니다. 아래에 나열하지 않은 인자는 모두 cluttex로 그대로 전달되므로 cluttex의 옵션을 그대로 쓸 수 있습니다.

### 옵션

| 옵션 | 설명 |
| --- | --- |
| `--lualatex` | LuaLaTeX로 컴파일합니다. 아무 엔진도 지정하지 않으면 기본값입니다. |
| `--xelatex` | XeLaTeX로 컴파일합니다. |
| `--pdflatex` | pdfLaTeX로 컴파일합니다. |
| `--crop` | 컴파일이 성공하면 `pdfcrop`으로 결과 PDF의 여백을 잘라 같은 파일에 덮어씁니다. |
| `--missingchar` | 출력 메시지 중 `There is no ...`로 시작하는 누락 글자 정보를 `ksruncltex_missingchar.txt`에 저장합니다. |
| `--version` | ksruncltex의 버전을 출력한 뒤 cluttex의 버전을 출력합니다. |
| `--help` | 도움말을 출력합니다. |
| `--help --cluttex` | ksruncltex 도움말에 이어 cluttex의 도움말도 출력합니다. |

### 예시

```sh
# 기본(LuaLaTeX)으로 컴파일
ksruncltex main.tex

# XeLaTeX로 컴파일하고 PDF 여백 자르기
ksruncltex --xelatex --crop figure.tex

# cluttex 옵션을 함께 전달
ksruncltex --lualatex --shell-escape main.tex
```

## 매직 코멘트

파일명 하나만 인자로 주면, 소스 파일의 `\documentclass` **앞쪽**에 있는 `%! KSRC` 줄을 찾아 그 내용을 옵션으로 사용합니다.

```latex
%! KSRC --lualatex --crop --missingchar
\documentclass{article}
...
```

```sh
ksruncltex main.tex
```

주의할 점은 다음과 같습니다.

- `%! KSRC` 줄은 `\documentclass`보다 앞에 있어야 하며, 처음 발견한 한 줄만 사용합니다.
- 공백이 들어간 값은 따옴표(`'` 또는 `"`)로 묶을 수 있습니다.
- 파일명 외에 터미널에서 인자를 하나라도 더 주면 매직 코멘트는 무시되고 터미널 인자만 사용합니다.
- 확장자 `.tex`는 생략해도 매직 코멘트를 찾아 줍니다.

## 자동 재시도

컴파일이 실패했을 때 다음 중 하나가 감지되면, `--fresh` 옵션을 붙여 **한 번만** 다시 실행합니다.

- `minted`가 `.listing` 파일을 찾지 못하는 오류 (`Package minted Error`, `kpsewhich failed`)
- 보조 파일 꼬임을 나타내는 오류 (`\@writefile` 또는 `File ended while scanning use of` 관련 메시지)

그 밖의 오류는 재시도하지 않고 그대로 종료합니다. 재시도해도 실패하면 종료 코드는 마지막 실행의 종료 코드입니다.

## 누락 글자 수집 (`--missingchar`)

폰트에 없는 글자가 있으면 TeX 엔진이 다음과 같은 메시지를 냅니다.

```
Missing character: There is no X (U+XXXX) in font ...
```

`--missingchar`를 주면 출력에서 `There is no`로 시작하는 부분만 뽑아 현재 폴더의 `ksruncltex_missingchar.txt`에 저장합니다.

- 같은 메시지는 한 번만 기록하고, 처음 나온 순서를 유지합니다.
- 옵션을 켜고 실행할 때마다 파일을 새로 씁니다. 누락 글자가 없으면 빈 파일이 됩니다.
- 자동 재시도가 일어났다면 마지막 실행의 출력만 사용합니다.
- 컴파일이 실패해도 파일은 저장됩니다.
- 터미널 폭 때문에 메시지가 줄바꿈되어 출력되는 환경에서는 일부가 잘릴 수 있습니다.

## 제거

```bat
install.bat --uninstall
```

```sh
sh install.sh --uninstall
```

`ksruncltex.lua`, 명령행 런처, (macOS인 경우) TeXShop 엔진을 삭제하고 파일명 데이터베이스를 갱신합니다.

## 문제 해결

- **`kpsewhich` 또는 `texlua`를 찾을 수 없다고 나올 때**: TeX 배포판이 설치되어 있고 PATH에 등록되어 있는지 확인하세요.
- **`ksruncltex` 명령을 찾을 수 없을 때**: 설치 후 새 터미널을 열어야 합니다. 그래도 안 되면 TeX bin 폴더에 런처를 복사할 권한이 없었을 수 있으니, 관리자 권한(또는 `sudo`)으로 설치 스크립트를 다시 실행하세요.
- **`cluttex.lua not found` 경고가 나올 때**: cluttex가 설치되어 있는지 확인하고, `kpsewhich --format=lua cluttex.lua`가 경로를 출력하는지 확인하세요. 설치 직후라면 `mktexlsr`로 파일명 데이터베이스를 갱신해 보세요.
- **`--crop`이 동작하지 않을 때**: `pdfcrop`이 설치되어 있는지 확인하세요.
