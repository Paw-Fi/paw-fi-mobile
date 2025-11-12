import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
// Uncomment for mobile (iOS/Android) - iOS-style color picker
import 'package:ios_color_picker/show_ios_color_picker.dart';
import 'package:moneko/features/profile/presentation/providers/user_profile_provider.dart';
import 'package:moneko/core/l10n/l10n.dart';

class AvatarCustomizerScreen extends ConsumerStatefulWidget {
  const AvatarCustomizerScreen({super.key});

  @override
  ConsumerState<AvatarCustomizerScreen> createState() => _AvatarCustomizerScreenState();
}

class _AvatarCustomizerScreenState extends ConsumerState<AvatarCustomizerScreen> {
  final _previewKey = GlobalKey();
  bool _isUploading = false;
  int _uploadProgress = 0;
  bool _hasAvatar = false;

  // Categories configuration (aligned with web)
  static const _categories = [
    'face', 'ears', 'shirts', 'hair', 'brow', 'eyes', 'nose', 'mouth', 'blush', 'accessories', 'stars'
  ];

  // Initial selections
  final Map<String, String> _selected = {
    'face': 'Face1',
    'ears': 'Ear1',
    'shirts': 'Shirt1',
    'hair': 'hair1',
    'brow': 'Brow1',
    'eyes': 'Eyes1',
    'nose': 'Nose1',
    'mouth': 'Mouth1',
    'blush': 'blush1',
    'accessories': 'Accessories1',
    'stars': 'Star1',
  };

  // Color selections
  final Map<String, String> _colors = {
    'hair': '#8B4513',
    'eyes': '#4A4A4A',
    'mouth': '#FF6B6B',
    'background': '#f0f0f0',
  };

  String _activeCategory = 'hair';

  @override
  void initState() {
    super.initState();
    _loadExistingCustomization();
  }

  Future<void> _loadExistingCustomization() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    final data = await client
        .from('users')
        .select('avatar_url, avatar_elements, avatar_colors')
        .eq('id', user.id)
        .maybeSingle();

