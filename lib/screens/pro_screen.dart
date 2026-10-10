import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/sumi_themes.dart';
import '../widgets/sumi_widgets.dart';

/// Sudoku PRO: Free-vs-Pro comparison, real purchase, restore, tip jar.
/// All prices come from the store — never hardcoded, never placeholders.
/// Until Wajiha creates the products in Play Console, an honest
/// "available after store setup" state is shown.
class ProScreen extends StatefulWidget {
  final SumiAudio audio;
  final SudoSettings settings;
  final StoreService? store;

  const ProScreen({
    super.key,
    required this.audio,
    required this.settings,
    this.store,
  });

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  SumiThemeDef get _t => widget.settings.themeDef();

  @override
  void initState() {
    super.initState();
    widget.store?.proPurchased.addListener(_onPro);
    widget.store?.lastThanks.addListener(_onThanks);
  }

  
  void _onThanks() {
    final msg = widget.store?.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: SumiType.body(15, _t)),
        backgroundColor: _t.walnut,
        behavior: SnackBarBehavior.floating,
      ),
    );
    widget.store!.lastThanks.value = null;
  }

  @override
  void dispose() {
    widget.store?.proPurchased.removeListener(_onPro);
    widget.store?.lastThanks.removeListener(_onThanks);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    final store = widget.store;
    final ready = store != null && store.storeReady;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: TatamiBackdrop(
        theme: t,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
                child: Row(
                  children: [
                    WoodToken(
                      theme: t,
                      size: 42,
                      onTap: () {
                        widget.audio.click();
                        Navigator.of(context).pop();
                      },
                      child: Icon(Icons.arrow_back,
                          color: t.washi, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text('Sudoku PRO',
                        style: SumiType.display(24, t)),
                  ],
                ),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: s,
                  builder: (_, _) => SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 10),
                    child: Column(
                      children: [
                                                _TipsCard(
                          theme: t,
                          store: store,
                          audio: widget.audio,
                          ready: ready,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Free vs Pro comparison table — buyers see the big difference.
class _Cell extends StatelessWidget {
  final Object value; // bool | String
  final SumiThemeDef theme;
  const _Cell({required this.value, required this.theme});

  @override
  Widget build(BuildContext context) {
    if (value is bool) {
      final v = value as bool;
      return Text(
        v ? '✓' : '—',
        style: SumiType.body(15,
            theme,
            color: v
                ? theme.vermilion
                : theme.walnut.withValues(alpha: 0.4)),
        textAlign: TextAlign.center,
      );
    }
    return Text(
      value as String,
      style: SumiType.label(12, theme),
      textAlign: TextAlign.center,
    );
  }
}

// ---------------------------------------------------------------------------
class _TipsCard extends StatelessWidget {
  final SumiThemeDef theme;
  final StoreService? store;
  final SumiAudio audio;
  final bool ready;
  const _TipsCard({
    required this.theme,
    required this.store,
    required this.audio,
    required this.ready,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    Widget tipRow(ProductDetails? p, String emoji, String blurb) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p?.title ?? blurb,
                      style: SumiType.body(15, t)),
                  Text(
                    p != null
                        ? '${p.price} · ${p.description}'
                        : 'Available after store setup',
                    style: SumiType.micro(12, t),
                  ),
                ],
              ),
            ),
            WoodButton(
              theme: t,
              text: p != null ? p.price : '—',
              onTap: p == null
                  ? () {}
                  : () {
                      audio.click();
                      store!.buyTip(p);
                    },
            ),
          ],
        ),
      );
    }

    return WashiCard(
      theme: t,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tip jar', style: SumiType.display(18, t)),
          const SizedBox(height: 4),
          Text(
            'Sudoku is free forever. Tips keep the ink flowing — no pay-to-win, ever.',
            style: SumiType.body(13, t,
                color: t.walnut.withValues(alpha: 0.75)),
          ),
          const SizedBox(height: 8),
          tipRow(store?.coffeeProduct, '☕', 'Buy the maker a coffee'),
          tipRow(store?.chocolateProduct, '🍫',
              'Buy the maker a chocolate'),
        ],
      ),
    );
  }
}
