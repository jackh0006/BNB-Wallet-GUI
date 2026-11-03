const { ethers } = require('ethers');

console.log('=== INDEPENDENT EIP-1559 VERIFICATION USING ETHERS.JS ===\n');

// Known test vector: Anvil test key
const PRIVATE_KEY = '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
const EXPECTED_ADDRESS = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';
const CHAIN_ID = 56; // BSC Mainnet

// Transaction parameters (matching the cold wallet test)
const NONCE = 0;
const MAX_PRIORITY_FEE_PER_GAS = BigInt(0x3b9aca00); // 1 gwei
const MAX_FEE_PER_GAS = BigInt(0x3b9aca00); // 1 gwei
const GAS_LIMIT = 21000;
const TO = '0x70997970C51812dc3A010C7d01b50e0d17dc79C8';
const VALUE = BigInt('0xde0b6b3a7640000'); // 1 ETH in wei
const DATA = '0x';

console.log('=== TRANSACTION PARAMETERS ===');
console.log('Private key:', PRIVATE_KEY);
console.log('Expected address:', EXPECTED_ADDRESS);
console.log('Chain ID:', CHAIN_ID);
console.log('Nonce:', NONCE);
console.log('Max priority fee per gas:', MAX_PRIORITY_FEE_PER_GAS.toString());
console.log('Max fee per gas:', MAX_FEE_PER_GAS.toString());
console.log('Gas limit:', GAS_LIMIT);
console.log('To:', TO);
console.log('Value:', VALUE.toString());
console.log('Data:', DATA);

// Create wallet
const wallet = new ethers.Wallet(PRIVATE_KEY);
console.log('\nWallet address:', wallet.address);
console.log('Matches expected:', wallet.address.toLowerCase() === EXPECTED_ADDRESS.toLowerCase());

// Build EIP-1559 transaction
const tx = {
  type: 2, // EIP-1559
  chainId: CHAIN_ID,
  nonce: NONCE,
  maxPriorityFeePerGas: MAX_PRIORITY_FEE_PER_GAS,
  maxFeePerGas: MAX_FEE_PER_GAS,
  gasLimit: GAS_LIMIT,
  to: TO,
  value: VALUE,
  data: DATA,
  accessList: []
};

console.log('\n=== ETHERS.JS TRANSACTION ===');
console.log('Transaction:', JSON.stringify(tx, (key, value) => 
  typeof value === 'bigint' ? value.toString() : value, 2));

