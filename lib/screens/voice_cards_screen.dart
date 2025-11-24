import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../services/api_service.dart';

class VoiceCardsScreen extends StatefulWidget {
  const VoiceCardsScreen({super.key});

  static const String voiceBoardName = 'cartoes_de_voz';

  static const List<_CategoryConfig> categoryConfigs = [
    _CategoryConfig(title: 'Emoções', color: Color(0xFF5C6EF8)),
    _CategoryConfig(title: 'Alimentação', color: Color(0xFF26C6DA)),
    _CategoryConfig(title: 'Atividades', color: Color(0xFFFFA726)),
  ];

  static const List<_CardSeed> defaultSeeds = [
    _CardSeed(category: 'Emoções', label: 'Feliz', emoji: '😊'),
    _CardSeed(category: 'Emoções', label: 'Triste', emoji: '😢'),
    _CardSeed(category: 'Emoções', label: 'Estou Bravo', emoji: '😡'),
    _CardSeed(category: 'Alimentação', label: 'Preciso de Água', emoji: '💧'),
    _CardSeed(category: 'Alimentação', label: 'Faz Pão', emoji: '🍞'),
    _CardSeed(category: 'Alimentação', label: 'Quero Arroz', emoji: '🍚'),
    _CardSeed(category: 'Alimentação', label: 'Quero Maçã', emoji: '🍎'),
    _CardSeed(category: 'Atividades', label: 'Quero Brincar', emoji: '🎮'),
    _CardSeed(category: 'Atividades', label: 'Preciso Dormir', emoji: '😴'),
    _CardSeed(category: 'Atividades', label: 'Vamos estudar', emoji: '📚'),
    _CardSeed(category: 'Atividades', label: 'Vamos caminhar', emoji: '🚶'),
  ];

  static const List<String> emojiPalette = [
    '😀', '😁', '😂', '🤣', '😊', '😍', '😎', '🤩',
    '😢', '😡', '😴', '🤒', '🤗', '🤔', '😇', '😤',
    '🍎', '🍌', '🍓', '🍉', '🍞', '🍚', '🍔', '🍟',
    '🎮', '🚶', '🏃', '📚', '🧩', '🎨', '⚽', '🎵',
  ];

  @override
  State<VoiceCardsScreen> createState() => _VoiceCardsScreenState();
}

