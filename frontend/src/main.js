import { initBlockchainConnection, isContractConfigured } from './modules/contract.js';
import { isMetaMaskAvailable, connectWallet, getBrowserProvider, setupWalletListeners } from './modules/wallet.js';
import { initDashboard, refreshDashboardStats } from './modules/dashboard.js';
import { initHistory, refreshEventHistory } from './modules/history.js';

document.addEventListener('DOMContentLoaded', () => {
  const connectButton = document.getElementById('connect-wallet-btn');
  const networkBadge = document.getElementById('network-badge');
  const walletAddress = document.getElementById('wallet-address');
  const dashboardButton = document.getElementById('refresh-dashboard-btn');
  const historyButton = document.getElementById('refresh-history-btn');

  initDashboard(document.getElementById('dashboard-content'));
  initHistory(document.getElementById('history-content'));

  function showWallet(account, chainId) {
    if (!account) {
      networkBadge.textContent = isMetaMaskAvailable() ? 'Wallet not connected' : 'MetaMask not detected';
      networkBadge.className = 'badge badge-disconnected';
      walletAddress.classList.add('hidden');
      walletAddress.textContent = '';
      connectButton.disabled = false;
      connectButton.textContent = 'Connect MetaMask';
      return;
    }
    networkBadge.textContent = `Connected · Chain ${chainId}`;
    networkBadge.className = 'badge badge-connected';
    walletAddress.textContent = `${account.slice(0, 6)}…${account.slice(-4)}`;
    walletAddress.classList.remove('hidden');
    connectButton.textContent = 'Wallet Connected';
  }

  async function loadChainData() {
    const result = await initBlockchainConnection(getBrowserProvider());
    if (result.connected) {
      await Promise.all([refreshDashboardStats(), refreshEventHistory()]);
    } else if (isContractConfigured()) {
      const status = document.getElementById('dashboard-status');
      if (status) status.textContent = result.reason || 'Blockchain connection unavailable.';
    }
  }

  connectButton.addEventListener('click', async () => {
    connectButton.disabled = true;
    try {
      const wallet = await connectWallet();
      showWallet(wallet.account, wallet.chainId);
      await loadChainData();
    } catch (error) {
      networkBadge.textContent = error.message || 'Wallet connection failed';
      networkBadge.className = 'badge badge-disconnected';
    } finally {
      connectButton.disabled = false;
    }
  });

  dashboardButton.addEventListener('click', refreshDashboardStats);
  historyButton.addEventListener('click', refreshEventHistory);

  setupWalletListeners({
    onAccountsChanged: account => {
      if (!account) {
        showWallet(null, null);
        return;
      }
      showWallet(account, Number(window.ethereum.chainId || '0x0'));
      loadChainData().catch(console.error);
    },
    onChainChanged: chainId => {
      showWallet(null, null);
      networkBadge.textContent = `Network changed · Chain ${chainId}`;
      loadChainData().catch(error => {
        networkBadge.textContent = error.message;
      });
    }
  });

  if (!isMetaMaskAvailable()) showWallet(null, null);
});
