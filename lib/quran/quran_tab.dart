import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quran_reading_store.dart';
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
  int? _lastSurah;
  int? _lastVerse;
  QuranReadingData _readingData = const QuranReadingData(
    bookmarkColors: <String, String>{},
    favorites: <String>{},
    notes: <String, String>{},
  );

  @override
  void initState() {
    super.initState();
    _loadReadingState();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadReadingState() async {
    final preferences = await SharedPreferences.getInstance();
    final data = await QuranReadingStore.load();
    if (!mounted) return;
    setState(() {
      _lastSurah = preferences.getInt('quran_last_surah');
      _lastVerse = preferences.getInt('quran_last_verse');
      _readingData = data;
    });
  }

  Future<void> _openReader(QuranSurah surah, {int? verse}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: QuranReaderScreen(surah: surah, initialVerse: verse),
        ),
      ),
    );
    await _loadReadingState();
  }

  Future<void> _openSavedPosition(List<QuranSurah> surahs, String key) async {
    final parts = key.split(':');
    if (parts.length != 2) return;
    final surahNumber = int.tryParse(parts.first);
    final verseNumber = int.tryParse(parts.last);
    if (surahNumber == null || verseNumber == null) return;
    final matches = surahs.where((surah) => surah.number == surahNumber);
    if (matches.isEmpty) return;
    await _openReader(matches.first, verse: verseNumber);
  }

  Future<void> _showNewKhatmahDialog() async {
    var days = 30;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('بدء ختمة جديدة'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('اختر المدة التي تناسبك. يُحسب الورد من عدد آيات المصحف المحلي، ويمكنك تغييره لاحقاً.'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [7, 15, 30, 45, 60].map(
                    (value) => ChoiceChip(
                      label: Text('$value يوماً'),
                      selected: days == value,
                      onSelected: (_) => setDialogState(() => days = value),
                    ),
                  ).toList(),
                ),
                const SizedBox(height: 16),
                Text('ورد تقريبي: ${(6236 / days).ceil()} آية يومياً.', style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('بدء الختمة')),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    final plan = QuranKhatmahPlan(startedAt: DateTime.now(), durationDays: days);
    await QuranReadingStore.savePlan(plan);
    await _loadReadingState();
  }

  Future<void> _clearKhatmah() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('إنهاء الخطة الحالية؟'),
              content: const Text('سيُحذف جدول الختمة فقط، ولن تُحذف العلامات أو المفضلة أو الملاحظات.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
                FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('إنهاء الخطة')),
              ],
            ),
          ),
        ) ??
        false;
    if (!confirmed) return;
    await QuranReadingStore.clearPlan();
    await _loadReadingState();
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
                  ? _SearchResults(matches: matches, onOpen: (surah, verse) => _openReader(surah, verse: verse))
                  : DefaultTabController(
                      length: 3,
                      child: Column(
                        children: [
                          const TabBar(
                            tabs: [
                              Tab(text: 'السور'),
                              Tab(text: 'خطتي'),
                              Tab(text: 'محفوظاتي'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _SurahList(
                                  surahs: surahs,
                                  lastSurah: _lastSurah,
                                  lastVerse: _lastVerse,
                                  onOpen: _openReader,
                                ),
                                _KhatmahPlanView(
                                  plan: _readingData.plan,
                                  surahs: surahs,
                                  lastSurah: _lastSurah,
                                  lastVerse: _lastVerse,
                                  onCreate: _showNewKhatmahDialog,
                                  onClear: _clearKhatmah,
                                  onContinue: _lastSurah == null
                                      ? null
                                      : () => _openReader(
                                            surahs.firstWhere((surah) => surah.number == _lastSurah),
                                            verse: _lastVerse,
                                          ),
                                ),
                                _SavedReadingsView(
                                  data: _readingData,
                                  surahs: surahs,
                                  onOpen: (key) => _openSavedPosition(surahs, key),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.matches, required this.onOpen});

  final List<QuranSearchMatch> matches;
  final void Function(QuranSurah surah, int verse) onOpen;

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: matches.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, index) {
          final match = matches[index];
          return Card(
            child: ListTile(
              onTap: () => onOpen(match.surah, match.verse.number),
              title: Text(match.surah.name, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(match.verse.text, maxLines: 2, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl),
              trailing: Text('${match.verse.number} : ${match.surah.number}'),
            ),
          );
        },
      );
}

class _SurahList extends StatelessWidget {
  const _SurahList({
    required this.surahs,
    required this.lastSurah,
    required this.lastVerse,
    required this.onOpen,
  });

  final List<QuranSurah> surahs;
  final int? lastSurah;
  final int? lastVerse;
  final Future<void> Function(QuranSurah surah, {int? verse}) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      children: [
        if (lastSurah != null)
          Card(
            color: theme.colorScheme.primaryContainer,
            child: ListTile(
              onTap: () => onOpen(surahs.firstWhere((item) => item.number == lastSurah), verse: lastVerse),
              leading: const CircleAvatar(child: Icon(Icons.play_arrow_rounded)),
              title: const Text('متابعة القراءة', style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text('السورة ${surahs.firstWhere((item) => item.number == lastSurah).name} • الآية ${lastVerse ?? 1}'),
              trailing: const Icon(Icons.chevron_left_rounded),
            ),
          ),
        if (lastSurah != null) const SizedBox(height: 10),
        ...surahs.map(
          (surah) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                onTap: () => onOpen(surah),
                leading: CircleAvatar(child: Text('${surah.number}')),
                title: Text(surah.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text('${surah.verses.length} آية • ${surah.revelationType == 'meccan' ? 'مكية' : 'مدنية'}'),
                trailing: const Icon(Icons.chevron_left_rounded),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _KhatmahPlanView extends StatelessWidget {
  const _KhatmahPlanView({
    required this.plan,
    required this.surahs,
    required this.lastSurah,
    required this.lastVerse,
    required this.onCreate,
    required this.onClear,
    required this.onContinue,
  });

  final QuranKhatmahPlan? plan;
  final List<QuranSurah> surahs;
  final int? lastSurah;
  final int? lastVerse;
  final Future<void> Function() onCreate;
  final Future<void> Function() onClear;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completed = lastSurah == null || lastVerse == null
        ? 0
        : QuranReadingStore.globalVerseIndex(surahs, lastSurah!, lastVerse!);
    final progress = (completed / 6236).clamp(0.0, 1.0).toDouble();
    if (plan == null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(Icons.auto_graph_rounded, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 14),
          Text('خطة قراءة هادئة', textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('أنشئ ختمة محلية تختار مدتها بنفسك. لا يحتاج هذا إلى حساب ولا إنترنت.', textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add_rounded), label: const Text('بدء ختمة جديدة')),
        ],
      );
    }
    final now = DateTime.now();
    final remainingDays = plan!.endsAt.difference(now).inDays.clamp(0, plan!.durationDays);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('ختمتي الحالية', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
              const SizedBox(height: 6),
              Text('الورد المقترح: ${plan!.dailyVerses} آية يومياً'),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: progress, minHeight: 10, borderRadius: BorderRadius.circular(10)),
              const SizedBox(height: 8),
              Text('موضع القراءة المسجل: $completed من 6236 آية • ${(progress * 100).round()}٪'),
              const Divider(height: 28),
              Text('تبدأ ${_dateLabel(plan!.startedAt)} • المتبقي تقريباً $remainingDays يوماً'),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onContinue,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('متابعة وردي'),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: onClear, icon: const Icon(Icons.close_rounded), label: const Text('إنهاء الخطة الحالية')),
      ],
    );
  }
}

class _SavedReadingsView extends StatelessWidget {
  const _SavedReadingsView({required this.data, required this.surahs, required this.onOpen});

  final QuranReadingData data;
  final List<QuranSurah> surahs;
  final Future<void> Function(String key) onOpen;

  @override
  Widget build(BuildContext context) {
    final items = <_SavedVerseItem>[];
    for (final entry in data.bookmarkColors.entries) {
      final item = _SavedVerseItem.fromKey(entry.key, surahs, label: 'علامة ${QuranReadingStore.bookmarkColorOptions[entry.value] ?? ''}', icon: Icons.bookmark_rounded, accent: _bookmarkColor(entry.value));
      if (item != null) items.add(item);
    }
    for (final key in data.favorites) {
      final item = _SavedVerseItem.fromKey(key, surahs, label: 'مفضلة', icon: Icons.star_rounded, accent: const Color(0xFFC58A28));
      if (item != null) items.add(item);
    }
    for (final entry in data.notes.entries) {
      final item = _SavedVerseItem.fromKey(entry.key, surahs, label: entry.value, icon: Icons.sticky_note_2_rounded, accent: const Color(0xFF2E6F95));
      if (item != null) items.add(item);
    }
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('لا توجد عناصر محفوظة بعد. اضغط مطولاً على أي آية لإضافة علامة أو مفضلة أو ملاحظة.', textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final item = items[index];
        return Card(
          child: ListTile(
            onTap: () => onOpen(item.key),
            leading: CircleAvatar(backgroundColor: item.accent.withValues(alpha: .15), child: Icon(item.icon, color: item.accent)),
            title: Text('${item.surah.name} • الآية ${item.verse.number}', style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text(item.label, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_left_rounded),
          ),
        );
      },
    );
  }
}

class _SavedVerseItem {
  const _SavedVerseItem({
    required this.key,
    required this.surah,
    required this.verse,
    required this.label,
    required this.icon,
    required this.accent,
  });

  final String key;
  final QuranSurah surah;
  final QuranVerse verse;
  final String label;
  final IconData icon;
  final Color accent;

  static _SavedVerseItem? fromKey(
    String key,
    List<QuranSurah> surahs, {
    required String label,
    required IconData icon,
    required Color accent,
  }) {
    final parts = key.split(':');
    if (parts.length != 2) return null;
    final surahNumber = int.tryParse(parts.first);
    final verseNumber = int.tryParse(parts.last);
    if (surahNumber == null || verseNumber == null) return null;
    final surahMatches = surahs.where((surah) => surah.number == surahNumber);
    if (surahMatches.isEmpty) return null;
    final surah = surahMatches.first;
    final verseMatches = surah.verses.where((verse) => verse.number == verseNumber);
    if (verseMatches.isEmpty) return null;
    return _SavedVerseItem(key: key, surah: surah, verse: verseMatches.first, label: label, icon: icon, accent: accent);
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
  QuranReadingData _readingData = const QuranReadingData(
    bookmarkColors: <String, String>{},
    favorites: <String>{},
    notes: <String, String>{},
  );

  @override
  void initState() {
    super.initState();
    _loadReaderState();
  }

  Future<void> _loadReaderState() async {
    final data = await QuranReadingStore.load();
    if (mounted) setState(() => _readingData = data);
  }

  String _key(QuranVerse verse) => QuranReadingStore.positionKey(widget.surah.number, verse.number);

  Future<void> _rememberVerse(QuranVerse verse) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt('quran_last_surah', widget.surah.number);
    await preferences.setInt('quran_last_verse', verse.number);
  }

  Future<void> _showVerseActions(QuranVerse verse) async {
    final key = _key(verse);
    final activeBookmark = _readingData.bookmarkColors[key];
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(title: Text('${widget.surah.name} • الآية ${verse.number}', style: const TextStyle(fontWeight: FontWeight.w900))),
              for (final entry in QuranReadingStore.bookmarkColorOptions.entries)
                ListTile(
                  leading: Icon(Icons.bookmark_rounded, color: _bookmarkColor(entry.key)),
                  title: Text('علامة ${entry.value}'),
                  trailing: activeBookmark == entry.key ? const Icon(Icons.check_rounded) : null,
                  onTap: () => Navigator.pop(sheetContext, 'bookmark:${entry.key}'),
                ),
              if (activeBookmark != null)
                ListTile(
                  leading: const Icon(Icons.bookmark_remove_outlined),
                  title: const Text('إزالة العلامة'),
                  onTap: () => Navigator.pop(sheetContext, 'remove-bookmark'),
                ),
              ListTile(
                leading: Icon(_readingData.favorites.contains(key) ? Icons.star_rounded : Icons.star_border_rounded, color: const Color(0xFFC58A28)),
                title: Text(_readingData.favorites.contains(key) ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة'),
                onTap: () => Navigator.pop(sheetContext, 'favorite'),
              ),
              ListTile(
                leading: const Icon(Icons.sticky_note_2_outlined),
                title: Text(_readingData.notes.containsKey(key) ? 'تعديل الملاحظة' : 'إضافة ملاحظة'),
                onTap: () => Navigator.pop(sheetContext, 'note'),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null) return;
    if (action.startsWith('bookmark:')) {
      await QuranReadingStore.saveBookmark(key, action.split(':').last);
      await _loadReaderState();
      return;
    }
    if (action == 'remove-bookmark') {
      await QuranReadingStore.saveBookmark(key, null);
      await _loadReaderState();
      return;
    }
    if (action == 'favorite') {
      await QuranReadingStore.saveFavorite(key, !_readingData.favorites.contains(key));
      await _loadReaderState();
      return;
    }
    if (action == 'note') await _editNote(verse);
  }

  Future<void> _editNote(QuranVerse verse) async {
    final key = _key(verse);
    final controller = TextEditingController(text: _readingData.notes[key] ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('ملاحظة • ${widget.surah.name} ${verse.number}'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(hintText: 'اكتب ملاحظتك الخاصة...'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result == null) return;
    await QuranReadingStore.saveNote(key, result);
    await _loadReaderState();
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
                const Text('اضغط مطولاً على الآية لحفظ علامة أو مفضلة أو ملاحظة.'),
                const Divider(height: 30),
              ],
            );
          }
          final verse = widget.surah.verses[index - 1];
          final key = _key(verse);
          final bookmarkType = _readingData.bookmarkColors[key];
          final favorite = _readingData.favorites.contains(key);
          final hasNote = _readingData.notes.containsKey(key);
          final highlighted = widget.initialVerse == verse.number;
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _rememberVerse(verse),
            onLongPress: () => _showVerseActions(verse),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: highlighted ? theme.colorScheme.primaryContainer : null,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: bookmarkType == null ? theme.dividerColor.withValues(alpha: .45) : _bookmarkColor(bookmarkType)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    CircleAvatar(radius: 13, child: Text('${verse.number}', style: const TextStyle(fontSize: 11))),
                    const Spacer(),
                    if (hasNote) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.sticky_note_2_rounded, size: 18, color: Color(0xFF2E6F95))),
                    if (favorite) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.star_rounded, size: 18, color: Color(0xFFC58A28))),
                    if (bookmarkType != null) Icon(Icons.bookmark_rounded, size: 18, color: _bookmarkColor(bookmarkType)),
                  ]),
                  const SizedBox(height: 9),
                  Text(
                    verse.text,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontFamily: 'AmiriQuran', fontSize: _fontSize, height: 2.05),
                  ),
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

Color _bookmarkColor(String type) {
  switch (type) {
    case 'green':
      return const Color(0xFF2E7D4F);
    case 'blue':
      return const Color(0xFF2E6F95);
    case 'red':
      return const Color(0xFFB23A48);
    case 'gold':
    default:
      return const Color(0xFFC58A28);
  }
}

String _dateLabel(DateTime date) => '${date.day}/${date.month}/${date.year}';
