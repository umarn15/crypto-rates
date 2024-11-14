import 'dart:async';
import 'dart:convert';
import 'package:crypto_rates/Auth/login_screen.dart';
import 'package:crypto_rates/models/user_model.dart';
import 'package:crypto_rates/screens/saved_alerts_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/api_key_manager.dart';
import '../models/coin_model.dart';
import 'coin_details_screen.dart';

class CryptoListScreen extends StatefulWidget {
  const CryptoListScreen({Key? key}) : super(key: key);

  @override
  _CryptoListScreenState createState() => _CryptoListScreenState();
}

class _CryptoListScreenState extends State<CryptoListScreen> {
  List<Coin> coins = [];
  bool isLoading = true;
  Timer? _timer;
  late final StreamController<List<Coin>> _coinsController;
  final DrawerContent _drawerContent = const DrawerContent();

  @override
  void initState() {
    super.initState();
    _coinsController = StreamController<List<Coin>>.broadcast();
    _startRealtimeUpdates();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _coinsController.close();
    super.dispose();
  }

  void _startRealtimeUpdates() {
    fetchCoins();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      fetchCoins();
    });
  }

  Future<void> fetchCoins() async {
    await ApiKeyManager.resetCountsIfMonthChanged();
    String currentApiKey = await ApiKeyManager.getCurrentKey();
    bool success = false;
    List<String> _apiKeys = ApiKeyManager.apiKeys;

    for (int i = 0; i < _apiKeys.length; i++) {
      try {
        final url = Uri.parse('https://api.coinranking.com/v2/coins?limit=20');
        final response = await http.get(
          url,
          headers: {
            'x-access-token': currentApiKey,
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final coinsData = data['data']['coins'] as List;
          final newCoins = coinsData.map((coin) => Coin.fromJson(coin)).toList();

          await ApiKeyManager.incrementApiCalls();
          _coinsController.add(newCoins);

          // Prepare data for widget
          List<Map<String, dynamic>> widgetData = newCoins.take(3).map((coin) {
            return {
              'symbol': coin.symbol,
              'price': coin.price.toStringAsFixed(2),
              'change': coin.change24h.toStringAsFixed(2),
            };
          }).toList();

          await HomeWidget.saveWidgetData<String>(
            'crypto_data',
            json.encode(widgetData),
          );

          // Trigger widget update
          await HomeWidget.updateWidget(
            androidName: 'CryptoPriceWidget',
            iOSName: 'CryptoPriceWidget',
          );

          print('Widget data updated: ${json.encode(widgetData)}'); // Debug print

          if (mounted) {
            setState(() {
              coins = newCoins;
              isLoading = false;
            });
          }

          success = true;
          break;
        } else if (response.statusCode == 429) {
          currentApiKey = await ApiKeyManager.getNextViableKey();
          continue;
        } else {
          throw Exception('Failed to load coins: ${response.statusCode}');
        }
      } catch (e) {
        print('Error in fetchCoins: $e'); // Debug print
        currentApiKey = await ApiKeyManager.getNextViableKey();
      }
    }

    if (!success) {
      print('All API keys exhausted');
    }
  }

  // Future<void> fetchCoins() async {
  //   await ApiKeyManager.resetCountsIfMonthChanged();
  //   String currentApiKey = await ApiKeyManager.getCurrentKey();
  //   bool success = false;
  //   List<String> _apiKeys = ApiKeyManager.apiKeys;
  //
  //   for (int i = 0; i < _apiKeys.length; i++) {
  //     try {
  //       final url = Uri.parse('https://api.coinranking.com/v2/coins?limit=20');
  //       final response = await http.get(
  //         url,
  //         headers: {
  //           'x-access-token': currentApiKey,
  //         },
  //       );
  //
  //       if (response.statusCode == 200) {
  //         final data = jsonDecode(response.body);
  //         final coinsData = data['data']['coins'] as List;
  //         final newCoins = coinsData.map((coin) => Coin.fromJson(coin)).toList();
  //
  //         await ApiKeyManager.incrementApiCalls();
  //         _coinsController.add(newCoins);
  //
  //         if (mounted) {
  //           setState(() {
  //             coins = newCoins;
  //             isLoading = false;
  //           });
  //         }
  //
  //         success = true;
  //         break;
  //       } else if (response.statusCode == 429) {
  //         currentApiKey = await ApiKeyManager.getNextViableKey();
  //         continue;
  //       } else {
  //         throw Exception('Failed to load coins: ${response.statusCode}');
  //       }
  //     } catch (e) {
  //       currentApiKey = await ApiKeyManager.getNextViableKey();
  //     }
  //   }
  //
  //   if (!success) {
  //     print('All API keys exhausted');
  //   }
  // }

  String formatPrice(double price) {
    if (price >= 1000000) {
      return '\$${(price / 1000000).toStringAsFixed(2)}M';
    } else if (price >= 1000) {
      return '\$${(price / 1000).toStringAsFixed(2)}K';
    }
    return '\$${price.toStringAsFixed(2)}';
  }

  String formatMarketCap(double marketCap) {
    if (marketCap >= 1000000000000) {
      return '\$${(marketCap / 1000000000000).toStringAsFixed(2)}T';
    } else if (marketCap >= 1000000000) {
      return '\$${(marketCap / 1000000000).toStringAsFixed(2)}B';
    }
    return '\$${(marketCap / 1000000).toStringAsFixed(2)}M';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cryptocurrency List'),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: IconButton(onPressed: (){
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SavedAlerts()),
              );
            }, icon: Icon(Icons.favorite)),
          )
        ]
      ),
      drawer: _drawerContent,
      body: StreamBuilder<List<Coin>>(
        stream: _coinsController.stream,
        builder: (context, snapshot) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final currentCoins = snapshot.data ?? coins;

          return ListView.builder(
            itemCount: currentCoins.length,
            itemBuilder: (context, index) {
              final coin = currentCoins[index];
              return ListTile(
                leading: Text(
                  '#${coin.rank}',
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                title: Text(
                  '${coin.name} (${coin.symbol})',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                subtitle: Text(
                  'Market Cap: ${formatMarketCap(coin.marketCap)}',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatPrice(coin.price),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      '${coin.change24h >= 0 ? '+' : ''}${coin.change24h.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: coin.change24h >= 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CoinDetailScreen(initialCoin: coin),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class DrawerContent extends StatelessWidget {
  const DrawerContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    const TextStyle style = TextStyle(color: Colors.white, fontSize: 17);

    if (user == null) {
      return Drawer(
        backgroundColor: Colors.blueGrey.shade900,
        child: DrawerHeader(
          child: Center(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: const Text(
                'Sign In',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Drawer(
      backgroundColor: Colors.blueGrey.shade900,
      child: FutureBuilder<UserModel>(
        future: getUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Error loading user data'));
          }

          final userData = snapshot.data!;

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(userData.name, style: style),
                accountEmail: Text(userData.email, style: style),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.blueGrey,
                  child: Text(
                    userData.name[0].toUpperCase(),
                    style: const TextStyle(fontSize: 24, color: Colors.white),
                  ),
                ),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade900,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today, color: Colors.white),
                title: const Text('Joined', style: style),
                subtitle: Text(
                  userData.createdAt != null
                      ? DateFormat('MMM d, yyyy').format(userData.createdAt!.toDate())
                      : 'Not available',
                  style: style,
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.white),
                title: const Text('Sign Out', style: style),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text(
                          'Are you sure you want to Log out?',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () async {
                              await FirebaseAuth.instance.signOut();
                              if (context.mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                                      (route) => false,
                                );
                              }
                            },
                            child: const Text('Yes'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}