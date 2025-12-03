import 'package:flutter/material.dart';
import 'package:setbit/setbit.dart';

// Replace with your actual API key
const String apiKey = 'pk_your_api_key';

void main() {
  runApp(const SetBitExampleApp());
}

class SetBitExampleApp extends StatelessWidget {
  const SetBitExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SetBit Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late SetBitClient _client;
  bool _initialized = false;
  String _status = 'Initializing...';

  // Flag states
  bool _newCheckoutEnabled = false;
  String _pricingVariant = 'control';
  String _rolloutVariant = 'disabled';

  @override
  void initState() {
    super.initState();
    _initSetBit();
  }

  Future<void> _initSetBit() async {
    _client = SetBitClient(
      apiKey: apiKey,
      tags: {
        'env': 'production',
        'app': 'flutter-example',
        'platform': 'mobile',
      },
      silent: false, // Show logs for demo
    );

    try {
      await _client.init();
      setState(() {
        _initialized = true;
        _status = 'SDK initialized! User ID: ${_client.autoUserId}';
      });
      await _evaluateFlags();
    } catch (e) {
      setState(() {
        _status = 'Failed to initialize: $e';
      });
    }
  }

  Future<void> _evaluateFlags() async {
    if (!_initialized) return;

    setState(() => _status = 'Evaluating flags...');

    try {
      // Check boolean flag
      _newCheckoutEnabled = await _client.enabled('new-checkout');

      // Check experiment variant
      _pricingVariant = await _client.variant('pricing-experiment');

      // Check rollout variant
      _rolloutVariant = await _client.variant('api-v2-rollout');

      setState(() {
        _status = 'Flags evaluated successfully!';
      });
    } catch (e) {
      setState(() {
        _status = 'Error evaluating flags: $e';
      });
    }
  }

  Future<void> _trackPurchase() async {
    await _client.track(
      'purchase_completed',
      flagName: 'pricing-experiment',
      metadata: {
        'amount': _getPriceForVariant(_pricingVariant),
        'currency': 'USD',
        'variant': _pricingVariant,
      },
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase event tracked!')),
      );
    }
  }

  double _getPriceForVariant(String variant) {
    switch (variant) {
      case 'variant_a':
        return 99.0;
      case 'variant_b':
        return 149.0;
      default:
        return 129.0;
    }
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('SetBit Flutter Example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _evaluateFlags,
            tooltip: 'Refresh flags',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _initialized ? Icons.check_circle : Icons.pending,
                          color: _initialized ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _initialized ? 'SDK Ready' : 'Initializing',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_status, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Boolean flag example
            Text(
              '1. Boolean Feature Flag',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Card(
              child: ListTile(
                leading: Icon(
                  _newCheckoutEnabled
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  color: _newCheckoutEnabled ? Colors.green : Colors.grey,
                ),
                title: const Text('new-checkout'),
                subtitle: Text(
                  _newCheckoutEnabled
                      ? 'New checkout flow is enabled'
                      : 'Using legacy checkout',
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Experiment flag example
            Text(
              '2. A/B Test Experiment',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.science, color: Colors.purple),
                title: const Text('pricing-experiment'),
                subtitle: Text(
                  'Variant: $_pricingVariant\n'
                  'Price: \$${_getPriceForVariant(_pricingVariant).toStringAsFixed(0)}',
                ),
                isThreeLine: true,
              ),
            ),
            const SizedBox(height: 16),

            // Rollout flag example
            Text(
              '3. Percentage Rollout',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Card(
              child: ListTile(
                leading: Icon(
                  _rolloutVariant == 'enabled'
                      ? Icons.rocket_launch
                      : Icons.hourglass_empty,
                  color:
                      _rolloutVariant == 'enabled' ? Colors.blue : Colors.grey,
                ),
                title: const Text('api-v2-rollout'),
                subtitle: Text(
                  _rolloutVariant == 'enabled'
                      ? 'You\'re in the rollout group!'
                      : 'Using stable API v1',
                ),
              ),
            ),
            const Spacer(),

            // Track conversion button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _initialized ? _trackPurchase : null,
                icon: const Icon(Icons.shopping_cart),
                label: Text(
                  'Complete Purchase (\$${_getPriceForVariant(_pricingVariant).toStringAsFixed(0)})',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
