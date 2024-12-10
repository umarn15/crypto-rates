import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import axios from 'axios';

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

interface Alert {
  id: string;
  coinSymbol: string;
  targetPrice: number;
  condition: 'above' | 'below';
  isEnabled: boolean;
}

interface User {
  fcmToken?: string;
}

class ApiKeyManager {
  private static readonly apiKeys = [
    'coinranking2264141459929f24ef0a4a3d748c0b21c1c339fcf39d812e',
    'coinrankingc32b4b2d653cf963499c6689890169fa8d66ceff6cc50cdc',
    'coinrankingbb871484d985f3180feab40a152706b9e4330d958c0324e8',
    'coinranking70c5e375563a0f68486836e7ef54ca77dae7c87e965c562e',
    'coinranking3573e070f92647d4f50b30950ab8ef6de6deaec29dc50b2b',
    'coinrankingfdb5f14226dc1d8945d70d266c131fdff80f821bb005c790',
    'coinranking5e9d8ff32da67df00d25ed82839a60263fba2d8f877160fc',
    'coinranking9bde62eb8ec1e74b539bf169eeb265a8b9f8ab529c74b9a6',
    'coinranking1dd6e5b9cbc454a36295cff2f0710a5ee5f1e4b7b116fc58'
  ];

  private static currentKeyIndex = 0;

  private static getNextKey(): string {
    this.currentKeyIndex = (this.currentKeyIndex + 1) % this.apiKeys.length;
    console.log(`Switching to API key ${this.currentKeyIndex + 1}`);
    return this.apiKeys[this.currentKeyIndex];
  }

  static async fetchWithKeyRotation(symbols: string[]): Promise<Map<string, number>> {
    let attempts = 0;
    let lastError: Error | null = null;
    let currentKey = this.apiKeys[this.currentKeyIndex];

    while (attempts < this.apiKeys.length) {
      try {
        console.log(`Attempt ${attempts + 1} with key ${this.currentKeyIndex + 1}`);
        console.log(`Fetching prices for symbols:`, symbols);

        const response = await axios.get(
          `https://api.coinranking.com/v2/coins`,
          {
            headers: {
              'x-access-token': currentKey
            },
            params: {
              symbols: symbols.join(','),
              referenceCurrencyUuid: 'yhjMzLPhuIDl'
            }
          }
        );

        if (!response.data?.data?.coins || !Array.isArray(response.data.data.coins)) {
          throw new Error('Invalid API response structure');
        }

        const priceMap = new Map<string, number>();
        response.data.data.coins.forEach((coin: any) => {
          if (coin && coin.symbol && coin.price) {
            const price = parseFloat(coin.price);
            if (!isNaN(price) && price > 0) {
              priceMap.set(coin.symbol, price);
              console.log(`Parsed price for ${coin.symbol}: ${price}`);
            } else {
              console.error(`Invalid price format for ${coin.symbol}: ${price}`);
            }
          }
        });

        return priceMap;

      } catch (error: any) {
        lastError = error;
        console.error(`API key ${this.currentKeyIndex + 1} failed:`, error.message);

        if (error.response?.status === 429) {
          currentKey = this.getNextKey();
          attempts++;
          continue;
        }

        // For other errors, also try the next key
        currentKey = this.getNextKey();
        attempts++;
      }
    }

    console.error(`All API keys exhausted after ${attempts} attempts`);
    throw lastError || new Error('All API keys failed');
  }

  static async fetchBTCPrice(): Promise<number> {
    let attempts = 0;
    let currentKey = this.apiKeys[this.currentKeyIndex];

    while (attempts < this.apiKeys.length) {
      try {
        console.log(`BTC price attempt ${attempts + 1} with key ${this.currentKeyIndex + 1}`);

        const response = await axios.get(
          'https://api.coinranking.com/v2/coin/Qwsogvtv82FCd/price',
          {
            headers: {
              'x-access-token': currentKey
            }
          }
        );

        const price = parseFloat(response.data.data.price);
        if (!isNaN(price) && price > 0) {
          console.log(`BTC price fetched successfully: ${price}`);
          return price;
        }
        throw new Error('Invalid BTC price received');

      } catch (error) {
        console.error(`Failed to fetch BTC price with key ${this.currentKeyIndex + 1}:`, error);
        currentKey = this.getNextKey();
        attempts++;
      }
    }

    console.error(`Failed to fetch BTC price after ${attempts} attempts`);
    throw new Error('Failed to fetch BTC price with all keys');
  }
}


