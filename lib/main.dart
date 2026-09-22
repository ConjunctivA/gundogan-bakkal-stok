import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------- renkler (bakkal / market temasi) ----------
const Color awning = Color(0xFF1F3D2B);
const Color awningDark = Color(0xFF152A1E);
const Color paper = Color(0xFFE9E0C9);
const Color paperLight = Color(0xFFF2ECDC);
const Color ink = Color(0xFF2B2419);
const Color red = Color(0xFFB3272D);
const Color mustard = Color(0xFFC98A3B);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ProductStore.instance.load();
  runApp(const GundoganBakkalApp());
}

// ---------- veri modeli ----------
class Product {
  String ad;
  double fiyat;
  Product({required this.ad, required this.fiyat});

  Map<String, dynamic> toJson() => {'ad': ad, 'fiyat': fiyat};
  factory Product.fromJson(Map<String, dynamic> j) =>
      Product(ad: j['ad'], fiyat: (j['fiyat'] as num).toDouble());
}

class ProductStore extends ChangeNotifier {
  ProductStore._();
  static final ProductStore instance = ProductStore._();

  final Map<String, Product> products = {};

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('urunler');
    if (raw != null) {
      final Map<String, dynamic> decoded = jsonDecode(raw);
      products.clear();
      decoded.forEach((k, v) => products[k] = Product.fromJson(v));
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> toEncode = {
      for (final e in products.entries) e.key: e.value.toJson()
    };
    await prefs.setString('urunler', jsonEncode(toEncode));
    notifyListeners();
  }

  Future<void> addOrUpdate(String barkod, String ad, double fiyat) async {
    products[barkod] = Product(ad: ad, fiyat: fiyat);
    await save();
  }

  Future<void> remove(String barkod) async {
    products.remove(barkod);
    await save();
  }
}

// ---------- app ----------
class GundoganBakkalApp extends StatelessWidget {
  const GundoganBakkalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gündoğan Bakkal Stok',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: paper,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: awning,
          primary: awning,
          secondary: red,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: awning,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: awning,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: paperLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: awning, width: 1.4),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: awning.withOpacity(0.5), width: 1.2),
          ),
        ),
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
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [const EkleTab(), const SorgulaTab(), const ListeTab()];
    return Scaffold(
      appBar: AppBar(
        title: const Text('GÜNDOĞAN BAKKAL STOK',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: mustard, width: 5)),
        ),
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: red,
        unselectedItemColor: awning,
        backgroundColor: paperLight,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), label: 'Ürün Ekle'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Sorgula'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Tüm Ürünler'),
        ],
      ),
    );
  }
}

// ---------- barkod tarama ekrani ----------
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      _handled = true;
      Navigator.pop(context, barcodes.first.rawValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Barkodu okutun'),
        backgroundColor: awningDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 260,
              height: 140,
              decoration: BoxDecoration(
                border: Border.all(color: mustard, width: 3),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- fis / fiyat etiketi karti ----------
class TagCard extends StatelessWidget {
  final String barkod;
  final String ad;
  final double fiyat;
  const TagCard({super.key, required this.barkod, required this.ad, required this.fiyat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: paperLight,
        border: Border.all(color: awning, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('|| $barkod ||',
              style: const TextStyle(fontFamily: 'monospace', color: Colors.brown, letterSpacing: 1.5)),
          const SizedBox(height: 6),
          Text(ad, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: ink)),
          const SizedBox(height: 4),
          Text('${fiyat.toStringAsFixed(2)} ₺',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: red)),
        ],
      ),
    );
  }
}

// ---------- Ekle sekmesi ----------
class EkleTab extends StatefulWidget {
  const EkleTab({super.key});
  @override
  State<EkleTab> createState() => _EkleTabState();
}

class _EkleTabState extends State<EkleTab> {
  final barkodCtrl = TextEditingController();
  final adCtrl = TextEditingController();
  final fiyatCtrl = TextEditingController();