// Sign transaction
async function signAndVerify() {
  const signedTx = await wallet.signTransaction(tx);
  console.log('\n=== SIGNED TRANSACTION (ETHERS) ===');
  console.log('Signed TX:', signedTx);
  
  // Parse signed transaction
  const parsed = ethers.Transaction.from(signedTx);
  console.log('\n=== PARSED SIGNED TRANSACTION ===');
  console.log('Type:', parsed.type);
  console.log('Chain ID:', parsed.chainId);
  console.log('Nonce:', parsed.nonce);
  console.log('Max Priority Fee Per Gas:', parsed.maxPriorityFeePerGas.toString());
  console.log('Max Fee Per Gas:', parsed.maxFeePerGas.toString());
  console.log('Gas Limit:', parsed.gasLimit.toString());
  console.log('To:', parsed.to);
  console.log('Value:', parsed.value.toString());
  console.log('Data:', parsed.data);
  console.log('Hash:', parsed.hash);
  
  // Get signature from the transaction
  const signature = parsed.signature;
  console.log('\n=== SIGNATURE ===');
  console.log('R:', signature.r);
  console.log('S:', signature.s);
  console.log('V:', signature.v);
  console.log('R (hex):', signature.r);
  console.log('S (hex):', signature.s);
  console.log('V (recovery ID):', signature.v);
  
  // Test recovery with the signing hash
  console.log('\n=== TESTING RECOVERY WITH SIGNING HASH ===');
  const messageHash = ethers.keccak256(ethers.getBytes(parsed.hash));
  console.log('Message hash:', messageHash);
  
  for (let v = 27; v <= 30; v++) {
    try {
      const recovered = ethers.verifyMessage(
        ethers.getBytes(parsed.hash),
        {
          r: signature.r,
          s: signature.s,
          v: v
        }
      );
      console.log(`V=${v}: ${recovered} ${recovered.toLowerCase() === EXPECTED_ADDRESS.toLowerCase() ? 'MATCH' : 'MISMATCH'}`);
    } catch (e) {
      console.log(`V=${v}: ERROR - ${e.message}`);
    }
  }
  
  // Cross-verify with Dart implementation
  console.log('\n=== CROSS-VERIFICATION: VERIFY DART SIGNATURE WITH ETHERS ===');
  const dartR = '90209847862045162569176841688939339112064910074981815885602146389777244538816';
  const dartS = '19154717284887472570230944981640205899053616800334249059923204829009173383162';
  const dartV = 1; // recovery ID
  
  // Recreate the signing hash from Dart's payload
  const dartTxPayload = '0x02f53880843b9aca00843b9aca00825208da708199797081c5181281dc3a010c7d0181b50e0d1781dc7981c8880de0b6b3a7640000c0c0';
  const dartSigningHash = ethers.keccak256(dartTxPayload);
  console.log('Dart signing hash:', dartSigningHash);
  
  const crossVerify = ethers.verifyMessage(
    ethers.getBytes(dartSigningHash),
    {
      r: '0x' + BigInt(dartR).toString(16).padStart(64, '0'),
      s: '0x' + BigInt(dartS).toString(16).padStart(64, '0'),
      v: 27 + 1 // v + 27
    }
  );
  console.log('Cross-verify recovered address:', crossVerify);
  console.log('Matches expected:', crossVerify.toLowerCase() === EXPECTED_ADDRESS.toLowerCase());
  
  // Now test the full signed transaction from Dart
  console.log('\n=== FULL SIGNED TRANSACTION VERIFICATION ===');
  // The Dart raw TX is: 0x02 + RLP([chainId, nonce, maxPriorityFeePerGas, maxFeePerGas, gasLimit, to, value, data, accessList, yParity, r, s])
  const dartRawTx = '0x02f53880843b9aca00843b9aca00825208da708199797081c5181281dc3a010c7d0181b50e0d1781dc7981c8880de0b6b3a7640000c0c001c770f6e96cbc0dc08a0b662e35287dd1f545dca8aae466c7a1c3116766b0c7c01b21a55432ede22dcb0900c407df3567c3b1b73db86d30aadb19093d4b18c0214b061a30dce23e63f89d4b18c0214b06';
  const parsedDartTx = ethers.Transaction.from(dartRawTx);
  console.log('Parsed Dart TX hash:', parsedDartTx.hash);
  console.log('Parsed Dart TX r:', parsedDartTx.signature.r);
  console.log('Parsed Dart TX s:', parsedDartTx.signature.s);
  console.log('Parsed Dart TX v:', parsedDartTx.signature.v);
  console.log('Parsed Dart TX type:', parsedDartTx.type);
  console.log('Parsed Dart TX chainId:', parsedDartTx.chainId);
  
  // Test with the full signed transaction from Dart
  console.log('\n=== CROSS-VERIFICATION: PARSE DART SIGNED TX WITH ETHERS ===');
  const parsedDartSig = parsedDartTx.signature;
  console.log('Dart signature r:', parsedDartSig.r);
  console.log('Dart signature s:', parsedDartSig.s);
  console.log('Dart signature v:', parsedDartSig.v);
  
  // Test recovery with the full signed transaction
  const dartTxHash = parsedDartTx.hash;
  console.log('Dart TX hash:', dartTxHash);
  
  for (let v = 27; v <= 30; v++) {
    try {
      const recovered = ethers.verifyMessage(
        ethers.getBytes(dartTxHash),
        {
          r: parsedDartSig.r,
          s: parsedDartSig.s,
          v: v
        }
      );
      console.log(`Dart TX V=${v}: ${recovered} ${recovered.toLowerCase() === EXPECTED_ADDRESS.toLowerCase() ? 'MATCH' : 'MISMATCH'}`);
    } catch (e) {
      console.log(`Dart TX V=${v}: ERROR - ${e.message}`);
    }
  }
  
  return {
    success: true,
    ethersSignature: { r: signature.r, s: signature.s, v: signature.v },
    dartSignature: { r: dartR, s: dartS, v: 1 }
  };
}

signAndVerify().then(result => {
  console.log('\n=== FINAL RESULT ===');
  console.log('Independent verification:', result.match ? 'PASSED' : 'FAILED');
  process.exit(result.match ? 0 : 1);
}).catch(e => {
  console.error('ERROR:', e);
  process.exit(1);
});
