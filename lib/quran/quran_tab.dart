import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quran_repository.dart';

class QuranTab extends StatefulWidget {
  const QuranTab({super.key});

  @override
  State<QuranTab> createState() => _QuranTabState();
}

class _QuranTabState extends State<QuranTab> {
  late final Future<List<QuranSurah>> _surahs = QuranRepository.load();
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openReader(QuranSurah surah, {int? verse}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: QuranReaderScreen(surah: surah, initialVerse: verse),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<QuranSurah>>(
      future: _surahs,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(child: Text('تعذر فتح بيانات المصحف المحلية.'));
        }
        final surahs = snapshot.data!;
        final matches = QuranRepository.search(surahs, _query);
        final searching = _query.trim().isNotEmpty;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('المصحف الكريم', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  const Text('قراءة وبحث محليان، بلا إنترنت.'),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _search,
                    textDirection: TextDirection.rtl,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'ابحث في آيات القرآن',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'مسح البحث',
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    searching ? '${matches.length} نتيجة ظاهرة' : '114 سورة • 6236 آية • نص محلي',
                    style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: searching
                  ? ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: matches.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final match = matches[index];
                        return Card(
                          child: ListTile(
                            onTap: () => _openReader(match.surah, verse: match.verse.number),
                            title: Text(match.surah.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                            subtitle: Text(match.verse.text, maxLines: 2, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl),
                            trailing: Text('${match.verse.number} : ${match.surah.number}'),
                          ),
                        );
                      },
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: surahs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final surah = surahs[index];
                        return Card(
                          child: ListTile(
                            onTap: () => _openReader(surah),
                            leading: CircleAvatar(child: Text('${surah.number}')),
                            title: Text(surah.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                            subtitle: Text('${surah.verses.length} آية • ${surah.revelationType == 'meccan' ? 'مكية' : 'مدنية'}'),
                            trailing: const Icon(Icons.chevron_left_rounded),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class QuranReaderScreen extends StatefulWidget {
  const QuranReaderScreen({super.key, required this.surah, this.initialVerse});

  final QuranSurah surah;
  final int? initialVerse;

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  double _fontSize = 25;
  Set<String> _bookmarks = <String>{};

  @override
  void initState() {
    super.initState();
    _loadReaderState();
  }

  Future<void> _loadReaderState() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getStringList('quran_bookmarks') ?? const [];
    if (mounted) setState(() => _bookmarks = stored.toSet());
  }

  String _key(QuranVerse verse) => '${widget.surah.number}:${verse.number}';

  Future<void> _rememberVerse(QuranVerse verse) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt('quran_last_surah', widget.surah.number);
    await preferences.setInt('quran_last_verse', verse.number);
  }

  Future<void> _toggleBookmark(QuranVerse verse) async {
    final key = _key(verse);
    final updated = Set<String>.from(_bookmarks);
    if (!updated.add(key)) updated.remove(key);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList('quran_bookmarks', updated.toList()..sort());
    if (mounted) setState(() => _bookmarks = updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(children: [Text(widget.surah.name), Text('${widget.surah.verses.length} آية', style: const TextStyle(fontSize: 11))]),
        actions: [
          IconButton(
            tooltip: 'تصغير الخط',
            onPressed: () => setState(() => _fontSize = (_fontSize - 2).clamp(19, 34)),
            icon: const Icon(Icons.text_decrease_rounded),
          ),
          IconButton(
            tooltip: 'تكبير الخط',
            onPressed: () => setState(() => _fontSize = (_fontSize + 2).clamp(19, 34)),
            icon: const Icon(Icons.text_increase_rounded),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        itemCount: widget.surah.verses.length + 1,
        itemBuilder: (_, index) {
          if (index == 0) {
            return Column(
              children: [
                Text('سورة ${widget.surah.name}', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('اضغط مطولاً على الآية لحفظ علامة مرجعية.'),
                const Divider(height: 30),
              ],
            );
          }
          final verse = widget.surah.verses[index - 1];
          final bookmarked = _bookmarks.contains(_key(verse));
          final highlighted = widget.initialVerse == verse.number;
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _rememberVerse(verse),
            onLongPress: () => _toggleBookmark(verse),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: highlighted ? theme.colorScheme.primaryContainer : null,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: bookmarked ? const Color(0xFFC58A28) : theme.dividerColor.withValues(alpha: .45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    CircleAvatar(radius: 13, child: Text('${verse.number}', style: const TextStyle(fontSize: 11))),
                    const Spacer(),
                    if (bookmarked) const Icon(Icons.bookmark_rounded, size: 18, color: Color(0xFFC58A28)),
                  ]),
                  const SizedBox(height: 9),
                  Text(verse.text, textDirection: TextDirection.rtl, textAlign: TextAlign.right, style: TextStyle(fontSize: _fontSize, height: 2.05, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
          child: Text('نص المصحف محلي • المصدر والرخصة في صفحة الخصوصية', textAlign: TextAlign.center, style: theme.textTheme.labelSmall),
        ),
      ),
    );
  }
}
