import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String firebaseUrl = String.fromEnvironment(
  'FIREBASE_DATABASE_URL',
  defaultValue: 'https://tradelens-academy-default-rtdb.firebaseio.com',
);

void main() {
  runApp(const TradeLensApp());
}

class TradeLensApp extends StatelessWidget {
  const TradeLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TradeLens Academy',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF39D98A),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0B0F14),
        cardTheme: CardTheme(
          color: const Color(0xFF121A23),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      home: const MainShell(),
    );
  }
}

class Trade {
  final String id;
  final String symbol;
  final String type;
  final double lot;
  final double entry;
  final double sl;
  final double tp;
  final double profit;
  final String status;
  final String time;

  Trade({
    required this.id,
    required this.symbol,
    required this.type,
    required this.lot,
    required this.entry,
    required this.sl,
    required this.tp,
    required this.profit,
    required this.status,
    required this.time,
  });

  factory Trade.fromMap(String id, Map<String, dynamic> map) {
    double toDouble(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0;
    }

    return Trade(
      id: id,
      symbol: (map['symbol'] ?? 'Unknown').toString(),
      type: (map['type'] ?? map['order_type'] ?? 'TRADE').toString().toUpperCase(),
      lot: toDouble(map['lot'] ?? map['volume']),
      entry: toDouble(map['entry'] ?? map['price_open']),
      sl: toDouble(map['sl']),
      tp: toDouble(map['tp']),
      profit: toDouble(map['profit']),
      status: (map['status'] ?? 'open').toString(),
      time: (map['time'] ?? map['created_at'] ?? '').toString(),
    );
  }
}

class FirebaseTradeService {
  Future<List<Trade>> fetchTrades() async {
    final normalized = firebaseUrl.endsWith('/')
        ? firebaseUrl.substring(0, firebaseUrl.length - 1)
        : firebaseUrl;
    final uri = Uri.parse('$normalized/trades.json');
    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200 || res.body == 'null') return [];
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) return [];
    final trades = <Trade>[];
    decoded.forEach((key, value) {
      if (value is Map) {
        trades.add(Trade.fromMap(key.toString(), Map<String, dynamic>.from(value)));
      }
    });
    trades.sort((a, b) => b.time.compareTo(a.time));
    return trades;
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  final service = FirebaseTradeService();
  late Future<List<Trade>> futureTrades;

  @override
  void initState() {
    super.initState();
    futureTrades = service.fetchTrades();
  }

  void refresh() {
    setState(() => futureTrades = service.fetchTrades());
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(futureTrades: futureTrades, onRefresh: refresh),
      HistoryPage(futureTrades: futureTrades, onRefresh: refresh),
      const DisclaimerPage(),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.warning_amber), label: 'Disclaimer'),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  final Future<List<Trade>> futureTrades;
  final VoidCallback onRefresh;

  const DashboardPage({super.key, required this.futureTrades, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<Trade>>(
        future: futureTrades,
        builder: (context, snapshot) {
          final trades = snapshot.data ?? [];
          final totalProfit = trades.fold<double>(0, (sum, t) => sum + t.profit);
          final wins = trades.where((t) => t.profit > 0).length;
          final losses = trades.where((t) => t.profit < 0).length;
          final winRate = trades.isEmpty ? 0 : (wins / trades.length * 100);

          return RefreshIndicator(
            onRefresh: () async => onRefresh(),
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TradeLens Academy', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                          SizedBox(height: 6),
                          Text('Educational trade tracking and performance journal'),
                        ],
                      ),
                    ),
                    IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh)),
                  ],
                ),
                const SizedBox(height: 18),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
                if (snapshot.hasError)
                  ErrorCard(message: snapshot.error.toString()),
                if (!snapshot.hasError) ...[
                  Row(
                    children: [
                      Expanded(child: StatCard(title: 'Total P/L', value: totalProfit.toStringAsFixed(2))),
                      const SizedBox(width: 12),
                      Expanded(child: StatCard(title: 'Win Rate', value: '${winRate.toStringAsFixed(1)}%')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: StatCard(title: 'Wins', value: '$wins')),
                      const SizedBox(width: 12),
                      Expanded(child: StatCard(title: 'Losses', value: '$losses')),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text('Latest Trades', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (trades.isEmpty)
                    const EmptyCard()
                  else
                    ...trades.take(8).map((t) => TradeTile(trade: t)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class HistoryPage extends StatelessWidget {
  final Future<List<Trade>> futureTrades;
  final VoidCallback onRefresh;

  const HistoryPage({super.key, required this.futureTrades, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<Trade>>(
        future: futureTrades,
        builder: (context, snapshot) {
          final trades = snapshot.data ?? [];
          return RefreshIndicator(
            onRefresh: () async => onRefresh(),
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                const Text('Trade History', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
                else if (snapshot.hasError)
                  ErrorCard(message: snapshot.error.toString())
                else if (trades.isEmpty)
                  const EmptyCard()
                else
                  ...trades.map((t) => TradeTile(trade: t)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class DisclaimerPage extends StatelessWidget {
  const DisclaimerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Disclaimer', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text(
              'The content displayed in this app is for educational and analytical purposes only. '
              'It does not constitute financial advice, investment advice, or a recommendation to buy or sell any financial instrument.\n\n'
              'Trading financial markets involves significant risk and may result in the loss of capital. Past performance does not guarantee future results.\n\n'
              'You are solely responsible for your own trading and investment decisions. Always conduct your own research before making any financial decision.',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;

  const StatCard({super.key, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class TradeTile extends StatelessWidget {
  final Trade trade;

  const TradeTile({super.key, required this.trade});

  @override
  Widget build(BuildContext context) {
    final isProfit = trade.profit >= 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text('${trade.symbol} • ${trade.type}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Lot: ${trade.lot}  Entry: ${trade.entry}  SL: ${trade.sl}  TP: ${trade.tp}'),
        trailing: Text(
          trade.profit.toStringAsFixed(2),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isProfit ? const Color(0xFF39D98A) : const Color(0xFFFF5C5C),
          ),
        ),
      ),
    );
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Text('No trades yet. Once MT5 sends data to Firebase, trades will appear here.'),
      ),
    );
  }
}

class ErrorCard extends StatelessWidget {
  final String message;

  const ErrorCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text('Error: $message'),
      ),
    );
  }
}