    if (!mounted) return;
    setState(() {
      final avatarUrl = data?['avatar_url'] as String?;
      _hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl != 'SKIPPED';
      final elements = (data?['avatar_elements'] as Map<String, dynamic>?)?.cast<String, String>();
      final colors = (data?['avatar_colors'] as Map<String, dynamic>?)?.cast<String, String>();
      if (elements != null && elements.isNotEmpty) {
        _selected.addAll(elements);
      }
      if (colors != null && colors.isNotEmpty) {
        _colors.addAll(colors);
      }
    });
  }

  // Helpers
  String _getLocalizedCategory(String category) {
    switch (category) {
      case 'face':
        return context.l10n.face;
      case 'ears':
        return context.l10n.ears;
      case 'shirts':
        return context.l10n.shirts;
      case 'hair':
        return context.l10n.hair;
      case 'brow':
        return context.l10n.brow;
      case 'eyes':
        return context.l10n.eyes;
      case 'nose':
        return context.l10n.nose;
      case 'mouth':
        return context.l10n.mouth;
      case 'blush':
        return context.l10n.blush;
      case 'accessories':
        return context.l10n.accessories;
      case 'stars':
        return context.l10n.stars;
      default:
        return category[0].toUpperCase() + category.substring(1);
    }
  }

  Color _hexToColor(String hex) {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }

  String _colorToHex(Color c) {
    String two(int n) => n.toRadixString(16).padLeft(2, '0');
    int toByte(double x) => (x * 255.0).round() & 0xff;
    return '#${two(toByte(c.r))}${two(toByte(c.g))}${two(toByte(c.b))}';
  }

  String _assetPath(String category, String asset) {
    // Map category to folder name
    final folder = {
      'face': '1.face',
      'ears': '2.ears',
      'shirts': '3.shirts',
      'hair': '4.hair',
      'brow': '5.brow',
      'eyes': '6.eyes',
      'nose': '7.nose',
      'mouth': '8.mouth',
      'blush': '9.blush',
      'accessories': '10.accessories',
      'stars': '11.stars',
    }[category]!;
    return 'lib/assets/images/avatar/$folder/$asset.svg';
  }

  List<String> _assetsFor(String category) {
    switch (category) {
      case 'face':
        return ['Face1','Face2','Face3','Face4','Face5','Face6','Face7','Face8'];
      case 'ears':
        return ['Ear1','Ear2','Ear3','Ear4','Ear5','Ear6','Ear7','Ear8','Ear9','Ear10'];
      case 'shirts':
        return ['Shirt1','Shirt2','Shirt3','Shirt4','Shirt5','Shirt6','Shirt7','Shirt8'];
      case 'hair':
        return ['hair1','hair2','hair3','hair4','hair5','hair6','hair7','hair8','hair9','hair10'];
      case 'brow':
        return ['Brow1','Brow2','Brow3','Brow4','Brow5','Brow6','Brow7','Brow8'];
      case 'eyes':
        return ['Eyes1','Eyes2','Eyes3','Eyes4','Eyes5','Eyes6','Eyes7','Eyes8'];
      case 'nose':
        return ['Nose1','Nose2','Nose3','Nose4','Nose5','Nose6','Nose7','Nose8'];
      case 'mouth':
        return ['Mouth1','Mouth2','Mouth3','Mouth4','Mouth5','Mouth6','Mouth7','Mouth8'];
      case 'blush':
        return ['blush1','blush2','blush3','blush4','blush5','blush6'];
      case 'accessories':
        return ['Accessories1','Accessories2','Accessories3','Accessories4','Accessories5','Accessories6','Accessories7','Accessories8'];
      case 'stars':
        return ['Star1','Star2','Star3','Star4','Star5','Star6'];
    }
    return [];
  }

  void _randomize() {
    final rnd = Random();
    final next = <String,String>{};
    for (final c in _categories) {
      final list = _assetsFor(c);
      next[c] = list[rnd.nextInt(list.length)];
    }
    final colorPalettes = {
      'hair': ['#8B4513', '#654321', '#4A4A4A', '#2C1810', '#B8860B', '#800080', '#FF6347', '#32CD32', '#1E90FF'],
      'eyes': ['#4A4A4A', '#8B4513', '#006400', '#0000FF', '#800080', '#2F4F4F', '#B8860B'],
      'mouth': ['#FF6B6B', '#DC143C', '#CD5C5C', '#F08080', '#FF1493', '#C71585'],
      'background': ['#f0f0f0', '#e8f4f8', '#f8e8f4', '#f4f8e8', '#e8e8f8', '#f8f4e8', '#ffffff', '#e0e0e0', '#f5f5f5'],
    };
    setState(() {
      for (final entry in next.entries) {
        _selected[entry.key] = entry.value;
      }
      _colors['hair'] = (colorPalettes['hair']!..shuffle()).first;
      _colors['eyes'] = (colorPalettes['eyes']!..shuffle()).first;
      _colors['mouth'] = (colorPalettes['mouth']!..shuffle()).first;
      _colors['background'] = (colorPalettes['background']!..shuffle()).first;
    });
  }

  Future<void> _skipForNow() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    await client.from('users').update({
      'avatar_url': 'SKIPPED',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  Future<void> _saveAvatar() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    if (_isUploading) return;

    setState(() { _isUploading = true; _uploadProgress = 10; });
    try {
      // Capture widget to image (approx 400x400 like web)
      final boundary = _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Preview not ready');
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to encode image');
      final pngBytes = byteData.buffer.asUint8List();
      setState(() { _uploadProgress = 50; });

      final path = '${user.id}/avatar.png';
      // Upload with upsert
      await client.storage.from('avatars').uploadBinary(
        path,
        pngBytes,
        fileOptions: const FileOptions(
          upsert: true,
          contentType: 'image/png',
          cacheControl: '3600',
        ),
      );

      setState(() { _uploadProgress = 80; });

      final publicUrl = client.storage.from('avatars').getPublicUrl(path);

      await client.from('users').update({
        'avatar_url': '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}',
        'avatar_elements': _selected,
        'avatar_colors': _colors,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      setState(() { _uploadProgress = 100; });
      
      // Invalidate the user profile provider to refresh avatar
      ref.invalidate(userProfileProvider);
      
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/dashboard');
      }
    } catch (e) {
      if (!mounted) return;
      // Use AppToast so the error is visible above any bottom sheet/overlay
      AppToast.error('${context.l10n.failedToSaveAvatar}: $e');
    } finally {
      if (mounted) {
        setState(() { _isUploading = false; _uploadProgress = 0; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = shadcnui.Theme.of(context).colorScheme;
    return shadcnui.DrawerOverlay(
      child: Scaffold(
        backgroundColor: scheme.background,
        appBar: AppBar(
          backgroundColor: scheme.background,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: scheme.foreground),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            },
          ),
          title: Text(context.l10n.avatarStudio, style: TextStyle(color: scheme.foreground, fontWeight: FontWeight.w600)),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // Preview Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.card,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.preview, style: TextStyle(fontWeight: FontWeight.w600, color: scheme.mutedForeground)),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar preview square
                        Expanded(
                          flex: 2,
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: RepaintBoundary(
                              key: _previewKey,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _hexToColor(_colors['background']!),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Stack(
                                  children: _categories.map((c) {
                                    final asset = _selected[c]!;
                                    final path = _assetPath(c, asset);
                                    ColorFilter? filter;
                                    if (c == 'hair') {
                                      filter = ColorFilter.mode(_hexToColor(_colors['hair']!), BlendMode.srcIn);
                                    } else if (c == 'eyes') {
                                      filter = ColorFilter.mode(_hexToColor(_colors['eyes']!), BlendMode.srcIn);
                                    } else if (c == 'mouth') {
                                      filter = ColorFilter.mode(_hexToColor(_colors['mouth']!), BlendMode.srcIn);
                                    }
                                    double scale;
                                    if (c == 'accessories' || c == 'stars') {
                                      scale = 0.75;
                                    } else if (c == 'hair') {
                                      scale = 0.9;
                                    } else if (c == 'shirts') {
                                      scale = 0.85;
                                    } else {
                                      scale = 0.8;
                                    }
                                    return Positioned.fill(
                                      child: Center(
                                        child: FractionallySizedBox(
                                          widthFactor: scale,
                                          heightFactor: scale,
                                          alignment: Alignment.center,
                                          child: SvgPicture.asset(
                                            path,
                                            fit: BoxFit.contain,
                                            colorFilter: filter,
                                            allowDrawingOutsideViewBox: true,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Colors on the right
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(context.l10n.colors, style: TextStyle(fontWeight: FontWeight.w600, color: scheme.mutedForeground)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _colorControl(context, context.l10n.hair, 'hair'),
                                  _colorControl(context, context.l10n.eyes, 'eyes'),
                                  _colorControl(context, context.l10n.mouth, 'mouth'),
                                  _colorControl(context, context.l10n.background, 'background'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Category chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((c) {
                    final active = _activeCategory == c;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        selected: active,
                        label: Text(_getLocalizedCategory(c)),
                        onSelected: (_) => setState(() => _activeCategory = c),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 12),

              // Asset grid
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.card,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final crossAxisCount = width > 380 ? 4 : 3;
                    final items = _assetsFor(_activeCategory);
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final asset = items[i];
                        final selected = _selected[_activeCategory] == asset;
                        final path = _assetPath(_activeCategory, asset);
                        return GestureDetector(
                          onTap: () => setState(() => _selected[_activeCategory] = asset),
                          child: Container(
                            decoration: BoxDecoration(
                              color: selected ? scheme.primary.withValues(alpha: 0.08) : scheme.muted.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: selected ? scheme.primary : scheme.border),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: SvgPicture.asset(
                              path,
                              fit: BoxFit.contain,
                              allowDrawingOutsideViewBox: true,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: shadcnui.OutlineButton(
                      onPressed: _isUploading ? null : _randomize,
                      child: Text(context.l10n.randomize),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: shadcnui.PrimaryButton(
                      onPressed: _isUploading ? null : _saveAvatar,
                      child: Text(_isUploading ? '${context.l10n.saving} $_uploadProgress%' : context.l10n.saveAvatar),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (!_hasAvatar)
                SizedBox(
                  width: double.infinity,
                  child: shadcnui.OutlineButton(
                    onPressed: _isUploading ? null : _skipForNow,
                    child: Text(context.l10n.skipForNow),
                  ),
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  // Compact color selector: tap to cycle palette
  Widget _colorControl(BuildContext context, String label, String key) {
    final scheme = shadcnui.Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _openColorPicker(context, key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.muted.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: _hexToColor(_colors[key]!),
                shape: BoxShape.circle,
                border: Border.all(color: scheme.border.withValues(alpha: 0.6)),
              ),
            ),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: scheme.foreground, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  void _openColorPicker(BuildContext context, String key) {
    final current = _hexToColor(_colors[key]!);
    
    // ==================== COLOR PICKER OPTIONS ====================
    // Uncomment the appropriate color picker based on your target platform:
    
    // OPTION 1: Web Color Picker (flutter_colorpicker) - Works on all platforms
    // Use this for web builds or if you want a consistent UI across all platforms
    
    // showDialog(
    //   context: context,
    //   builder: (BuildContext context) {
    //     return AlertDialog(
    //       title: Text('Select ${key} color'),
    //       content: SingleChildScrollView(
    //         child: ColorPicker(
    //           pickerColor: current,
    //           onColorChanged: (color) {
    //             setState(() {
    //               _colors[key] = _colorToHex(color);
    //             });
    //           },
    //         ),
    //       ),
    //       actions: <Widget>[
    //         TextButton(
    //           child: const Text('Done'),
    //           onPressed: () {
    //             Navigator.of(context).pop();
    //           },
    //         ),
    //       ],
    //     );
    //   },
    // );
    
    
    // OPTION 2: Mobile Color Picker (ios_color_picker) - Native iOS-style picker
    // Use this for iOS/Android builds to get the native color picker experience
    // NOTE: Requires uncommenting the ios_color_picker import at the top of this file
    
    final iosColorPickerController = IOSColorPickerController();
    iosColorPickerController.showIOSCustomColorPicker(
      startingColor: current,
      onColorChanged: (color) {
        setState(() {
          _colors[key] = _colorToHex(color);
        });
      },
      context: context,
    );

    
  }

  // ignore: unused_element
  void _cycleColor(String key) {
    final palettes = <String, List<String>>{
      'hair': ['#8B4513', '#654321', '#4A4A4A', '#2C1810', '#B8860B', '#800080', '#FF6347', '#32CD32', '#1E90FF'],
      'eyes': ['#4A4A4A', '#8B4513', '#006400', '#0000FF', '#800080', '#2F4F4F', '#B8860B'],
      'mouth': ['#FF6B6B', '#DC143C', '#CD5C5C', '#F08080', '#FF1493', '#C71585'],
      'background': ['#f0f0f0', '#e8f4f8', '#f8e8f4', '#f4f8e8', '#e8e8f8', '#f8f4e8', '#ffffff', '#e0e0e0', '#f5f5f5'],
    };
    final list = palettes[key]!;
    final current = _colors[key]!;
    final idx = list.indexOf(current);
    final next = list[(idx + 1) % list.length];
    setState(() { _colors[key] = next; });
  }
}
