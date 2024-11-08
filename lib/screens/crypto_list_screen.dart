import 'dart:convert';
import 'package:crypto_rates/Auth/login_screen.dart';
import 'package:crypto_rates/models/user_model.dart';
import 'package:crypto_rates/screens/crypto_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/api_key_manager.dart';
import '../models/coin_model.dart';
import '../models/rates_api_service.dart';
import 'coin_details_screen.dart';

class CryptoListScreen extends StatefulWidget {
  @override
  _CryptoListScreenState createState() => _CryptoListScreenState();
}

class _CryptoListScreenState extends State<CryptoListScreen> {
  List<Coin> coins = [];
  bool isLoading = true;
  final String timestampKey = 'coins_timestamp';
  final String coinsKey = 'cached_coins';
  final String cacheKey = 'cache_key';

  @override
  void initState() {
    super.initState();
    initializeCache();
  }


  Future<void> initializeCache() async {
    await loadCachedData();
  }

  Future<void> loadCachedData({bool ignoreTimestamp = false}) async {
    final cachedData = prefs.getString(coinsKey);
    final cachedTimestamp = prefs.getInt(timestampKey);

    if (cachedData != null && (ignoreTimestamp || cachedTimestamp != null)) {
      if (ignoreTimestamp ||
          DateTime.now().millisecondsSinceEpoch - cachedTimestamp! < cacheValidDuration.inMilliseconds) {
        setState(() {
          coins = (json.decode(cachedData) as List)
              .map((coinJson) => Coin.fromCachedJson(coinJson))
              .toList();
          isLoading = false;
        });
        print('Got data from cache');
        return;
      }
    }

    try {
      await fetchCoins();
      print('Did not get data from cache - fetched new data');
    } catch (e) {
      print('Fetch failed, trying to load expired cache');
      if (cachedData != null) {
        await loadCachedData(ignoreTimestamp: true);
      } else {
        print('No cached data available');
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> fetchCoins() async {
    await ApiKeyManager.resetCountsIfMonthChanged();
    String currentApiKey = await ApiKeyManager.getCurrentKey();
    bool success = false;

    for (int i = 0; i < 4; i++) {
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

          await prefs.setString(coinsKey, json.encode(
              newCoins.map((coin) => coin.toJson()).toList()
          ));
          await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);

          await ApiKeyManager.incrementApiCalls();

          print('using $currentApiKey');

          setState(() {
            coins = newCoins;
            isLoading = false;
          });

          success = true;
          break;
        } else if (response.statusCode == 429) {
          currentApiKey = await ApiKeyManager.getNextViableKey();
          continue;
        } else {
          throw Exception('Failed to load coins: ${response.statusCode}');
        }
      } catch (e) {
        currentApiKey = await ApiKeyManager.getNextViableKey();
      }
    }

    if (!success) {
       print('All API keys exhausted');
    }
  }


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
    TextStyle style = TextStyle(color: Colors.white, fontSize: 17);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Cryptocurrency List'),
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: IconButton(
              icon: Icon(Icons.show_chart),
              onPressed: (){
                Navigator.of(context).push(MaterialPageRoute(builder: (context)
                 => CryptoChart()));
              }
            ),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.blueGrey.shade900,
        child: user == null?
        DrawerHeader(
            child: Center(
          child: GestureDetector(
              onTap: (){
                Navigator.of(context).push(MaterialPageRoute(builder: (context)
                => LoginScreen()));
              },
              child: Text('Sign In',
                style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white
              ),)),
        )) :
        FutureBuilder<UserModel>(
          future: getUserData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(
                child: Text('Error loading user data'),
              );
            }

            final userData = snapshot.data!;

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                UserAccountsDrawerHeader(
                  accountName: Text(userData.name, style: style,),
                  accountEmail: Text(userData.email, style: style,),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: Colors.blueGrey,
                    child: Text(
                      userData.name[0].toUpperCase(),
                      style: TextStyle(fontSize: 24, color: Colors.white),
                    ),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade900,
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.calendar_today, color: Colors.white,),
                  title: Text('Joined', style: style,),
                  subtitle: Text(
                    userData.createdAt != null
                        ? DateFormat('MMM d, yyyy').format(userData.createdAt!.toDate())
                        : 'Not available',
                        style: style,
                  ),
                ),
                Divider(),
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.white,),
                  title: Text('Sign Out', style: style,),
                  onTap: () async {
                    showDialog(context: context, builder: (context){
                       return AlertDialog(
                         title: Text('Are you sure you want to Log out?',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),),
                          actions: [
                            TextButton(
                                onPressed: (){
                              Navigator.pop(context);
                            }, child: Text('Cancel')),
                            TextButton(onPressed: () async {
                              await FirebaseAuth.instance.signOut();
                              Navigator.of(context).push(MaterialPageRoute(builder: (context)
                              => LoginScreen()));
                            }, child: Text('Yes'))
                          ],
                       );
                    });
                  },
                ),
              ],
            );
          },
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
            itemCount: coins.length,
            itemBuilder: (context, index) {
              final coin = coins[index];
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
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                subtitle: Text(
                  'Market Cap: ${formatMarketCap(coin.marketCap)}',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatPrice(coin.price),
                     style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),),
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
                      builder: (context) => CoinDetailScreen(coin: coin),
                    ),
                  );
                },
              );
            },
          ),
    );
  }
}