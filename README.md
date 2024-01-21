# GHO Peg Stability and Cross Chain Facilitator    

GHOCC is a GHO Facilitator that is pegged to USDC on Mainnet (Sepolia for the demo), and that also functions as a cross-chain facilitator using Chainlink CCIP.   


The following capabilities are available in the GHOCC smart contracts:    
1. paying USDC and receiving an equivalent amount of GHO in return    
2. redeeming the GHO for USDC    
3. transferring the GHO cross-chain using Chainlink CCIP   
4. transferring the GHO back to the source chain (Mainnet or Sepolia)    

A fee is charged for swapping USDC for GHO, and for sending GHO cross-chain. The fees are distributable only to the Aave Treasury.    

Addresses:    
Sepolia demo USDC: 0xd702baC2f43eB7B9aAD73b965210b241d873154C    
Sepolia demo GHO: 0x57F324D62E8fCfCD64c3dc254a04f7a84363F9ef    
Sepolia Facilitator: 0x6eF0D6F8714C570eBc575B39137662bfD8a913CA    
Mumbai Receiver: 0x16ffa647315b5c83234c1e3ff0814cf9ea3a7ef9    
Mumbai demo GHO: 0xa08690e2d701306A230C3A87551F5542d6c0B988    