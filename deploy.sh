# 계약 배포 디렉토리로 이동
cd /Users/gyu/project/nads-pump/contracts

# .env 파일 로드
source .env

# 배포 스크립트 실행 및 로그 캡처
echo "Deploying contracts..."
DEPLOY_OUTPUT=$(forge script script/Deploy.s.sol:NadFun --fork-url $RPC_URL --broadcast --via-ir)
echo "$DEPLOY_OUTPUT"
# 주소 추출
BONDING_CURVE_FACTORY=$(echo "$DEPLOY_OUTPUT" | grep "BONDING_CURVE_FACTORY=" | awk '{print $2}')
DEX_FACTORY=$(echo "$DEPLOY_OUTPUT" | grep "DEX_FACTORY=" | awk '{print $2}')
CORE=$(echo "$DEPLOY_OUTPUT" | grep "CORE=" | awk '{print $2}')
WNATIVE=$(echo "$DEPLOY_OUTPUT" | grep "WNATIVE=" | awk '{print $2}')
DEX_ROUTER=$(echo "$DEPLOY_OUTPUT" | grep "DEX_ROUTER=" | awk '{print $2}')
UNISWAP_ROUTER=$(echo "$DEPLOY_OUTPUT" | grep "UNISWAP_ROUTER=" | awk '{print $2}')
FEE_VAULT=$(echo "$DEPLOY_OUTPUT" | grep "FEE_VAULT=" | awk '{print $2}')
START_BLOCK=$(echo "$DEPLOY_OUTPUT" | grep "START_BLOCK=" | awk '{print $2}')

echo "Extracted START_BLOCK: $START_BLOCK"
# 함수: .env 파일 업데이트
update_env_file() {
   local DIR=$1
   echo "Updating .env in $DIR..."
   
   # 디렉토리로 이동
   cd /Users/gyu/project/nads-pump/$DIR
   
   # 기존 .env 파일 백업
   cp .env .env.backup
   
   # 각 변수 업데이트
   sed -i '' "s|BONDING_CURVE_FACTORY=.*|BONDING_CURVE_FACTORY=$BONDING_CURVE_FACTORY|" .env
   sed -i '' "s|DEX_FACTORY=.*|DEX_FACTORY=$DEX_FACTORY|" .env
   sed -i '' "s|CORE=.*|CORE=$CORE|" .env
   sed -i '' "s|WNATIVE=.*|WNATIVE=$WNATIVE|" .env
   sed -i '' "s|FEE_VAULT=.*|FEE_VAULT=$FEE_VAULT|" .env
   sed -i '' "s|DEX_ROUTER *=.*|DEX_ROUTER=$DEX_ROUTER|" .env
  sed -i '' "s|UNISWAP_ROUTER *=.*|UNISWAP_ROUTER=$UNISWAP_ROUTER|" .env
   sed -i '' "s|START_BLOCK=.*|START_BLOCK=$START_BLOCK|" .env
   sed -i '' "s|END_BLOCK=.*|END_BLOCK=9999999999999999999|" .env
   
   echo "Updated $DIR/.env successfully!"
   echo "A backup of the original file has been created as $DIR/.env.backup"
   echo "Updated contract addresses in $DIR:"
   grep -E "BONDING_CURVE_FACTORY|DEX_ROUTER|DEX_FACTORY|CORE|WNATIVE|FEE_VAULT|UNISWAP_ROUTER" .env
   echo "----------------------------------------"
}

# observer와 tester의 .env 파일 업데이트
update_env_file "observer"
update_env_file "tester"

echo "All environment files have been updated successfully!"

cd /Users/gyu/project/nads-pump/contracts

# Set output directory for ABIs
OBSERVER_ABI_DIR="/Users/gyu/project/nads-pump/observer/abi"
KEYSTORE_ABI_DIR="/Users/gyu/project/nads-pump/keystore/abi"
# Create output directory if it doesn't exist
mkdir -p $OBSERVER_ABI_DIR

# Define interface list
INTERFACES=(
  "IBondingCurve"
  "IBondingCurveFactory" 
  "ICore"
  "IToken"
  "IDexRouter"
  "IUniswapV2Factory"
  "IUniswapV2Router"
  "IUniswapV2Pair"
)

echo "Copying ABIs to observer..."

# Copy ABI files to observer directory
for interface in "${INTERFACES[@]}"; do
  echo "Copying ABI for $interface..."
  cp "out/$interface.sol/$interface.json" "$OBSERVER_ABI_DIR/$interface.json"
  cp "out/$interface.sol/$interface.json" "$KEYSTORE_ABI_DIR/$interface.json"
done

# Observer ABI 업데이트
cd $OBSERVER_ABI_DIR
echo "Observer ABI 업데이트 중..."

# Prettier로 각 JSON 파일 포맷팅
for file in *.json; do
  prettier --write "$file"
done

# Git 커밋 및 푸시
git add *.json
git commit -m "Update : Observer ABI files"
git push origin main

# Keystore ABI 업데이트
cd $KEYSTORE_ABI_DIR
echo "Keystore ABI 업데이트 중..."

# Prettier로 각 JSON 파일 포맷팅
for file in *.json; do
  prettier --write "$file"
done

# Git 커밋 및 푸시
git add *.json
git commit -m "Update : Keystore ABI files"
git push origin main

echo "ABI 업데이트가 완료되었습니다."
echo "Observer ABI 위치: $OBSERVER_ABI_DIR"
echo "Keystore ABI 위치: $KEYSTORE_ABI_DIR"
