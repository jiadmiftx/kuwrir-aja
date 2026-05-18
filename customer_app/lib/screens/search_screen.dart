import 'package:flutter/material.dart';
import 'package:kuwrir_shared/kuwrir_shared.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final List<String> _recentSearches = [
    'Ayam Taliwang',
    'Nasi Campur',
    'Sate Rembiga',
    'Es Kelapa',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search merchants or product...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: KuwrirColors.textHint),
            filled: false,
          ),
          style: const TextStyle(fontSize: 16),
          onSubmitted: (query) {
            // TODO: Call API search
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _controller.clear(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Searches',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: KuwrirColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentSearches.map((search) {
                return GestureDetector(
                  onTap: () {
                    _controller.text = search;
                    // TODO: Trigger search
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: KuwrirColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: KuwrirColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, size: 16, color: KuwrirColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(search, style: TextStyle(fontSize: 13, color: KuwrirColors.textPrimary)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text(
              'Popular Categories',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: KuwrirColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CategoryTag(label: '🍗 Ayam', onTap: () {}),
                _CategoryTag(label: '🍚 Nasi', onTap: () {}),
                _CategoryTag(label: '🥘 Sate', onTap: () {}),
                _CategoryTag(label: '🥤 Minuman', onTap: () {}),
                _CategoryTag(label: '🍰 Dessert', onTap: () {}),
                _CategoryTag(label: '🌶️ Pedas', onTap: () {}),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTag extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CategoryTag({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: KuwrirColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