class _VoiceCardsScreenState extends State<VoiceCardsScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  final Map<String, Color> _categoryColorMap = {
    for (final config in VoiceCardsScreen.categoryConfigs) config.title: config.color,
  };

  List<_VoiceCategoryData> _categories = [];
  bool _isLoading = true;
  String? _errorMessage;
  int? _boardId;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _configureTts();
    await _loadVoiceCards();
  }

  Future<void> _configureTts() async {
    await _flutterTts.setLanguage('pt-BR');
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setVolume(1.0);
  }

  Future<void> _loadVoiceCards() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final boardsResult = await ApiService.listBoards();
    if (!mounted) return;

    if (boardsResult['success'] != true) {
      setState(() {
        _isLoading = false;
        _errorMessage = boardsResult['message'] ?? 'Não foi possível carregar os cartões.';
      });
      return;
    }

    final data = boardsResult['data'];
    if (data is! List) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Resposta inválida do servidor ao carregar os cartões.';
      });
      return;
    }

    Map<String, dynamic>? board;
    for (final item in data) {
      if (item is Map<String, dynamic> && item['nome'] == VoiceCardsScreen.voiceBoardName) {
        board = item;
        break;
      }
    }

    if (board == null) {
      final createdBoard = await ApiService.createBoard(VoiceCardsScreen.voiceBoardName);
      if (!mounted) return;
      if (createdBoard['success'] == true && createdBoard['data'] is Map<String, dynamic>) {
        board = createdBoard['data'] as Map<String, dynamic>;
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = createdBoard['message'] ?? 'Não foi possível criar o quadro de cartões.';
        });
        return;
      }
    }

    final int? boardId = board['id'] is int ? board['id'] as int : null;
    if (boardId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Quadro de cartões inválido retornado pelo servidor.';
      });
      return;
    }

    final List<dynamic> rawItems = List<dynamic>.from(board['items'] as List? ?? []);

    if (rawItems.isEmpty) {
      // Seed default cards for first-time users
      for (final seed in VoiceCardsScreen.defaultSeeds) {
        final seedResult = await ApiService.createBoardItem(
          boardId: boardId,
          texto: seed.label,
          emoji: seed.emoji,
          categoria: seed.category,
        );
        if (seedResult['success'] == true && seedResult['data'] is Map<String, dynamic>) {
          rawItems.add(seedResult['data']);
        }
      }
    }

    setState(() {
      _boardId = boardId;
      _categories = _buildCategoriesFromItems(rawItems);
      _isLoading = false;
    });
  }

  List<_VoiceCategoryData> _buildCategoriesFromItems(List<dynamic> items) {
    final Map<String, List<_VoiceCardData>> grouped = {
      for (final config in VoiceCardsScreen.categoryConfigs) config.title: <_VoiceCardData>[],
    };

    for (final raw in items) {
      if (raw is! Map<String, dynamic>) continue;
      final idValue = raw['id'];
      if (idValue is! int) continue;

      final label = (raw['texto']?.toString() ?? '').trim();
      if (label.isEmpty) continue;

      final categoryName = (raw['categoria']?.toString() ?? '').trim();
      final emoji = (raw['emoji']?.toString() ?? '').trim();

      final normalizedCategory = categoryName.isEmpty
          ? VoiceCardsScreen.categoryConfigs.first.title
          : categoryName;

      grouped.putIfAbsent(normalizedCategory, () => <_VoiceCardData>[]);
      grouped[normalizedCategory]!.add(
        _VoiceCardData(
          id: idValue,
          label: label,
          emoji: emoji.isEmpty ? '🔈' : emoji,
          category: normalizedCategory,
        ),
      );
    }

    final List<_VoiceCategoryData> categories = [];
    for (final config in VoiceCardsScreen.categoryConfigs) {
      categories.add(
        _VoiceCategoryData(
          title: config.title,
          color: config.color,
          cards: grouped[config.title] ?? <_VoiceCardData>[],
        ),
      );
      grouped.remove(config.title);
    }

    // Any extra categories stored in the backend that are not part of the default config.
    grouped.forEach((title, cards) {
      categories.add(
        _VoiceCategoryData(
          title: title,
          color: _categoryColorMap[title] ?? const Color(0xFF5C6EF8),
          cards: cards,
        ),
      );
    });

    return categories;
  }

  Future<void> _speak(String text) async {
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  Future<void> _handleAddCard(_VoiceCategoryData category) async {
    final boardId = _boardId;
    if (boardId == null) {
      _showSnackBar('Quadro de cartões não carregado.');
      return;
    }

    final result = await _showCardDialog(
      dialogTitle: 'Novo cartão',
      initialEmoji: VoiceCardsScreen.emojiPalette.first,
      initialLabel: '',
    );

    if (result == null) return;

    final apiResult = await ApiService.createBoardItem(
      boardId: boardId,
      texto: result.label,
      emoji: result.emoji,
      categoria: category.title,
    );

    if (apiResult['success'] == true && apiResult['data'] is Map<String, dynamic>) {
      final newCard = _voiceCardFromMap(apiResult['data'] as Map<String, dynamic>);
      if (newCard != null && mounted) {
        setState(() {
          category.cards.add(newCard);
        });
      }
    } else {
      _showSnackBar(apiResult['message'] ?? 'Não foi possível criar o cartão.');
    }
  }

  Future<void> _handleEditCard(
    _VoiceCategoryData category,
    _VoiceCardData card,
  ) async {
    final boardId = _boardId;
    if (boardId == null) {
      _showSnackBar('Quadro de cartões não carregado.');
      return;
    }

    final result = await _showCardDialog(
      dialogTitle: 'Editar cartão',
      initialEmoji: card.emoji,
      initialLabel: card.label,
    );

    if (result == null) return;

    final apiResult = await ApiService.updateBoardItem(
      boardId: boardId,
      itemId: card.id,
      texto: result.label,
      emoji: result.emoji,
      categoria: category.title,
    );

    if (apiResult['success'] == true && apiResult['data'] is Map<String, dynamic>) {
      final updatedCard = _voiceCardFromMap(apiResult['data'] as Map<String, dynamic>);
      if (updatedCard != null && mounted) {
        setState(() {
          final index = category.cards.indexWhere((element) => element.id == card.id);
          if (index != -1) {
            category.cards[index] = updatedCard;
          }
        });
      }
    } else {
      _showSnackBar(apiResult['message'] ?? 'Não foi possível atualizar o cartão.');
    }
  }

  Future<void> _handleDeleteCard(
    _VoiceCategoryData category,
    _VoiceCardData card,
  ) async {
    final boardId = _boardId;
    if (boardId == null) {
      _showSnackBar('Quadro de cartões não carregado.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remover cartão'),
          content: Text('Deseja remover o cartão "${card.label}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remover'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final apiResult = await ApiService.deleteBoardItem(boardId: boardId, itemId: card.id);

    if (apiResult['success'] == true && mounted) {
      setState(() {
        category.cards.removeWhere((element) => element.id == card.id);
      });
    } else {
      _showSnackBar(apiResult['message'] ?? 'Não foi possível remover o cartão.');
    }
  }

  _VoiceCardData? _voiceCardFromMap(Map<String, dynamic> map) {
    final idValue = map['id'];
    if (idValue is! int) return null;
    final label = (map['texto']?.toString() ?? '').trim();
    if (label.isEmpty) return null;
    final emoji = (map['emoji']?.toString() ?? '').trim();
    final category = (map['categoria']?.toString() ?? '').trim();

    return _VoiceCardData(
      id: idValue,
      label: label,
      emoji: emoji.isEmpty ? '🔈' : emoji,
      category: category.isEmpty
          ? VoiceCardsScreen.categoryConfigs.first.title
          : category,
    );
  }

  Future<_VoiceCardFormResult?> _showCardDialog({
    required String dialogTitle,
    required String initialEmoji,
    required String initialLabel,
  }) async {
    final labelController = TextEditingController(text: initialLabel);
    final emojiController = TextEditingController(text: initialEmoji);
    String? labelError;

    return showDialog<_VoiceCardFormResult>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(dialogTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: labelController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Título',
                      border: const OutlineInputBorder(),
                      errorText: labelError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emojiController,
                    readOnly: true,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'Emoji',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.grid_view_rounded),
                        onPressed: () async {
                          final selected = await _showEmojiPicker();
                          if (selected != null) {
                            setStateDialog(() {
                              emojiController.text = selected;
                            });
                          }
                        },
                      ),
                    ),
                    onTap: () async {
                      final selected = await _showEmojiPicker();
                      if (selected != null) {
                        setStateDialog(() {
                          emojiController.text = selected;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final trimmedLabel = labelController.text.trim();
                    if (trimmedLabel.isEmpty) {
                      setStateDialog(() {
                        labelError = 'Informe um título';
                      });
                      return;
                    }

                    final trimmedEmoji = emojiController.text.trim();

                    Navigator.of(context).pop(
                      _VoiceCardFormResult(
                        label: trimmedLabel,
                        emoji: trimmedEmoji.isEmpty
                            ? initialEmoji
                            : trimmedEmoji,
                      ),
                    );
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> _showEmojiPicker() {
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Selecione um emoji'),
          content: SizedBox(
            width: 260,
            height: 220,
            child: GridView.count(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: VoiceCardsScreen.emojiPalette
                  .map(
                    (emoji) => InkWell(
                      onTap: () => Navigator.of(context).pop(emoji),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE3E8EF)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _ErrorView(
                    message: _errorMessage!,
                    onRetry: _loadVoiceCards,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(
                                Icons.arrow_back_ios_new,
                                color: Color(0xFF5C6EF8),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cartões de Voz',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).textTheme.titleLarge?.color ?? 
                                           (Theme.of(context).brightness == Brightness.dark 
                                            ? Colors.white 
                                            : const Color(0xFF2F2F2F)),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Clique para ouvir ou editar',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).textTheme.bodyMedium?.color ?? 
                                           (Theme.of(context).brightness == Brightness.dark 
                                            ? const Color(0xFFB0B4C1) 
                                            : const Color(0xFF6B7280)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadVoiceCards,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              const horizontalPadding = 40.0;
                              const spacing = 10.0;
                              const double minCardWidth = 150.0;
                              final double rawWidth = constraints.maxWidth - horizontalPadding;
                              final double availableWidth = rawWidth > 0 ? rawWidth : constraints.maxWidth;

                              int columns = 1;
                              double cardWidth = availableWidth;

                              for (int candidate = 4; candidate >= 2; candidate--) {
                                final double candidateWidth =
                                    (availableWidth - ((candidate - 1) * spacing)) / candidate;
                                if (candidateWidth >= minCardWidth) {
                                  columns = candidate;
                                  cardWidth = candidateWidth;
                                  break;
                                }
                              }

                              if (columns == 1) {
                                cardWidth = availableWidth;
                              }

                              return SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                child: Column(
                                  children: _categories
                                      .map(
                                        (category) => Padding(
                                          padding: const EdgeInsets.only(bottom: 16),
                                          child: _VoiceCategorySection(
                                            category: category,
                                            columns: columns,
                                            cardWidth: cardWidth,
                                            spacing: spacing,
                                            onSpeak: _speak,
                                            onEdit: (card) => _handleEditCard(category, card),
                                            onDelete: (card) => _handleDeleteCard(category, card),
                                            onAdd: () => _handleAddCard(category),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: const Color(0xFF5C6EF8),
        unselectedItemColor: const Color(0xFFB0B4C1),
        showUnselectedLabels: true,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).pop();
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Início',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_outlined),
            label: 'Diário',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time_outlined),
            label: 'Rotina',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Relatório',
          ),
        ],
      ),
    );
  }
}

class _VoiceCategorySection extends StatelessWidget {
  const _VoiceCategorySection({
    required this.category,
    required this.columns,
    required this.cardWidth,
    required this.spacing,
    required this.onSpeak,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
  });

  final _VoiceCategoryData category;
  final int columns;
  final double cardWidth;
  final double spacing;
  final ValueChanged<String> onSpeak;
  final ValueChanged<_VoiceCardData> onEdit;
  final ValueChanged<_VoiceCardData> onDelete;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CategoryHeader(
            title: category.title,
            color: category.color,
            onAdd: onAdd,
          ),
          const SizedBox(height: 12),
          if (category.cards.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? const Color(0xFF2A2A2A) 
                    : const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? const Color(0xFF3A3A3A) 
                      : const Color(0xFFE3E8EF),
                ),
              ),
              child: Text(
                'Nenhum cartão cadastrado. Toque no + para adicionar.',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color ?? 
                         (Theme.of(context).brightness == Brightness.dark 
                          ? const Color(0xFFB0B4C1) 
                          : const Color(0xFF6B7280)), 
                  fontSize: 13,
                ),
              ),
            )
          else
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: category.cards
                  .map(
                    (card) => SizedBox(
                      width: columns == 1 ? double.infinity : cardWidth,
                      child: _VoiceCardItem(
                        card: card,
                        accentColor: category.color,
                        onSpeak: () => onSpeak(card.label),
                        onEdit: () => onEdit(card),
                        onDelete: () => onDelete(card),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.title,
    required this.color,
    required this.onAdd,
  });

  final String title;
  final Color color;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.add,
                color: color,
                size: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).textTheme.titleLarge?.color ?? 
                   (Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : const Color(0xFF2F2F2F)),
          ),
        ),
      ],
    );
  }
}

class _VoiceCardItem extends StatelessWidget {
  const _VoiceCardItem({
    required this.card,
    required this.accentColor,
    required this.onSpeak,
    required this.onEdit,
    required this.onDelete,
  });

  final _VoiceCardData card;
  final Color accentColor;
  final VoidCallback onSpeak;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
            ? const Color(0xFF2A2A2A) 
            : const Color(0xFFFDFEFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFF3A3A3A) 
              : const Color(0xFFE3E8EF),
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                card.emoji,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  card.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.titleLarge?.color ?? 
                           (Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white 
                            : const Color(0xFF2F2F2F)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _VoiceActionButton(
                icon: Icons.volume_up_rounded,
                backgroundColor: accentColor,
                iconColor: Colors.white,
                onTap: onSpeak,
              ),
              const SizedBox(width: 8),
              _VoiceActionButton(
                icon: Icons.edit_outlined,
                backgroundColor: Theme.of(context).brightness == Brightness.dark 
                    ? const Color(0xFF2A2A2A) 
                    : Colors.white,
                iconColor: accentColor,
                borderColor: Theme.of(context).brightness == Brightness.dark 
                    ? const Color(0xFF3A3A3A) 
                    : const Color(0xFFE3E8EF),
                onTap: onEdit,
              ),
              const SizedBox(width: 8),
              _VoiceActionButton(
                icon: Icons.delete_outline,
                backgroundColor: Theme.of(context).brightness == Brightness.dark 
                    ? const Color(0xFF2A2A2A) 
                    : Colors.white,
                iconColor: const Color(0xFFEF5350),
                borderColor: const Color(0xFFFAD2D0),
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VoiceActionButton extends StatelessWidget {
  const _VoiceActionButton({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.onTap,
    this.borderColor,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final Color? borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: borderColor != null ? Border.all(color: borderColor!) : null,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
        ),
      ),
    );
  }
}

class _VoiceCategoryData {
  _VoiceCategoryData({
    required this.title,
    required this.color,
    List<_VoiceCardData>? cards,
  }) : cards = cards ?? <_VoiceCardData>[];

  final String title;
  final Color color;
  final List<_VoiceCardData> cards;
}

class _VoiceCardData {
  _VoiceCardData({
    required this.id,
    required this.label,
    required this.emoji,
    required this.category,
  });

  final int id;
  final String label;
  final String emoji;
  final String category;
}

class _CategoryConfig {
  const _CategoryConfig({required this.title, required this.color});

  final String title;
  final Color color;
}

class _CardSeed {
  const _CardSeed({required this.category, required this.label, required this.emoji});

  final String category;
  final String label;
  final String emoji;
}

class _VoiceCardFormResult {
  const _VoiceCardFormResult({required this.label, required this.emoji});

  final String label;
  final String emoji;
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF5350)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

