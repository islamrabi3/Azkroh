import 'package:azkroh_app/l10n/app_locale.dart';
import 'dart:async';
import 'dart:convert';

import 'package:azkroh_app/features/core/appstyle.dart';
import 'package:azkroh_app/features/core/services/global_location_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Bottom sheet to choose the prayer-times location: GPS or any city in the
/// world (search powered by the Open-Meteo geocoding API, no key needed).
Future<bool?> showLocationPicker(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppStyle.background,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _LocationPicker(),
  );
}

class _City {
  final String name;
  final String subtitle;
  final double lat;
  final double lon;
  final String? timezone;

  _City(this.name, this.subtitle, this.lat, this.lon, this.timezone);
}

class _LocationPicker extends StatefulWidget {
  const _LocationPicker();

  @override
  State<_LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<_LocationPicker> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<_City> _results = [];
  bool _loading = false;
  String? _error;
  bool _gpsBusy = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    final query = q.trim();
    if (query.length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uri = Uri.parse(
          'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeQueryComponent(query)}&count=15&language=ar&format=json');
      final res = await http.get(uri).timeout(Duration(seconds: 15));
      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map;
      final list = (body['results'] as List? ?? []).map((e) {
        final m = e as Map;
        final sub = [m['admin1'], m['country']]
            .where((x) => x != null && '$x'.isNotEmpty)
            .join(', ');
        return _City('${m['name']}', sub, (m['latitude'] as num).toDouble(),
            (m['longitude'] as num).toDouble(), m['timezone'] as String?);
      }).toList();
      if (!mounted) return;
      setState(() {
        _results = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = tr('تعذر البحث، تأكد من الاتصال بالإنترنت');
      });
    }
  }

  Future<void> _useGps() async {
    setState(() => _gpsBusy = true);
    await GlobalLocationService().useAutomaticLocation();
    if (!mounted) return;
    setState(() => _gpsBusy = false);
    if (GlobalLocationService().currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('تعذر تحديد موقعك. فعّل خدمة الموقع أو اختر مدينتك يدوياً'))));
      return;
    }
    Navigator.pop(context, true);
  }

  Future<void> _pick(_City c) async {
    await GlobalLocationService().setManualLocation(
      lat: c.lat,
      lon: c.lon,
      name: c.subtitle.isEmpty ? c.name : '${c.name}، ${c.subtitle.split('، ').last}',
      timezone: c.timezone,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final loc = GlobalLocationService();
    return Directionality(
      textDirection: AppLocale.direction,
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.8,
          child: Column(
            children: [
              SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppStyle.textLight.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(tr('موقع مواقيت الصلاة'),
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ),
              if (loc.cityName != null)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                        '${tr('الحالي')}: ${loc.cityName} ${loc.isManual ? '(يدوي)' : '(تلقائي)'}',
                        style: TextStyle(color: AppStyle.textLight)),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Material(
                  color: AppStyle.primaryGreen,
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    onTap: _gpsBusy ? null : _useGps,
                    leading: _gpsBusy
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : Icon(Icons.my_location_rounded,
                            color: Colors.white),
                    title: Text(tr('تحديد موقعي تلقائياً (GPS)'),
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                    subtitle: Text(tr('يتحدث تلقائياً عند السفر'),
                        style: TextStyle(color: Colors.white70)),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _controller,
                  onChanged: _onChanged,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _search,
                  decoration: InputDecoration(
                    hintText: tr('أو ابحث عن مدينتك (مثال: القاهرة، لندن، جاكرتا)'),
                    prefixIcon: Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(
                            color: AppStyle.primaryGreen))
                    : _error != null
                        ? Center(child: Text(_error!))
                        : ListView.separated(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            itemCount: _results.length,
                            separatorBuilder: (_, __) =>
                                SizedBox(height: 6),
                            itemBuilder: (_, i) {
                              final c = _results[i];
                              return Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  leading: Icon(
                                      Icons.location_city_rounded,
                                      color: AppStyle.primaryGreen),
                                  title: Text(c.name,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  subtitle: Text(c.subtitle),
                                  onTap: () => _pick(c),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
