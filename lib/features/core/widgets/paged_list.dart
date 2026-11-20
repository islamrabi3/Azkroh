import 'dart:async';

import 'package:flutter/material.dart';

import 'app_loader.dart';

/// Sliver that reveals [items] one page at a time. The next page is added
/// when the footer scrolls into the build range, so long lists (hundreds of
/// reciters, stations, hadiths) never build or lay out everything at once.
///
/// Passing a new list instance (e.g. a new search result) resets paging.
class PagedSliverList<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int pageSize;
  final EdgeInsetsGeometry padding;
  final double spacing;

  const PagedSliverList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.pageSize = 25,
    this.padding = EdgeInsets.zero,
    this.spacing = 0,
  });

  @override
  State<PagedSliverList<T>> createState() => _PagedSliverListState<T>();
}

class _PagedSliverListState<T> extends State<PagedSliverList<T>> {
  late int _shown = widget.pageSize;
  bool _scheduled = false;

  @override
  void didUpdateWidget(covariant PagedSliverList<T> old) {
    super.didUpdateWidget(old);
    if (!identical(old.items, widget.items)) _shown = widget.pageSize;
  }

  void _loadMore() {
    if (_scheduled) return;
    _scheduled = true;
    // Defer so we never call setState during build; a short pause lets the
    // current frame finish before the next page is laid out.
    Timer(const Duration(milliseconds: 120), () {
      _scheduled = false;
      if (!mounted) return;
      setState(() => _shown += widget.pageSize);
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.items.length;
    final count = _shown < total ? _shown : total;
    final hasMore = count < total;
    return SliverPadding(
      padding: widget.padding,
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            if (i == count) {
              _loadMore();
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: AppLoader(size: 26),
              );
            }
            final child = widget.itemBuilder(context, widget.items[i], i);
            if (widget.spacing <= 0) return child;
            return Padding(
              padding: EdgeInsets.only(bottom: widget.spacing),
              child: child,
            );
          },
          childCount: count + (hasMore ? 1 : 0),
        ),
      ),
    );
  }
}

/// Text field with a built-in debounce, so filtering long lists does not run
/// on every keystroke.
class DebouncedSearchField extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final Duration delay;
  final Color fillColor;

  const DebouncedSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.delay = const Duration(milliseconds: 280),
    this.fillColor = Colors.white,
  });

  @override
  State<DebouncedSearchField> createState() => _DebouncedSearchFieldState();
}

class _DebouncedSearchFieldState extends State<DebouncedSearchField> {
  final _c = TextEditingController();
  Timer? _t;

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _changed(String v) {
    setState(() {});
    _t?.cancel();
    _t = Timer(widget.delay, () => widget.onChanged(v));
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      onChanged: _changed,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _c.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () {
                  _c.clear();
                  _t?.cancel();
                  setState(() {});
                  widget.onChanged('');
                },
              ),
        filled: true,
        fillColor: widget.fillColor,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// Arabic-insensitive search key: no diacritics, unified alef/ya/ta-marbuta.
String searchKey(String s) => s
    .replaceAll(RegExp('[\\u0610-\\u061A\\u064B-\\u065F\\u0670\\u06D6-\\u06ED\\u0640]'), '')
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .replaceAll(' ', '')
    .toLowerCase();
