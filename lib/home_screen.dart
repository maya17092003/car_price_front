import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:shared_preferences/shared_preferences.dart'
    as shared_preferences;

class CarCard extends StatelessWidget {
  final Map<String, dynamic> ad;

  const CarCard({Key? key, required this.ad}) : super(key: key);

  static const _spacing = SizedBox(height: 8);

  static const _titleStyle = TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const _priceStyle = TextStyle(
    color: Colors.red,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const _specStyle = TextStyle(
    color: Colors.white70,
  );

  Widget _buildSpec(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 4),
        Text(
          text,
          style: _specStyle,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Card(
        color: const Color(0xFF1F1F1F),
        elevation: 4,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 200,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF808080),
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: ad['image'] != null && ad['image'].isNotEmpty
                  ? Image.network(
                      ad['image'],
                      fit: BoxFit.cover,
                      cacheWidth: 400,
                      frameBuilder:
                          (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded) return child;
                        return AnimatedOpacity(
                          opacity: frame == null ? 0 : 1,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          child: child,
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.directions_car,
                            size: 80, color: Colors.grey);
                      },
                    )
                  : const Icon(Icons.directions_car,
                      size: 80, color: Colors.grey),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${ad['title']}, ${ad['year']}г.',
                          style: _titleStyle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${ad['price'].toString()} ₽',
                        style: _priceStyle,
                      ),
                    ],
                  ),
                  _spacing,
                  Row(
                    children: [
                      if (ad['mileage'] != null) ...[
                        _buildSpec(Icons.speed, '${ad['mileage']} км'),
                        const SizedBox(width: 16),
                      ],
                      if (ad['engine_volume'] != null) ...[
                        _buildSpec(Icons.local_gas_station,
                            '${ad['engine_volume']} л'),
                        const SizedBox(width: 16),
                      ],
                      if (ad['transmission'] != null &&
                          ad['transmission'].isNotEmpty)
                        _buildSpec(Icons.settings, ad['transmission']),
                    ],
                  ),
                  _spacing,
                  Row(
                    children: [
                      if (ad['fuel_type'] != null &&
                          ad['fuel_type'].isNotEmpty) ...[
                        _buildSpec(
                            Icons.local_fire_department, ad['fuel_type']),
                        const SizedBox(width: 16),
                      ],
                      if (ad['drive'] != null && ad['drive'].isNotEmpty) ...[
                        _buildSpec(Icons.drive_eta, ad['drive']),
                        const SizedBox(width: 16),
                      ],
                      if (ad['power'] != null)
                        _buildSpec(Icons.flash_on, '${ad['power']} л.с.'),
                    ],
                  ),
                  _spacing,
                  if (ad['location'] != null)
                    _buildSpec(Icons.location_on, ad['location']),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _formKey = GlobalKey<FormState>();
  static const String CACHE_KEY = 'cached_ads';
  static const String GRAPH_DATA_KEY = 'graph_data';

  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _mileageFromController = TextEditingController();
  final _mileageToController = TextEditingController();
  final _priceFromController = TextEditingController();
  final _priceToController = TextEditingController();
  final _yearFromController = TextEditingController();
  final _yearToController = TextEditingController();
  final _engineVolumeController = TextEditingController();

  List<FlSpot> spots = [];
  List<Map<String, dynamic>> _marks = [];
  List<Map<String, dynamic>> _models = [];
  List<Map<String, dynamic>> _ads = [];
  int? _selectedMarkId;
  bool showGraph = false;

  @override
  void initState() {
    super.initState();
    _fetchMarks();
    _loadCachedData();
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _mileageFromController.dispose();
    _mileageToController.dispose();
    _priceFromController.dispose();
    _priceToController.dispose();
    _yearFromController.dispose();
    _yearToController.dispose();
    _engineVolumeController.dispose();
    super.dispose();
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await shared_preferences.SharedPreferences.getInstance();

      // Загружаем сохраненные объявления
      final String? cachedAdsString = prefs.getString(CACHE_KEY);
      if (cachedAdsString != null) {
        final List<dynamic> cachedAds = json.decode(cachedAdsString);
        setState(() {
          _ads = cachedAds.map((ad) => Map<String, dynamic>.from(ad)).toList();
        });
      }

      // Загружаем данные графика
      final String? graphDataString = prefs.getString(GRAPH_DATA_KEY);
      if (graphDataString != null) {
        final Map<String, dynamic> graphData = json.decode(graphDataString);

        List<double> prices =
        List<double>.from(graphData['prices'].map((x) => x.toDouble()));

        // Преобразуем индексы как ось X
        List<double> xValues =
        List.generate(prices.length, (index) => index.toDouble());

        setState(() {
          spots = List.generate(
            xValues.length,
                (i) => FlSpot(xValues[i], prices[i]),
          );
          showGraph = true;
        });
      }
    } catch (e) {
      print('Ошибка при загрузке кэшированных данных: $e');
    }
  }

  Future<void> _cacheData(List<Map<String, dynamic>> ads) async {
    try {
      final prefs = await shared_preferences.SharedPreferences.getInstance();
      final String adsString = json.encode(ads);
      await prefs.setString(CACHE_KEY, adsString);
    } catch (e) {
      print('Ошибка при сохранении данных: $e');
    }
  }

  Future<void> _cacheGraphData(Map<String, dynamic> graphData) async {
    try {
      final prefs = await shared_preferences.SharedPreferences.getInstance();
      final String graphDataString = json.encode(graphData);
      await prefs.setString(GRAPH_DATA_KEY, graphDataString);
    } catch (e) {
      print('Ошибка при сохранении данных графика: $e');
    }
  }

  Future<void> _fetchMarks() async {
    try {
      final response = await http.get(Uri.parse(
          'https://example.com/get_marks'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        if (mounted) {
          setState(() {
            _marks =
                data.map((e) => {'id': e['id'], 'mark': e['mark']}).toList();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _fetchModels(int markId) async {
    try {
      final response = await http.get(Uri.parse(
          'https://example.com/get_models_by_mark?mark_id=$markId'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        setState(() {
          _models = data
              .map((e) => {'id': e['id'].toString(), 'model': e['model']})
              .toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _submitForm() async {
    String? modelId;
    try {
      modelId = _models.firstWhere(
          (element) => element['model'] == _modelController.text)['id'];
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пожалуйста, выберите модель из списка'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final data = {
      'mark': _brandController.text,
      'model': _modelController.text,
      'mileage_from': _mileageFromController.text,
      'mileage_to': _mileageToController.text,
      'price_from': _priceFromController.text,
      'price_to': _priceToController.text,
      'engine_volume': _engineVolumeController.text,
      'year_from': _yearFromController.text,
      'year_to': _yearToController.text,
      'mark_id': _selectedMarkId?.toString(),
      'model_id': modelId,
    };

    try {
      final response = await http.post(
        Uri.parse('https://example.com/submit'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['advs'] != null && responseData['advs'].isNotEmpty &&
            responseData['graph'] != null && responseData['graph'].isNotEmpty) {
          print(responseData['advs']);
          print(responseData['graph']);
          List<dynamic> rawAds = responseData['advs'];
          List<Map<String, dynamic>> ads = rawAds.map((item) {
            return Map<String, dynamic>.from(item);
          }).toList();

          final graphData = responseData['graph'];
          List<double> prices =
              List<double>.from(graphData['prices'].map((x) => x.toDouble()));

          // Преобразуем индексы как ось X
          List<double> xValues =
              List.generate(prices.length, (index) => index.toDouble());

          // Сохраняем полученные данные в кэш
          await _cacheData(ads);
          // Сохраняем данные графика
          await _cacheGraphData(graphData);

          setState(() {
            _ads = ads;
            spots = List.generate(
              xValues.length,
              (i) => FlSpot(xValues[i], prices[i]),
            );
            showGraph = true;
          });
        } else {
          setState(() {
            _ads = [];
            showGraph = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Объявления не найдены'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сервера: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSearchForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TypeAheadField(
            hideOnSelect: true,
            hideOnUnfocus: true,
            suggestionsCallback: (pattern) {
              return _marks
                  .where((mark) => mark['mark']
                      .toLowerCase()
                      .contains(pattern.toLowerCase()))
                  .toList();
            },
            itemBuilder: (context, suggestion) {
              return ListTile(
                title: Text(
                  suggestion['mark'],
                  style: const TextStyle(color: Colors.white),
                ),
                tileColor: Colors.grey.shade800,
              );
            },
            onSelected: (suggestion) {
              setState(() {
                _brandController.text = suggestion['mark'];
                _selectedMarkId = suggestion['id'];
                _fetchModels(suggestion['id']);
              });
              FocusScope.of(context).unfocus();
            },
            builder: (context, controller, focusNode) {
              controller.text = _brandController.text;

              return TextField(
                controller: controller,
                focusNode: focusNode,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.red,
                decoration: const InputDecoration(
                  labelText: 'Марка',
                  labelStyle: TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.directions_car, color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red),
                  ),
                ),
                onChanged: (value) {
                  _brandController.text = value;
                },
              );
            },
            decorationBuilder: (context, child) {
              return Material(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
                elevation: 4,
                child: child,
              );
            },
          ),
          const SizedBox(height: 16),
          TypeAheadField(
            hideOnSelect: true,
            hideOnUnfocus: true,
            suggestionsCallback: (pattern) {
              return _models
                  .where((model) => model['model']
                      .toLowerCase()
                      .contains(pattern.toLowerCase()))
                  .toList();
            },
            itemBuilder: (context, suggestion) {
              return ListTile(
                title: Text(
                  suggestion['model'],
                  style: const TextStyle(color: Colors.white),
                ),
                tileColor: Colors.grey.shade800,
              );
            },
            onSelected: (suggestion) {
              setState(() {
                _modelController.text = suggestion['model'];
              });
              FocusScope.of(context).unfocus();
            },
            builder: (context, controller, focusNode) {
              controller.text = _modelController.text;

              return TextField(
                controller: controller,
                focusNode: focusNode,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.red,
                decoration: const InputDecoration(
                  labelText: 'Модель',
                  labelStyle: TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.car_repair, color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red),
                  ),
                ),
                onChanged: (value) {
                  _modelController.text = value;
                },
              );
            },
            decorationBuilder: (context, child) {
              return Material(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
                elevation: 4,
                child: child,
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _mileageFromController,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.red,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Пробег от',
                    labelStyle: TextStyle(color: Colors.white70),
                    prefixIcon: Icon(Icons.speed, color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _mileageToController,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.red,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Пробег до',
                    labelStyle: TextStyle(color: Colors.white70),
                    prefixIcon: Icon(Icons.speed, color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _priceFromController,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.red,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Цена от',
                    labelStyle: TextStyle(color: Colors.white70),
                    prefixIcon: Icon(Icons.money, color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _priceToController,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.red,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Цена до',
                    labelStyle: TextStyle(color: Colors.white70),
                    prefixIcon: Icon(Icons.money, color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _yearFromController,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.red,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Год от',
                    labelStyle: TextStyle(color: Colors.white70),
                    prefixIcon:
                        Icon(Icons.calendar_today, color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _yearToController,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.red,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Год до',
                    labelStyle: TextStyle(color: Colors.white70),
                    prefixIcon:
                        Icon(Icons.calendar_today, color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _engineVolumeController,
            style: const TextStyle(color: Colors.white),
            cursorColor: Colors.red,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Объём двигателя',
              labelStyle: TextStyle(color: Colors.white70),
              prefixIcon: Icon(Icons.local_gas_station, color: Colors.white70),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white30),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _submitForm();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text(
                    'Отправить',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGraph() {
    double minY = spots.map((spot) => spot.y).reduce((a, b) => a < b ? a : b);
    double maxY = spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);

    // Увеличиваем интервал для уменьшения количества меток
    double interval = (maxY - minY) / 3; // Изменено с 4 на 3
    interval = interval == 0 ? 1 : interval;

    String formatNumber(double number) {
      if (number >= 1000000) {
        return '${(number / 1000000).toStringAsFixed(1)}М';
      } else if (number >= 1000) {
        return '${(number / 1000).toStringAsFixed(1)}K';
      }
      return number.toStringAsFixed(0);
    }

    if (spots.length >= 2) {

      return Center(
        child: Container(
          width: MediaQuery.of(context).size.width,
          height: 300,
          padding: const EdgeInsets.only(
            left: 16, // Увеличили отступ слева
            right: 16,
            top: 24, // Увеличили верхний отступ
            bottom: 16,
          ),
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: interval,
                    reservedSize: 40, // Увеличили резервируемое место
                    getTitlesWidget: (double value, TitleMeta meta) {
                      return Text(
                        formatNumber(value),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  left: BorderSide(color: Colors.white30),
                  bottom: BorderSide(color: Colors.white30),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots.sublist(0, spots.length - 1),
                  isCurved: true,
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.shade700,
                      Colors.red.shade700,
                    ],
                  ),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: const LinearGradient(
                      colors: [
                        Color.fromRGBO(255, 0, 0, 0.3),
                        Color.fromRGBO(255, 0, 0, 0.05),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                LineChartBarData(
                  spots: [
                    spots[spots.length - 2],
                    FlSpot(
                      (spots[spots.length - 2].x + spots.last.x) / 2,
                      (spots[spots.length - 2].y + spots.last.y) / 2,
                    ),
                    spots.last,
                  ],
                  isCurved: true,
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.shade700,
                      spots.last.y > spots[spots.length - 2].y
                          ? Colors.green
                          : Colors.orange,
                    ],
                    stops: [0.3, 1.0],
                  ),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: const LinearGradient(
                      colors: [
                        Color.fromRGBO(255, 0, 0, 0.3),
                        Color.fromRGBO(255, 0, 0, 0.05),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
              minY: minY - (maxY - minY) * 0.1,
              maxY: maxY + (maxY - minY) * 0.1,
            ),
          ),
        ),
      );
    } else {
      return Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'Недостаточно данных для отображения графика',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
  }





  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text('Главная', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: _buildSearchForm(),
            ),
          ),
          if (_ads.isEmpty && showGraph)
            SliverToBoxAdapter(
              child: Center(
                child: Text(
                  'Объявления не найдены',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          if (showGraph) ...[
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: _buildGraph(),
              ),
            ),
          ],
          if (_ads.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Найдено объявлений: ${_ads.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => CarCard(
                    key: ValueKey(_ads[index]['id'] ?? index),
                    ad: _ads[index],
                  ),
                  childCount: _ads.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