async function fetchCryptoPrices(symbols: string[]): Promise<Map<string, number>> {
  try {
    const priceMap = await ApiKeyManager.fetchWithKeyRotation(
      symbols.filter(s => s !== 'BTC')
    );

    if (symbols.includes('BTC')) {
      try {
        const btcPrice = await ApiKeyManager.fetchBTCPrice();
        priceMap.set('BTC', btcPrice);
        console.log('Added BTC price to price map:', btcPrice);
      } catch (error) {
        console.error('Failed to fetch BTC price:', error);
      }
    }

    return priceMap;
  } catch (error) {
    console.error('Error fetching crypto prices:', error);
    throw new Error('Failed to fetch crypto prices');
  }
}

async function sendPriceAlert(
  userId: string,
  alert: Alert,
  currentPrice: number,
  fcmToken: string
): Promise<void> {
  try {
    const message = {
      notification: {
        title: `${alert.coinSymbol} Price Alert`,
        body: `Price has gone ${alert.condition} $${alert.targetPrice.toFixed(2)} (Current: $${currentPrice.toFixed(2)})`,
      },
      data: {
        coinSymbol: alert.coinSymbol,
        targetPrice: alert.targetPrice.toString(),
        currentPrice: currentPrice.toString(),
        condition: alert.condition,
        alertId: alert.id,
      },
      token: fcmToken,
    };

    await messaging.send(message);
    console.log(`Alert sent for ${alert.coinSymbol} to user ${userId}`);
  } catch (error) {
    console.error('Error sending notification:', error);
    if ((error as any)?.errorInfo?.code === 'messaging/registration-token-not-registered') {
      await db.collection('Users').doc(userId).update({
        fcmToken: admin.firestore.FieldValue.delete()
      });
    }
    throw error;
  }
}

async function processAlert(
  userId: string,
  alert: Alert,
  currentPrice: number
): Promise<void> {
  try {
    if (isNaN(currentPrice) || currentPrice <= 0) {
      console.error(`Invalid price for ${alert.coinSymbol}: ${currentPrice}`);
      return;
    }

    if (isNaN(alert.targetPrice) || alert.targetPrice <= 0) {
      console.error(`Invalid target price for alert ${alert.id}: ${alert.targetPrice}`);
      return;
    }

    const shouldTrigger = alert.condition === 'above'
      ? currentPrice >= alert.targetPrice
      : currentPrice <= alert.targetPrice;

    console.log(`Processing alert for ${alert.coinSymbol}:
      Current price: ${currentPrice.toFixed(2)}
      Target: ${alert.targetPrice.toFixed(2)}
      Condition: ${alert.condition}
      Should trigger: ${shouldTrigger}
    `);

    if (shouldTrigger) {
      const userDoc = await db.collection('Users').doc(userId).get();
      const userData = userDoc.data() as User | undefined;

      if (!userData) {
        console.error(`No user data found for user ${userId}`);
        return;
      }

      if (userData.fcmToken) {
        try {
          await sendPriceAlert(userId, alert, currentPrice, userData.fcmToken);

          await db.collection('Users')
            .doc(userId)
            .collection('alertHistory')
            .add({
              alertId: alert.id,
              coinSymbol: alert.coinSymbol,
              targetPrice: alert.targetPrice,
              triggeredPrice: currentPrice,
              condition: alert.condition,
              triggeredAt: admin.firestore.FieldValue.serverTimestamp(),
              userId: userId,
              success: true,
            });

          await db.collection('Users')
            .doc(userId)
            .collection('alerts')
            .doc(alert.id)
            .update({
              isEnabled: false,
              triggeredAt: admin.firestore.FieldValue.serverTimestamp(),
              triggeredPrice: currentPrice,
              notificationSent: true,
              lastChecked: admin.firestore.FieldValue.serverTimestamp(),
            });

        } catch (error) {
          console.error(`Error sending notification for alert ${alert.id}:`, error);

          await db.collection('Users')
            .doc(userId)
            .collection('alertHistory')
            .add({
              alertId: alert.id,
              coinSymbol: alert.coinSymbol,
              targetPrice: alert.targetPrice,
              triggeredPrice: currentPrice,
              condition: alert.condition,
              triggeredAt: admin.firestore.FieldValue.serverTimestamp(),
              userId: userId,
              success: false,
              error: error.message,
            });

          throw error;
        }
      } else {
        console.log(`No FCM token found for user ${userId}`);
      }
    }
  } catch (error) {
    console.error(`Error processing alert ${alert.id} for user ${userId}:`, error);
    throw error;
  }
}

