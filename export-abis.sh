#!/bin/bash
# How to use?
# chmod +x export-abis.sh
# ./export-abis.sh

# Set output directory
OUTPUT_DIR="src/abis"

# Create output directory if it doesn't exist
mkdir -p $OUTPUT_DIR

# Define interface list
INTERFACES=(
    "IBondingCurve"
    "IBondingCurveFactory"
    "ICore"
    "IToken"
    "ILock"
    "IWNative"
    "IFeeVault"
    "IDexRouter"
)

UNISWAP_INTERFACES=(
    "IUniswapV2Router"
    "IUniswapV2Factory"
    "IUniswapV2Pair"
)

# Extract ABI for each interface
for interface in "${INTERFACES[@]}"
do
    echo "Exporting ABI for $interface..."
    forge inspect $interface abi > "$OUTPUT_DIR/${interface}.json"
done

for interface in "${UNISWAP_INTERFACES[@]}"
do
    echo "Exporting ABI for $interface..."
    forge inspect $interface abi > "$OUTPUT_DIR/${interface}.json"
done

echo "ABI extraction completed."
echo "Output location: $OUTPUT_DIR"
