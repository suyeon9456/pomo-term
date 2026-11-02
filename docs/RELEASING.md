# 배포하기 (Developer ID 서명 + 공증)

GitHub Releases 등으로 직접 배포하면서, 받는 사람이 경고 없이 바로 열 수 있게 하는 방법이에요.
처음 한 번 **준비**를 하고 나면, 이후 배포는 `./scripts/release.sh` 한 줄이에요.

## 처음 한 번 준비

### 1. Apple Developer Program 가입
- https://developer.apple.com/programs/enroll/ (개인, 연 $99)
- 승인까지 몇 시간~1–2일. 승인되면 https://developer.apple.com/account 에서 **Team ID**(10자리)를 확인해 두세요

### 2. Developer ID Application 인증서 만들기
Xcode 없이도 됩니다.

1. **키체인 접근** 앱 → 메뉴 **키체인 접근 › 인증서 지원 › 인증 기관에서 인증서 요청…**
   - 이메일: Apple ID, 일반 이름: 본인 이름, **디스크에 저장됨** 선택 → `CertificateSigningRequest.certSigningRequest` 저장
2. https://developer.apple.com/account/resources/certificates/add 에서 **Developer ID Application** 선택
   - (G2 Sub-CA 선택이 나오면 기본값) → 1에서 만든 CSR 업로드 → `.cer` 다운로드
3. 받은 `.cer`를 더블클릭해서 키체인에 설치
4. 확인: 터미널에서 아래가 `Developer ID Application: 이름 (TEAMID)`를 보여주면 성공
   ```bash
   security find-identity -v -p codesigning
   ```

> Xcode가 정상인 Mac이라면 Xcode › 설정 › Accounts › Manage Certificates… › + › Developer ID Application으로도 만들 수 있어요.

### 3. 공증용 앱 암호 만들기
- https://account.apple.com → 로그인 및 보안 → **앱 암호** → 이름 `pomo-notary`로 생성 (`xxxx-xxxx-xxxx-xxxx`)

### 4. 공증 자격 증명을 키체인에 저장
**터미널 앱**에서 실행 (암호를 물어보면 3의 앱 암호 입력):
```bash
xcrun notarytool store-credentials pomo-notary --apple-id <Apple ID 이메일> --team-id <Team ID>
```
Xcode 첫 실행 설정이 안 된 Mac에서 `xcrun`이 실패하면 앞에 `DEVELOPER_DIR=/Library/Developer/CommandLineTools`를 붙이세요.

## 배포할 때마다

1. `VERSION` 파일의 버전을 올림 (예: `1.0.1`)
2. 실행:
   ```bash
   ./scripts/release.sh
   ```
   유니버설 빌드 → 서명(Hardened Runtime) → 앱 공증·스테이플 → DMG 만들기 → DMG 서명·공증·스테이플 → zip·체크섬.
   공증은 보통 몇 분씩 걸려요. 결과는 `dist/`에:
   - `Pomo-<버전>.dmg` — 배포 권장 (열어서 응용 프로그램 폴더로 끌어다 놓기)
   - `Pomo-<버전>.zip`
   - `SHA256SUMS.txt`
3. GitHub에 태그 `v<버전>`으로 Release를 만들고 위 파일을 올림

인증서가 아직 없으면 스크립트는 서명·공증 없이 DMG·zip만 만들어요. 이 파일은 처음 열 때 "확인되지 않은 개발자" 경고가 나오고, 우클릭 → 열기로 열 수 있어요.

## 문제 해결
- **공증 실패 이유 보기**: `xcrun notarytool log <submission id> --keychain-profile pomo-notary`
- **서명 확인**: `codesign -dv --verbose=4 build/Pomo.app`, `spctl -a -vv build/Pomo.app`
- 인증서를 다른 Mac으로 옮길 때는 키체인 접근에서 인증서 + 개인 키를 `.p12`로 내보내서 가져오기