export const checkPriceAlerts = functions.pubsub
  .schedule('every 2 minutes')
  .onRun(async (context) => {
    try {
      const usersSnapshot = await db.collection('Users').get();

      for (const userDoc of usersSnapshot.docs) {
        const userId = userDoc.id;

        try {
          const alertsSnapshot = await db.collection('Users')
            .doc(userId)
            .collection('alerts')
            .where('isEnabled', '==', true)
            .get();

          if (alertsSnapshot.empty) continue;

          const symbolGroups = new Map<string, Alert[]>();
          alertsSnapshot.docs.forEach(doc => {
            const alert = { id: doc.id, ...doc.data() } as Alert;
            const alerts = symbolGroups.get(alert.coinSymbol) || [];
            alerts.push(alert);
            symbolGroups.set(alert.coinSymbol, alerts);
          });

          const uniqueSymbols = Array.from(symbolGroups.keys());
          const prices = await fetchCryptoPrices(uniqueSymbols);

          const promises = Array.from(symbolGroups.entries()).map(
            async ([symbol, alerts]) => {
              const currentPrice = prices.get(symbol);
              if (currentPrice === undefined || currentPrice <= 0) {
                console.error(`Invalid price found for symbol ${symbol}: ${currentPrice}`);
                return Promise.all([]);
              }

              return Promise.all(
                alerts.map(alert => processAlert(userId, alert, currentPrice))
              );
            }
          );

          await Promise.all(promises);

        } catch (error) {
          console.error(`Error processing alerts for user ${userId}:`, error);
          continue;
        }
      }

      console.log('Successfully processed alerts for all users');

    } catch (error) {
      console.error('Error in checkPriceAlerts:', error);
      throw error;
    }
  });


  interface ForexAlert {
    id: string;
    pairSymbol: string;
    baseCurrency: string;
    quoteCurrency: string;
    targetPrice: number;
    condition: 'above' | 'below';
    isEnabled: boolean;
  }

  interface User {
    fcmToken?: string;
  }

  class ForexApiManager {
    private static readonly API_KEY = 'HxgjgDgzW7FJasIp8bK7yprHBhnBqynr';
    private static readonly BASE_URL = 'https://api.polygon.io/v2';

    static async fetchForexPrices(pairs: string[]): Promise<Map<string, number>> {
      try {
        const priceMap = new Map<string, number>();

        // Fetch prices for each pair
        for (const pair of pairs) {
          try {
            const response = await axios.get(
              `${this.BASE_URL}/aggs/ticker/C:${pair}/prev`,
              {
                params: {
                  apiKey: this.API_KEY
                }
              }
            );

            if (response.data?.results?.[0]?.c) {
              const price = response.data.results[0].c;
              priceMap.set(pair, price);
              console.log(`Fetched price for ${pair}: ${price}`);
            }
          } catch (error) {
            console.error(`Error fetching price for ${pair}:`, error);
          }
        }

        return priceMap;
      } catch (error) {
        console.error('Error fetching forex prices:', error);
        throw error;
      }
    }
  }

  async function sendForexAlert(
    userId: string,
    alert: ForexAlert,
    currentPrice: number,
    fcmToken: string
  ): Promise<void> {
    try {
      const message = {
        notification: {
          title: `${alert.pairSymbol} Price Alert`,
          body: `Price has gone ${alert.condition} ${alert.targetPrice.toFixed(4)} (Current: ${currentPrice.toFixed(4)})`,
        },
        data: {
          pairSymbol: alert.pairSymbol,
          targetPrice: alert.targetPrice.toString(),
          currentPrice: currentPrice.toString(),
          condition: alert.condition,
          alertId: alert.id,
          type: 'forex'
        },
        token: fcmToken,
      };

      await messaging.send(message);
      console.log(`Forex alert sent for ${alert.pairSymbol} to user ${userId}`);
    } catch (error) {
      console.error('Error sending forex notification:', error);
      if ((error as any)?.errorInfo?.code === 'messaging/registration-token-not-registered') {
        await db.collection('Users').doc(userId).update({
          fcmToken: admin.firestore.FieldValue.delete()
        });
      }
      throw error;
    }
  }

  async function processForexAlert(
    userId: string,
    alert: ForexAlert,
    currentPrice: number
  ): Promise<void> {
    try {
      if (isNaN(currentPrice) || currentPrice <= 0) {
        console.error(`Invalid price for ${alert.pairSymbol}: ${currentPrice}`);
        return;
      }

      if (isNaN(alert.targetPrice) || alert.targetPrice <= 0) {
        console.error(`Invalid target price for forex alert ${alert.id}: ${alert.targetPrice}`);
        return;
      }

      const shouldTrigger = alert.condition === 'above'
        ? currentPrice >= alert.targetPrice
        : currentPrice <= alert.targetPrice;

      console.log(`Processing forex alert for ${alert.pairSymbol}:
        Current price: ${currentPrice.toFixed(4)}
        Target: ${alert.targetPrice.toFixed(4)}
        Condition: ${alert.condition}
        Should trigger: ${shouldTrigger}
      `);

      if (shouldTrigger) {
        const userDoc = await db.collection('Users').doc(userId).get();
        const userData = userDoc.data() as User | undefined;

        if (!userData?.fcmToken) {
          console.log(`No FCM token found for user ${userId}`);
          return;
        }

        try {
          await sendForexAlert(userId, alert, currentPrice, userData.fcmToken);

          // Record alert history
          await db.collection('Users')
            .doc(userId)
            .collection('forexAlertHistory')
            .add({
              alertId: alert.id,
              pairSymbol: alert.pairSymbol,
              targetPrice: alert.targetPrice,
              triggeredPrice: currentPrice,
              condition: alert.condition,
              triggeredAt: admin.firestore.FieldValue.serverTimestamp(),
              userId: userId,
              success: true,
            });

          // Update alert status
          await db.collection('Users')
            .doc(userId)
            .collection('forex_alerts')
            .doc(alert.id)
            .update({
              isEnabled: false,
              triggeredAt: admin.firestore.FieldValue.serverTimestamp(),
              triggeredPrice: currentPrice,
              notificationSent: true,
              lastChecked: admin.firestore.FieldValue.serverTimestamp(),
            });

        } catch (error) {
          console.error(`Error processing forex alert ${alert.id}:`, error);

          await db.collection('Users')
            .doc(userId)
            .collection('forexAlertHistory')
            .add({
              alertId: alert.id,
              pairSymbol: alert.pairSymbol,
              targetPrice: alert.targetPrice,
              triggeredPrice: currentPrice,
              condition: alert.condition,
              triggeredAt: admin.firestore.FieldValue.serverTimestamp(),
              userId: userId,
              success: false,
              error: error.message,
            });

          throw error;
        }
      }
    } catch (error) {
      console.error(`Error processing forex alert ${alert.id}:`, error);
      throw error;
    }
  }

  export const checkForexAlerts = functions.pubsub
    .schedule('every 2 minutes')
    .onRun(async (context) => {
      try {
        const usersSnapshot = await db.collection('Users').get();

        for (const userDoc of usersSnapshot.docs) {
          const userId = userDoc.id;

          try {
            const alertsSnapshot = await db.collection('Users')
              .doc(userId)
              .collection('forex_alerts')
              .where('isEnabled', '==', true)
              .get();

            if (alertsSnapshot.empty) continue;

            const pairGroups = new Map<string, ForexAlert[]>();
            alertsSnapshot.docs.forEach(doc => {
              const alert = { id: doc.id, ...doc.data() } as ForexAlert;
              const alerts = pairGroups.get(alert.pairSymbol) || [];
              alerts.push(alert);
              pairGroups.set(alert.pairSymbol, alerts);
            });

            const uniquePairs = Array.from(pairGroups.keys());
            const prices = await ForexApiManager.fetchForexPrices(uniquePairs);

            const promises = Array.from(pairGroups.entries()).map(
              async ([pair, alerts]) => {
                const currentPrice = prices.get(pair);
                if (currentPrice === undefined || currentPrice <= 0) {
                  console.error(`Invalid price found for pair ${pair}: ${currentPrice}`);
                  return Promise.all([]);
                }

                return Promise.all(
                  alerts.map(alert => processForexAlert(userId, alert, currentPrice))
                );
              }
            );

            await Promise.all(promises);

          } catch (error) {
            console.error(`Error processing forex alerts for user ${userId}:`, error);
            continue;
          }
        }

        console.log('Successfully processed forex alerts for all users');

      } catch (error) {
        console.error('Error in checkForexAlerts:', error);
        throw error;
      }
    });
