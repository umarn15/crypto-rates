import 'dart:convert';

import 'package:crypto_rates/screens/crypto_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
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
  final String coinsKey = 'cached_coins';
  final String timestampKey = 'coins_timestamp';

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
    try {
      final url = Uri.parse('https://api.coinranking.com/v2/coins?limit=20');
      final response = await http.get(
        url,
        headers: {
          'x-access-token': apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final coinsData = data['data']['coins'] as List;

        final newCoins = coinsData.map((coin) => Coin.fromJson(coin)).toList();

        // Cache the data
        await prefs.setString(coinsKey, json.encode(
            newCoins.map((coin) => coin.toJson()).toList()
        ));
        await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);

        setState(() {
          coins = newCoins;
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load coins');
      }
    } catch (e) {
      print('Error fetching coins: $e');
      rethrow;
    }
  }

  Future<void> refreshData() async {
    final cachedTimestamp = prefs.getInt(timestampKey);
    if (cachedTimestamp != null) {
      final cacheAge = DateTime.now().millisecondsSinceEpoch - cachedTimestamp;
      if (cacheAge < cacheValidDuration.inMilliseconds) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Using cached data. Next update available in ${((cacheValidDuration.inMilliseconds - cacheAge) / 1000 / 60).toStringAsFixed(0)} minutes'
            ),
          ),
        );
        return;
      }
    }
    await fetchCoins();
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Cryptocurrency List'),
        actions: [
          IconButton(
            icon: Icon(Icons.show_chart),
            onPressed: (){
              Navigator.of(context).push(MaterialPageRoute(builder: (context)
               => CryptoChart()));
            }
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: IconButton(
                icon: Icon(Icons.refresh),
                onPressed: refreshData
            ),
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: fetchCoins,
        child: ListView.builder(
          itemCount: coins.length,
          itemBuilder: (context, index) {
            final coin = coins[index];
            return ListTile(
              leading: Text(
                '#${coin.rank}',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              title: Text(
                '${coin.name} (${coin.symbol})',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Market Cap: ${formatMarketCap(coin.marketCap)}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatPrice(coin.price),
                    style: TextStyle(fontWeight: FontWeight.bold),
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
                    builder: (context) => CoinDetailScreen(coin: coin),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
