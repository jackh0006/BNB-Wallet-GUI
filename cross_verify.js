const { ethers } = require('ethers');

console.log('=== CROSS-VERIFICATION: DART SIGNED TX WITH ETHERS ===\n');

// The Dart signed transaction from our test output
const dartRawTx = '0x02f53880843b9aca00843b9aca00825208da708199797081c5181281dc3a010c7d0181b50e0d1781dc7981c8880de0b6b3a7640000c0c001c770f6e96cbc0dc08a0b662e35287dd1f545dca8aae466c7a1c3116766b0c7c01b21a55432ede22dcb0900c407df3567c3b1b73db86d30aadb19093d4b18c0214b061a30dce23e63f89d4b18c0214b06';

console.log('Dart raw TX:', dartRawTx);

// Try to parse with ethers
try {
  const parsedDartTx = ethers.Transaction.from(dartRawTx);
  console.log('\n=== PARSED DART TX WITH ETHERS ===');
  console.log('Hash:', parsedDartTx.hash);
  console.log('Type:', parsedDartTx.type);
  console.log('Chain ID:', parsedDartTx.chainId);
  console.log('Nonce:', parsedDartTx.nonce);
  console.log('To:', parsedDartTx.to);
  console.log('Value:', parsedDartTx.value.toString());
  console.log('Gas Limit:', parsedDartTx.gasLimit.toString());
  console.log('Max Fee Per Gas:', parsedDartTx.maxFeePerGas.toString());
  console.log('Max Priority Fee Per Gas:', parsedDartTx.maxPriorityFeePerGas.toString());
  console.log('R:', parsedDartTx.signature.r);
  console.log('S:', parsedDartTx.signature.s);
  console.log('V:', parsedDartTx.signature.v);
  
  // Try to verify the signature
  const parsedDartSig = parsedDartTx.signature;
  console.log('\n=== SIGNATURE RECOVERY ===');
  for (let v = 27; v <= 30; v++) {
    try {
      const recovered = ethers.verifyMessage(
        ethers.getBytes(parsedDartTx.hash),
        {
          r: parsedDartTx.signature.r,
          s: parsedDartTx.signature.s,
          v: v
        }
      );
      console.log(`V=${v}: ${recovered} ${recovered.toLowerCase() === '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266' ? 'MATCH' : 'MISMATCH'}`);
    } catch (e) {
      console.log(`V=${v}: ERROR - ${e.message}`);
    }
  }
  
  // Also try with the signing hash
  console.log('\n=== WITH SIGNING HASH ===');
  const messageHash = parsedDartTx.hash;
  for (let v = 27; v <= 30; v++) {
    try {
      const recovered = ethers.verifyMessage(
        ethers.getBytes(parsedDartTx.hash),
        {
          r: parsedDartTx.signature.r,
          s: parsedDartTx.signature.s,
          v: v
        }
      );
      console.log(`V=${v}: ${recovered} ${recovered.toLowerCase() === '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266' ? 'MATCH' : 'MISMATCH'}`);
    } catch (e) {
      console.log(`V=${v}: ERROR - ${e.message}`);
    }
  }
  
} catch (e) {
  console.error('ERROR parsing Dart TX:', e.message);
  console.error(e.stack);
}

console.log('\n=== NOW TEST ETHERS SIGNED TX RECOVERY ===');
// Now test with ethers' own signed transaction
const ethersRawTx = '0x02f8723880843b9aca00843b9aca008252089470997970c51812dc3a010c7d01b50e0d17dc79c8880de0b6b3a764000080c001a09e14c0496472a3ea4af35ece19224ff815dfd656a568524a84130c722b959afda0393349471326e2196f8d11c49649f17df740476d4f5d6447f8dfa20bd0d66a4b';

try {
  const parsedEthersTx = ethers.Transaction.from(ethersRawTx);
  console.log('\n=== PARSED ETHERS TX ===');
  console.log('Hash:', parsedEthersTx.hash);
  console.log('R:', parsedEthersTx.signature.r);
  console.log('S:', parsedEthersTx.signature.s);
  console.log('V:', parsedEthersTx.signature.v);
  
  for (let v = 27; v <= 30; v++) {
    try {
      const recovered = ethers.verifyMessage(
        ethers.getBytes(parsedEthersTx.hash),
        {
          r: parsedEthersTx.signature.r,
          s: parsedEthersTx.signature.s,
          v: v
        }
      );
      console.log(`V=${v}: ${recovered} ${recovered.toLowerCase() === '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266' ? 'MATCH' : 'MISMATCH'}`);
    } catch (e) {
      console.log(`V=${v}: ERROR - ${e.message}`);
    }
  }
} catch (e) {
  console.error('ERROR:', e.message);
}
