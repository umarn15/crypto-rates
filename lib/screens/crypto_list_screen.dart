import 'dart:async';
import 'dart:convert';
import 'package:crypto_rates/Auth/login_screen.dart';
import 'package:crypto_rates/models/user_model.dart';
import 'package:crypto_rates/screens/saved_alerts_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/coin_model.dart';
import '../services/binance_service.dart';
import 'coin_details_screen.dart';

class CryptoListScreen extends StatefulWidget {
  const CryptoListScreen({Key? key}) : super(key: key);

  @override
  _CryptoListScreenState createState() => _CryptoListScreenState();
}

class _CryptoListScreenState extends State<CryptoListScreen> {
  List<Coin> coins = [];
  List<Coin> filteredCoins = [];
  bool isLoading = true;
  WebSocketChannel? _channel;
  late final StreamController<List<Coin>> _coinsController;
  final DrawerContent _drawerContent = const DrawerContent();
  final TextEditingController _searchController = TextEditingController();
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    _coinsController = StreamController<List<Coin>>.broadcast();
    _searchController.addListener(_filterCoins);
    _initializeData();
  }

  void _filterCoins() {
    if (_searchController.text.isEmpty) {
      setState(() {
        filteredCoins = coins;
      });
      return;
    }

    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredCoins = coins.where((coin) {
        return coin.name.toLowerCase().contains(query) ||
            coin.symbol.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _initializeData() async {
    try {
      setState(() => isLoading = true);

      // Get initial data
      final initialCoins = await BinanceService.getInitialData();

      if (mounted) {
        setState(() {
          coins = initialCoins;
          filteredCoins = initialCoins;
          isLoading = false;
        });

        _coinsController.add(initialCoins);
        _updateWidget();

        // Setup WebSocket after getting initial data
        _setupWebSocket();
      }
    } catch (e) {
      print('Error initializing data: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _setupWebSocket() {
    try {
      _channel?.sink.close();

      _channel = WebSocketChannel.connect(
          Uri.parse('wss://stream.binance.com:9443/ws/!ticker@arr')
      );

      _channel!.stream.listen(
            (dynamic message) {
          try {
            final List<dynamic> tickers = jsonDecode(message);
            bool updatedAny = false;

            for (var ticker in tickers) {
              final symbol = ticker['s'].toString().replaceAll('USDT', '');
              final coinIndex = coins.indexWhere((coin) =>
              coin.symbol.toUpperCase() == symbol
              );

              if (coinIndex != -1) {
                final double newPrice = double.parse(ticker['c']);
                final double newChange = double.parse(ticker['P']);
                final double volume = double.parse(ticker['q']);
                final double marketCap = newPrice * volume;

                if (coins[coinIndex].price != newPrice ||
                    coins[coinIndex].change24h != newChange ||
                    coins[coinIndex].marketCap != marketCap) {
                  coins[coinIndex] = coins[coinIndex].copyWith(
                    price: newPrice,
                    change24h: newChange,
                    marketCap: marketCap,
                  );
                  updatedAny = true;
                }
              }
            }

            if (updatedAny && mounted) {
              // Sort again by market cap
              coins.sort((a, b) => b.marketCap.compareTo(a.marketCap));

              // Update ranks
              for (int i = 0; i < coins.length; i++) {
                coins[i] = coins[i].copyWith(rank: i + 1);
              }

              setState(() {
                _filterCoins(); // Re-apply search filter after updates
              });
              _coinsController.add(coins);
              _updateWidget();
            }
          } catch (e) {
            print('Error processing WebSocket message: $e');
          }
        },
        onError: (error) {
          print('WebSocket Error: $error');
          Future.delayed(Duration(seconds: 5), _setupWebSocket);
        },
        onDone: () {
          print('WebSocket connection closed');
          Future.delayed(Duration(seconds: 5), _setupWebSocket);
        },
      );
    } catch (e) {
      print('Error setting up WebSocket: $e');
      Future.delayed(Duration(seconds: 5), _setupWebSocket);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _channel?.sink.close();
    _coinsController.close();
    super.dispose();
  }

  void _updateWidget() {
    try {
      final widgetData = coins.take(3).map((coin) {
        return {
          'symbol': coin.symbol,
          'price': coin.price.toStringAsFixed(2),
          'change': coin.change24h.toStringAsFixed(2),
        };
      }).toList();

      HomeWidget.saveWidgetData<String>(
        'crypto_data',
        json.encode(widgetData),
      );

      HomeWidget.updateWidget(
        androidName: 'CryptoPriceWidget',
        iOSName: 'CryptoPriceWidget',
      );
    } catch (e) {
      print('Error updating widget: $e');
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

  PreferredSizeWidget _buildAppBar() {
    if (isSearching) {
      return AppBar(
        leading: BackButton(
          onPressed: () {
            setState(() {
              isSearching = false;
              _searchController.clear();
            });
          },
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search coins...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
        ),
      );
    }

    return AppBar(
      title: const Text('Cryptocurrency List'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            setState(() {
              isSearching = true;
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _initializeData,
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SavedAlerts()),
              );
            },
            icon: const Icon(Icons.favorite),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      drawer: _drawerContent,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: filteredCoins.length,
        itemBuilder: (context, index) {
          final coin = filteredCoins[index];
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
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
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