# EvmoSwap Protocol

1. ⚠️ ⚠️ ⚠️ Execute distribution must use `function checkpointToken()`, don't use `function distribute(address _coin)`;
1. If you want to use `function distribute(address _coin)`, you need to approve the FeeDistributor.sol. But I don't suggest you use this method. It's dangerous!
