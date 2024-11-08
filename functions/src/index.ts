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
    'coinranking70c5e375563a0f68486836e7ef54ca77dae7c87e965c562e'
  ];

  private static currentKeyIndex = 0;

  static async fetchWithKeyRotation(symbols: string[]): Promise<Map<string, number>> {
    let lastError: Error | null = null;

    for (let i = 0; i < this.apiKeys.length; i++) {
      try {
        const response = await axios.get(
          `https://api.coinranking.com/v2/coins`, {
            headers: {
              'x-access-token': this.apiKeys[this.currentKeyIndex]
            },
            params: {
              symbols: symbols.join(',')
            }
          }
        );

        const priceMap = new Map<string, number>();
        const coins = response.data.data.coins;

        coins.forEach((coin: any) => {
          priceMap.set(coin.symbol, parseFloat(coin.price));
        });

        return priceMap;

      } catch (error: any) {
        lastError = error;
        console.log(`API key ${this.currentKeyIndex + 1} failed:`, error.message);

        if (error.response?.status === 429) {
          this.currentKeyIndex = (this.currentKeyIndex + 1) % this.apiKeys.length;
          continue;
        }

        throw error;
      }
    }

    throw lastError || new Error('All API keys failed');
  }
}

async function fetchCryptoPrices(symbols: string[]): Promise<Map<string, number>> {
  try {
    return await ApiKeyManager.fetchWithKeyRotation(symbols);
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
    const shouldTrigger = alert.condition === 'above'
      ? currentPrice >= alert.targetPrice
      : currentPrice <= alert.targetPrice;

    if (shouldTrigger) {
      const userDoc = await db.collection('Users').doc(userId).get();
      const userData = userDoc.data() as User | undefined;

      if (userData?.fcmToken) {
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
          });

        await db.collection('Users')
          .doc(userId)
          .collection('alerts')
          .doc(alert.id)
          .update({
            isEnabled: false,
            triggeredAt: admin.firestore.FieldValue.serverTimestamp(),
            triggeredPrice: currentPrice,
          });
      }
    }
  } catch (error) {
    console.error(`Error processing alert ${alert.id} for user ${userId}:`, error);
    throw error;
  }
}

export const checkPriceAlerts = functions.pubsub
  .schedule('every 20 minutes')
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
              if (currentPrice === undefined) {
                console.error(`No price found for symbol ${symbol}`);
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

// export const cleanupAlertHistory = functions.pubsub
//   .schedule('every 24 hours')
//   .onRun(async (context) => {
//     const thirtyDaysAgo = admin.firestore.Timestamp.fromDate(
//       new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
//     );
//
//     try {
//       const usersSnapshot = await db.collection('Users').get();
//
//       for (const userDoc of usersSnapshot.docs) {
//         const userId = userDoc.id;
//
//         const batch_size = 500;
//         let lastDoc = null;
//         let deletedCount = 0;
//
//         do {
//           let query = db.collection('Users')
//             .doc(userId)
//             .collection('alertHistory')
//             .where('triggeredAt', '<', thirtyDaysAgo)
//             .limit(batch_size);
//
//           if (lastDoc) {
//             query = query.startAfter(lastDoc);
//           }
//
//           const snapshot = await query.get();
//
//           if (snapshot.empty) break;
//
//           const batch = db.batch();
//           snapshot.docs.forEach(doc => {
//             batch.delete(doc.ref);
//           });
//
//           await batch.commit();
//           deletedCount += snapshot.size;
//           lastDoc = snapshot.docs[snapshot.docs.length - 1];
//
//           if (snapshot.size < batch_size) break;
//
//         } while (true);
//
//         console.log(`Cleaned up ${deletedCount} old alert history records for user ${userId}`);
//       }
//
//     } catch (error) {
//       console.error('Error in cleanupAlertHistory:', error);
//       throw error;
//     }
//   });