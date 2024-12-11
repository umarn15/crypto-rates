import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto_rates/Auth/login_screen.dart';
import 'package:crypto_rates/models/user_model.dart';
import 'package:crypto_rates/screens/forex_details_screen.dart';
import 'package:crypto_rates/screens/saved_alerts_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/coin_model.dart';
import '../models/forex_pair_model.dart';
import '../services/binance_service.dart';
import '../services/forex_service.dart';
import 'coin_details_screen.dart';

class CryptoListScreen extends StatefulWidget {
  const CryptoListScreen({Key? key}) : super(key: key);

  @override
  _CryptoListScreenState createState() => _CryptoListScreenState();
}

class _CryptoListScreenState extends State<CryptoListScreen> with SingleTickerProviderStateMixin {
  DateTime? _lastWidgetUpdate;
  static const Duration _minWidgetUpdateInterval = Duration(seconds: 30);
  late TabController _tabController;
  List<Coin> coins = [];
  List<Coin> filteredCoins = [];
  List<ForexPair> forexPairs = [];
  List<ForexPair> filteredForexPairs = [];
  bool isCryptoLoading = true;
  bool isForexLoading = true;
  WebSocketChannel? _cryptoChannel;
  WebSocketChannel? _forexChannel;
  late final StreamController<List<Coin>> _coinsController;
  final DrawerContent _drawerContent = const DrawerContent();
  final TextEditingController _searchController = TextEditingController();
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _coinsController = StreamController<List<Coin>>.broadcast();
    _searchController.addListener(_filterAssets);
    _initializeData();
  }

  void _filterAssets() {
    if (_searchController.text.isEmpty) {
      setState(() {
        filteredCoins = coins;
        filteredForexPairs = forexPairs;
      });
      return;
    }

    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredCoins = coins.where((coin) {
        return coin.name.toLowerCase().contains(query) ||
            coin.symbol.toLowerCase().contains(query);
      }).toList();

      filteredForexPairs = forexPairs.where((pair) {
        return pair.name.toLowerCase().contains(query) ||
            pair.symbol.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _initializeData() async {
    await Future.wait([
      _initializeCryptoData(),
      _initializeForexData(),
    ]);
  }

  Future<void> _initializeCryptoData() async {
    try {
      setState(() => isCryptoLoading = true);
      final initialCoins = await BinanceService.getInitialData();

      if (mounted) {
        setState(() {
          coins = initialCoins;
          filteredCoins = initialCoins;
          isCryptoLoading = false;
        });

        _coinsController.add(initialCoins);
        _updateWidget();
        _setupCryptoWebSocket();
      }
    } catch (e) {
      print('Error initializing crypto data: $e');
      if (mounted) {
        setState(() => isCryptoLoading = false);
      }
    }
  }

  Future<void> _initializeForexData() async {
    try {
      setState(() => isForexLoading = true);

      final initialForex = await ForexService.getInitialData();

      if (mounted) {
        setState(() {
          forexPairs = initialForex;
          filteredForexPairs = initialForex;
          isForexLoading = false;
        });

        _setupForexWebSocket();
      }
    } catch (e) {
      print('Error initializing forex data: $e');
      if (mounted) {
        setState(() => isForexLoading = false);
      }
    }
  }


  void _setupCryptoWebSocket() {
    try {
      _cryptoChannel?.sink.close();

      _cryptoChannel = WebSocketChannel.connect(
        Uri.parse('wss://stream.binance.com:9443/ws/!ticker@arr'),
      );

      _cryptoChannel!.stream.listen(
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
              coins.sort((a, b) => b.marketCap.compareTo(a.marketCap));
              for (int i = 0; i < coins.length; i++) {
                coins[i] = coins[i].copyWith(rank: i + 1);
              }

              setState(() {
                _filterAssets();
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
          Future.delayed(Duration(seconds: 5), _setupCryptoWebSocket);
        },
        onDone: () {
          print('WebSocket connection closed');
          Future.delayed(Duration(seconds: 5), _setupCryptoWebSocket);
        },
      );
    } catch (e) {
      print('Error setting up WebSocket: $e');
      Future.delayed(Duration(seconds: 5), _setupCryptoWebSocket);
    }
  }

  void _setupForexWebSocket() {
    if (!mounted) return;  // Prevent setup if widget is disposed

    try {
      _forexChannel?.sink.close();

      _forexChannel = WebSocketChannel.connect(
        Uri.parse('wss://socket.polygon.io/forex'),
      );

      // Add connection error handling
      _forexChannel!.stream.handleError((error) {
        print('Forex WebSocket connection error: $error');
        return;  // Don't try to reconnect immediately on error
      }).listen(
            (dynamic message) {
          // ... rest of your existing listen code ...
        },
        onError: (error) {
          print('Forex WebSocket stream error: $error');
          // Only try to reconnect if widget is still mounted
          if (mounted) {
            Future.delayed(Duration(seconds: 30), _setupForexWebSocket);
          }
        },
        onDone: () {
          print('Forex WebSocket connection closed normally');
          // Only try to reconnect if widget is still mounted
          if (mounted) {
            Future.delayed(Duration(seconds: 30), _setupForexWebSocket);
          }
        },
        cancelOnError: true,  // Don't try to use the socket after an error
      );

    } catch (e) {
      print('Error setting up Forex WebSocket: $e');
      if (mounted) {
        Future.delayed(Duration(seconds: 30), _setupForexWebSocket);
      }
    }
  }


  void _updateWidget() {
    // Check if enough time has passed since last update
    final now = DateTime.now();
    if (_lastWidgetUpdate != null &&
        now.difference(_lastWidgetUpdate!) < _minWidgetUpdateInterval) {
      return; // Skip update if too soon
    }

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

      _lastWidgetUpdate = now;
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
        elevation: 0,
        backgroundColor: Colors.transparent,
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
          decoration: InputDecoration(
            hintText: 'Search...',
            hintStyle: const TextStyle(color: Colors.white60),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            prefixIcon: const Icon(Icons.search, color: Colors.white60),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      );
    }

    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      title: const Text(
        'Market Rates',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 16,
          color: Colors.grey
        ),
        tabs: const [
          Tab(text: 'Crypto'),
          Tab(text: 'Forex'),
        ],
      ),
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
          padding: const EdgeInsets.only(right: 12),
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

  Widget _buildAssetCard({
    required String name,
    required String symbol,
    required int rank,
    required double price,
    required double change24h,
    required double marketCap,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.white.withOpacity(0.03),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            symbol,
                            style: TextStyle(
                              color: Colors.grey.shade300,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Market Cap: ${formatMarketCap(marketCap)}',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatPrice(price),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: change24h >= 0
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${change24h >= 0 ? '+' : ''}${change24h.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: change24h >= 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      drawer: _drawerContent,
      body: TabBarView(
        physics: AlwaysScrollableScrollPhysics(),
        controller: _tabController,
        children: [
          // Crypto Tab
          isCryptoLoading
              ? const Center(
            child: CircularProgressIndicator(color: Colors.white),
          )
              : ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: filteredCoins.length,
            itemBuilder: (context, index) {
              final coin = filteredCoins[index];
              return _buildAssetCard(
                name: coin.name,
                symbol: coin.symbol,
                rank: coin.rank,
                price: coin.price,
                change24h: coin.change24h,
                marketCap: coin.marketCap,
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

          // Forex Tab
          isForexLoading
              ? const Center(
            child: CircularProgressIndicator(color: Colors.white),
          )
              : ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: filteredForexPairs.length,
            itemBuilder: (context, index) {
              final pair = filteredForexPairs[index];
              return _buildAssetCard(
                name: pair.name,
                symbol: pair.symbol,
                rank: index + 1,
                price: pair.price,
                change24h: pair.change24h,
                marketCap: pair.volume,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (context){
                    return ForexDetailScreen(initialPair: pair);
                  }));
                },
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _cryptoChannel?.sink.close();
    _forexChannel?.sink.close();
    _coinsController.close();
    super.dispose();
  }
}


class DrawerContent extends StatefulWidget {
  const DrawerContent({Key? key}) : super(key: key);

  @override
  State<DrawerContent> createState() => _DrawerContentState();
}

class _DrawerContentState extends State<DrawerContent> {
  int _rating = 0;

  Future<void> _handleRating(int rating) async {
    setState(() {
      _rating = rating;
    });

    Navigator.of(context).pop();

    if (rating >= 4) {
      final url = Platform.isAndroid
          ? 'market://details?id=com.example.crypto_rates'
          : 'https://apps.apple.com/app/idYOUR_APP_ID'; // todo Replace YOUR_APP_ID
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the app store.'),
          ),
        );
      }
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Column(
              children: [
                Icon(
                  Icons.favorite,
                  color: Colors.red,
                  size: 40,
                ),
                SizedBox(height: 16),
                Text(
                  'Thank You',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: const Text(
                'Thank you for your feedback. We\'ll work hard to improve your experience.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
            actions: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Drawer(
        backgroundColor: Colors.blueGrey.shade900,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUnauthenticatedHeader(context),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: const IconContainer(
                      icon: Icons.star,
                      backgroundColor: Colors.amber,
                      iconColor: Colors.white,
                    ),
                    title: const Text(
                      'Rate Us',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    onTap: () => _showRateDialog(context),
                  ),
                  ListTile(
                    leading: const IconContainer(
                      icon: Icons.share,
                      backgroundColor: Colors.blue,
                      iconColor: Colors.white,
                    ),
                    title: const Text(
                      'Share App',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    onTap: () => Share.share(
                      'Check out this awesome crypto tracking app!\n\nDownload now: [Your App Store Link]',
                      subject: 'Check out this Crypto Tracking App',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

        return Drawer(
      backgroundColor: Colors.blueGrey.shade900,
      child: FutureBuilder<UserModel>(
        future: getUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Error loading user data',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            );
          }

          final userData = snapshot.data!;

          return Column(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        child: Text(
                          userData.name[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      userData.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userData.email,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade300,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                ),
                title: const Text(
                  'Member since',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  userData.createdAt != null
                      ? DateFormat('MMMM d, yyyy').format(userData.createdAt!.toDate())
                      : 'Not available',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                ),
              ),
              const Divider(
                color: Colors.white24,
                indent: 16,
                endIndent: 16,
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.star, color: Colors.amber, size: 20),
                ),
                title: const Text(
                  'Rate Us',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Colors.blueGrey.shade800,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Text(
                        'Rate Our App',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'If you enjoy using our app, please take a moment to rate it. Your feedback helps us improve!',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              5,
                                  (index) => IconButton(
                                icon: Icon(
                                  _rating > index ? Icons.star : Icons.star_border,
                                  color: Colors.amber,
                                  size: 32,
                                ),
                                onPressed: () => _handleRating(index + 1),
                              ),
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Maybe Later',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.share, color: Colors.blue, size: 20),
                ),
                title: const Text(
                  'Share App',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                onTap: () {
                  Share.share(
                    'Check out this awesome crypto tracking app!\n\n'
                        'Download now: [Your App Store Link]', // todo Replace with your app's store link
                    subject: 'Check out this Crypto Tracking App',
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                ),
                title: const Text(
                  'Sign Out',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 16,
                  ),
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        backgroundColor: Colors.blueGrey.shade800,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text(
                          'Sign Out',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        content: const Text(
                          'Are you sure you want to sign out?',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              await FirebaseAuth.instance.signOut();
                              if (context.mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                                      (route) => false,
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Sign Out'),
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

  Widget _buildUnauthenticatedHeader(BuildContext context) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.withOpacity(0.2),
            Colors.purple.withOpacity(0.2),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
            ),
            child: const Icon(
              Icons.person_outline,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context)=>
              LoginScreen()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'Sign In',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showRateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.blueGrey.shade800,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Rate Our App',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'If you enjoy using our app, please take a moment to rate it. Your feedback helps us improve!',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                    (index) => IconButton(
                  icon: Icon(
                    _rating > index ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                  onPressed: () => _handleRating(index + 1),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Maybe Later',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ),
        ],
      ),
    );
  }
}

class IconContainer extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  const IconContainer({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: iconColor, size: 20),
    );
  }
}

