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

  void _onPro() {
    if ((widget.store?.proPurchased.value ?? false) && mounted) {
      widget.settings.setPro(true);
      widget.audio.win();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PRO unlocked — enjoy everything!',
              style: SumiType.body(15, _t)),
          backgroundColor: _t.walnut,
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.store!.proPurchased.value = false;
    }
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
                        _ComparisonCard(theme: t, isPro: s.isPro),
                        const SizedBox(height: 16),
                        _BuyCard(
                          theme: t,
                          settings: s,
                          store: store,
                          audio: widget.audio,
                          ready: ready,
                        ),
                        const SizedBox(height: 16),
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
class _ComparisonCard extends StatelessWidget {
  final SumiThemeDef theme;
  final bool isPro;
  const _ComparisonCard({required this.theme, required this.isPro});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Complete Sudoku game', true, true),
      ('All official rules', true, true),
      ('Novice → Expert + Daily puzzle', true, true),
      ('Timed & Relaxed modes', true, true),
      ('Renameable player profile', true, true),
      ('Music & sound effects', true, true),
      ('Washi themes', '4', '14 + custom'),
      ('Digit styles', '4', '9'),
      ('Grid accents', '3', '6'),
      ('Custom theme creator', false, true),
      ('Daily streak tracking', true, true),
      ('Priority new features', false, true),
    ];
    return WashiCard(
      theme: theme,
      child: Column(
        children: [
          Text('Free vs PRO', style: SumiType.display(20, theme)),
          const SizedBox(height: 4),
          Text(
            'One purchase. Yours forever.',
            style: SumiType.body(13,
                theme, color: theme.walnut.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(flex: 5, child: SizedBox()),
              Expanded(
                  flex: 2,
                  child: Text('FREE',
                      style: SumiType.label(12, theme),
                      textAlign: TextAlign.center)),
              Expanded(
                  flex: 2,
                  child: Text('PRO',
                      style: SumiType.label(12, theme),
                      textAlign: TextAlign.center)),
            ],
          ),
          Divider(height: 14, color: theme.washLine),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(r.$1,
                        style: SumiType.body(13, theme)),
                  ),
                  Expanded(flex: 2, child: _Cell(value: r.$2, theme: theme)),
                  Expanded(flex: 2, child: _Cell(value: r.$3, theme: theme)),
                ],
              ),
            ),
          if (isPro)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: theme.vermilion.withValues(alpha: 0.15),
                  border: Border.all(color: theme.vermilion),
                ),
                child: Text('✦ PRO ACTIVE ✦',
                    style: SumiType.label(14, theme,
                        color: theme.vermilion)),
              ),
            ),
        ],
      ),
    );
  }
}

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
class _BuyCard extends StatelessWidget {
  final SumiThemeDef theme;
  final SudoSettings settings;
  final StoreService? store;
  final SumiAudio audio;
  final bool ready;
  const _BuyCard({
    required this.theme,
    required this.settings,
    required this.store,
    required this.audio,
    required this.ready,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final pro = store?.proProduct;
    return WashiCard(
      theme: t,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Unlock PRO', style: SumiType.display(18, t)),
          const SizedBox(height: 6),
          if (settings.isPro)
            Text('PRO is active on this device. Thank you!',
                style: SumiType.body(14, t)),
          if (!settings.isPro && !ready)
            Text(
              store?.error ?? 'Available after store setup',
              style: SumiType.body(14, t,
                  color: t.walnut.withValues(alpha: 0.7)),
            ),
          if (!settings.isPro && ready && pro != null) ...[
            Text(pro.description.isNotEmpty
                ? pro.description
                : 'Every theme, digit style and grid accent — forever.',
                style: SumiType.body(14, t)),
            const SizedBox(height: 12),
            Center(
              child: WoodButton(
                theme: t,
                text: 'Buy PRO · ${pro.price}',
                icon: Icons.star,
                primary: true,
                onTap: () {
                  audio.click();
                  store!.buyPro();
                },
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () {
                  audio.click();
                  store!.restore();
                },
                child: Text('Restore purchase',
                    style: SumiType.label(12, t)),
              ),
            ),
          ],
          if ((store?.purchaseError.value ?? '') != '')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(store!.purchaseError.value!,
                  style: SumiType.body(13, t, color: t.vermilion)),
            ),
        ],
      ),
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