  Future<void> _scan() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    if (result != null) setState(() => barkodCtrl.text = result);
  }

  Future<void> _save() async {
    final barkod = barkodCtrl.text.trim();
    final ad = adCtrl.text.trim();
    final fiyatText = fiyatCtrl.text.trim().replaceAll(',', '.');
    final fiyat = double.tryParse(fiyatText);

    if (barkod.isEmpty || ad.isEmpty || fiyat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barkod, ürün adı ve geçerli bir fiyat girin.'), backgroundColor: red),
      );
      return;
    }
    await ProductStore.instance.addOrUpdate(barkod, ad, fiyat);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"$ad" kaydedildi.'), backgroundColor: awning),
    );
    barkodCtrl.clear();
    adCtrl.clear();
    fiyatCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: _scan,
            icon: const Icon(Icons.camera_alt),
            label: const Text('BARKOD OKUT'),
          ),
          const SizedBox(height: 16),
          TextField(controller: barkodCtrl, decoration: const InputDecoration(labelText: 'Barkod No')),
          const SizedBox(height: 12),
          TextField(controller: adCtrl, decoration: const InputDecoration(labelText: 'Ürün Adı')),
          const SizedBox(height: 12),
          TextField(
            controller: fiyatCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Fiyat (₺)'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(backgroundColor: red),
            child: const Text('KAYDET'),
          ),
        ],
      ),
    );
  }
}

// ---------- Sorgula sekmesi ----------
class SorgulaTab extends StatefulWidget {
  const SorgulaTab({super.key});
  @override
  State<SorgulaTab> createState() => _SorgulaTabState();
}

class _SorgulaTabState extends State<SorgulaTab> {
  final barkodCtrl = TextEditingController();
  Product? found;
  String? notFoundCode;

  Future<void> _scan() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    if (result != null) {
      barkodCtrl.text = result;
      _search(result);
    }
  }

  void _search(String code) {
    final p = ProductStore.instance.products[code];
    setState(() {
      if (p != null) {
        found = p;
        notFoundCode = null;
      } else {
        found = null;
        notFoundCode = code;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: _scan,
            icon: const Icon(Icons.camera_alt),
            label: const Text('BARKOD OKUT'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: barkodCtrl,
            decoration: const InputDecoration(labelText: 'veya barkodu elle yazın'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => _search(barkodCtrl.text.trim()),
            child: const Text('ARA'),
          ),
          const SizedBox(height: 20),
          if (found != null)
            TagCard(barkod: barkodCtrl.text.trim(), ad: found!.ad, fiyat: found!.fiyat),
          if (notFoundCode != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.brown, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('"$notFoundCode" barkodu kayıtlı değil.\nÜrün Ekle sekmesinden kaydedebilirsiniz.',
                  style: const TextStyle(color: ink)),
            ),
        ],
      ),
    );
  }
}

// ---------- Liste sekmesi ----------
class ListeTab extends StatefulWidget {
  const ListeTab({super.key});
  @override
  State<ListeTab> createState() => _ListeTabState();
}

class _ListeTabState extends State<ListeTab> {
  Future<void> _confirmDelete(String barkod, String ad) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sil'),
        content: Text('"$ad" ürününü silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok == true) {
      await ProductStore.instance.remove(barkod);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = ProductStore.instance.products.entries.toList()
      ..sort((a, b) => a.value.ad.toLowerCase().compareTo(b.value.ad.toLowerCase()));

    if (entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Henüz kayıtlı ürün yok.\n"Ürün Ekle" sekmesinden başlayın.',
              textAlign: TextAlign.center, style: TextStyle(color: ink)),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final barkod = entries[i].key;
        final p = entries[i].value;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: paperLight,
            border: Border.all(color: awning.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.ad, style: const TextStyle(fontWeight: FontWeight.w600, color: ink)),
                    Text(barkod, style: const TextStyle(fontSize: 11, color: Colors.brown)),
                  ],
                ),
              ),
              Text('${p.fiyat.toStringAsFixed(2)} ₺',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: red, fontSize: 16)),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: red),
                onPressed: () => _confirmDelete(barkod, p.ad),
              ),
            ],
          ),
        );
      },
    );
  }
}
