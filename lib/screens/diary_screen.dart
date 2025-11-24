import 'package:flutter/material.dart';

import '../services/api_service.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({
    super.key,
    this.perfil,
  });

  final String? perfil;

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final TextEditingController _alimentacaoController = TextEditingController();
  final TextEditingController _criseController = TextEditingController();

  final TextEditingController _responsavelHumorObsController =
      TextEditingController();
  final TextEditingController _responsavelSonoObsController =
      TextEditingController();
  final TextEditingController _responsavelAlimentacaoObsController =
      TextEditingController();
  final TextEditingController _responsavelCriseObsController =
      TextEditingController();

  String? _selectedMood;
  String? _selectedSleep;
  bool _isSaving = false;

  String? _responsavelHumor;
  String? _responsavelSono;
  String? _responsavelAlimentacao;
  String? _responsavelCrise;

  final List<_DiaryOption> _moodOptions = const [
    _DiaryOption(label: 'Muito feliz', emoji: '😀'),
    _DiaryOption(label: 'Feliz', emoji: '😊'),
    _DiaryOption(label: 'Neutro', emoji: '😐'),
    _DiaryOption(label: 'Triste', emoji: '😔'),
    _DiaryOption(label: 'Muito triste', emoji: '😭'),
  ];

  final List<_DiaryOption> _sleepOptions = const [
    _DiaryOption(label: 'Excelente', emoji: '😴'),
    _DiaryOption(label: 'Bom', emoji: '🙂'),
    _DiaryOption(label: 'Regular', emoji: '😌'),
    _DiaryOption(label: 'Ruim', emoji: '😟'),
    _DiaryOption(label: 'Péssimo', emoji: '😫'),
  ];

  final List<String> _responsavelHumorOptions = const [
    'Calmo',
    'Feliz',
    'Irritado',
  ];

  final List<String> _responsavelSonoOptions = const [
    'Dormiu bem',
    'Agitado',
    'Pouco',
  ];

  final List<String> _responsavelAlimentacaoOptions = const [
    'Comeu bem',
    'Pouco',
    'Recusou',
  ];

  final List<String> _responsavelCriseOptions = const [
    'Não houve',
    'Sim, leve',
    'Forte',
  ];

  bool get _isResponsavel {
    final perfil = (widget.perfil ?? '').toLowerCase();
    return perfil.contains('cuidador') || perfil.contains('respons');
  }

  @override
  void dispose() {
    _alimentacaoController.dispose();
    _criseController.dispose();
    _responsavelHumorObsController.dispose();
    _responsavelSonoObsController.dispose();
    _responsavelAlimentacaoObsController.dispose();
    _responsavelCriseObsController.dispose();
    super.dispose();
  }

  Future<void> _submitDiary() async {
    if (_isResponsavel) {
      if (_responsavelHumor == null ||
          _responsavelSono == null ||
          _responsavelAlimentacao == null ||
          _responsavelCrise == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Selecione uma opção em cada seção (humor, sono, alimentação e crise).',
            ),
          ),
        );
        return;
      }
    } else {
      if (_selectedMood == null || _selectedSleep == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione o humor e a qualidade do sono.'),
          ),
        );
        return;
      }
      if (_alimentacaoController.text.trim().isEmpty ||
          _criseController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Descreva a alimentação e registre se houve alguma crise.',
            ),
          ),
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    final texto = _isResponsavel ? _buildResponsavelTexto() : _buildAutistaTexto();

    // OBTER USERID DO APISERVICE OU DOS ARGUMENTOS DA ROTA
    final userId = ApiService.currentUserId;
    
    final result = await ApiService.createDiaryEntry(
      tipo: 'diario',
      texto: texto,
      tags: _buildTags(),
      timestamp: DateTime.now(),
      userId: userId,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (result['success'] == true) {
      final isOffline = result['offline'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isOffline
                ? 'Diário salvo localmente. Será sincronizado quando houver conexão.'
                : 'Diário registrado com sucesso!',
          ),
          backgroundColor: isOffline ? Colors.orange : Colors.green,
          duration: Duration(seconds: isOffline ? 4 : 2),
        ),
      );
      setState(() {
        if (_isResponsavel) {
          _responsavelHumor = null;
          _responsavelSono = null;
          _responsavelAlimentacao = null;
          _responsavelCrise = null;
          _responsavelHumorObsController.clear();
          _responsavelSonoObsController.clear();
          _responsavelAlimentacaoObsController.clear();
          _responsavelCriseObsController.clear();
        } else {
          _selectedMood = null;
          _selectedSleep = null;
          _alimentacaoController.clear();
          _criseController.clear();
        }
      });
    } else {
      final message = result['message'] as String? ??
          'Não foi possível salvar seu diário. Tente novamente.';
      final detail = result['detail'] as String?;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            detail != null ? '$message\n$detail' : message,
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isResponsavel
        ? _buildResponsavelLayout()
        : _buildAutistaLayout();
  }

  List<String> _buildTags() {
    if (_isResponsavel) {
      return [
        if (_responsavelHumor != null) _responsavelHumor!,
        if (_responsavelSono != null) _responsavelSono!,
        if (_responsavelAlimentacao != null) _responsavelAlimentacao!,
        if (_responsavelCrise != null) _responsavelCrise!,
        'cuidador',
      ];
    }

    return [
      if (_selectedMood != null) _selectedMood!,
      if (_selectedSleep != null) _selectedSleep!,
      if (_alimentacaoController.text.trim().isNotEmpty) 'alimentacao',
      if (_criseController.text.trim().isNotEmpty) 'crise',
    ];
  }

  String _buildAutistaTexto() {
    return [
      'Humor: $_selectedMood',
      'Sono: $_selectedSleep',
      'Alimentação: ${_alimentacaoController.text.trim()}',
      'Crise: ${_criseController.text.trim()}',
    ].join('\n');
  }

  String _buildResponsavelTexto() {
    return [
      'Humor: $_responsavelHumor',
      if (_responsavelHumorObsController.text.trim().isNotEmpty)
        'Observação de humor: ${_responsavelHumorObsController.text.trim()}',
      'Sono: $_responsavelSono',
      if (_responsavelSonoObsController.text.trim().isNotEmpty)
        'Observação de sono: ${_responsavelSonoObsController.text.trim()}',
      'Alimentação: $_responsavelAlimentacao',
      if (_responsavelAlimentacaoObsController.text.trim().isNotEmpty)
        'Observação de alimentação: ${_responsavelAlimentacaoObsController.text.trim()}',
      'Crise: $_responsavelCrise',
      if (_responsavelCriseObsController.text.trim().isNotEmpty)
        'Observação de crise: ${_responsavelCriseObsController.text.trim()}',
    ].join('\n');
  }

  Widget _buildAutistaLayout() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Como foi seu dia?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color ?? 
                         (Theme.of(context).brightness == Brightness.dark 
                          ? Colors.white 
                          : const Color(0xFF2F2F2F)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Registre seu humor e reflita sobre o dia',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color ?? 
                         (Theme.of(context).brightness == Brightness.dark 
                          ? const Color(0xFFB0B4C1) 
                          : const Color(0xFF6B7280)),
                ),
              ),
              const SizedBox(height: 24),
              _buildOptionSection(
                title: 'Qual foi seu humor?',
                options: _moodOptions,
                selectedValue: _selectedMood,
                onSelected: (value) {
                  setState(() {
                    // SE JÁ ESTÁ SELECIONADO, DESMARCAR; CASO CONTRÁRIO, SELECIONAR
                    _selectedMood = _selectedMood == value ? null : value;
                  });
                },
              ),
              const SizedBox(height: 24),
              _buildOptionSection(
                title: 'Como foi seu sono?',
                options: _sleepOptions,
                selectedValue: _selectedSleep,
                onSelected: (value) {
                  setState(() {
                    // SE JÁ ESTÁ SELECIONADO, DESMARCAR; CASO CONTRÁRIO, SELECIONAR
                    _selectedSleep = _selectedSleep == value ? null : value;
                  });
                },
              ),
              const SizedBox(height: 24),
              _buildTextCard(
                title: 'Como foi sua Alimentação?',
                hint: 'O que você comeu hoje? Como foi sua alimentação?',
                controller: _alimentacaoController,
              ),
              const SizedBox(height: 16),
              _buildTextCard(
                title: 'Teve alguma crise?',
                hint:
                    'Descreva se você teve alguma crise ou momento difícil…',
                controller: _criseController,
              ),
              const SizedBox(height: 24),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponsavelLayout() {
    final formattedDate = _formatDate(DateTime.now());
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Diário do Cuidador',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color ?? 
                         (Theme.of(context).brightness == Brightness.dark 
                          ? Colors.white 
                          : const Color(0xFF2F2F2F)),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: Theme.of(context).textTheme.bodyMedium?.color ?? 
                           (Theme.of(context).brightness == Brightness.dark 
                            ? const Color(0xFFB0B4C1) 
                            : const Color(0xFF6B7280)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Data: $formattedDate',
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
              const SizedBox(height: 24),
              _buildResponsavelSection(
                title: 'Humor',
                options: _responsavelHumorOptions,
                selectedValue: _responsavelHumor,
                onSelected: (value) {
                  setState(() {
                    _responsavelHumor = value;
                  });
                },
                noteController: _responsavelHumorObsController,
                showNote: false,
              ),
              const SizedBox(height: 20),
              _buildResponsavelSection(
                title: 'Sono',
                options: _responsavelSonoOptions,
                selectedValue: _responsavelSono,
                onSelected: (value) {
                  setState(() {
                    _responsavelSono = value;
                  });
                },
                noteController: _responsavelSonoObsController,
                showNote: false,
              ),
              const SizedBox(height: 20),
              _buildResponsavelSection(
                title: 'Alimentação',
                options: _responsavelAlimentacaoOptions,
                selectedValue: _responsavelAlimentacao,
                onSelected: (value) {
                  setState(() {
                    _responsavelAlimentacao = value;
                  });
                },
                noteController: _responsavelAlimentacaoObsController,
              ),
              const SizedBox(height: 20),
              _buildResponsavelSection(
                title: 'Crise',
                options: _responsavelCriseOptions,
                selectedValue: _responsavelCrise,
                onSelected: (value) {
                  setState(() {
                    _responsavelCrise = value;
                  });
                },
                noteController: _responsavelCriseObsController,
              ),
              const SizedBox(height: 28),
              _buildSubmitButton(
                label: 'Salvar',
                color: const Color(0xFF5C6EF8),
                icon: Icons.check,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton({
    String label = 'Registrar Diário',
    Color? color,
    IconData? icon,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _submitDiary,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? const Color(0xFFFFB74D),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white,
                  ),
                ),
              )
            : icon != null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18),
                      const SizedBox(width: 8),
                      Text(label),
                    ],
                  )
                : Text(label),
      ),
    );
  }

  Widget _buildOptionSection({
    required String title,
    required List<_DiaryOption> options,
    required String? selectedValue,
    required ValueChanged<String?> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.titleLarge?.color ?? 
                   (Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : const Color(0xFF2F2F2F)),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: options.map((option) {
            final isSelected = selectedValue == option.label;
            return GestureDetector(
              onTap: () => onSelected(option.label),
              child: Container(
                width: 104,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? const Color(0xFFFFF1DB) 
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        isSelected ? const Color(0xFFFFB74D) : const Color(0xFFE5E7EB),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      option.emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      option.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.titleLarge?.color ?? 
                               (Theme.of(context).brightness == Brightness.dark 
                                ? Colors.white 
                                : const Color(0xFF374151)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildResponsavelSection({
    required String title,
    required List<String> options,
    required String? selectedValue,
    required ValueChanged<String?> onSelected,
    required TextEditingController noteController,
    bool showNote = true,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color ?? 
                     (Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white 
                      : const Color(0xFF2F2F2F)),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: options.map((option) {
              final isSelected = option == selectedValue;
              return _buildResponsavelOption(
                label: option,
                selected: isSelected,
                onTap: () {
                  // SE JÁ ESTÁ SELECIONADO, DESMARCAR; CASO CONTRÁRIO, SELECIONAR
                  onSelected(isSelected ? null : option);
                },
              );
            }).toList(),
          ),
          if (showNote) ...[
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                hintText: 'Observação (texto curto)',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF5C6EF8)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResponsavelOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF5C6EF8) : const Color(0xFFE5E7EB),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF5C6EF8)
                      : const Color(0xFFCBD5F5),
                  width: 2,
                ),
                color: selected ? const Color(0xFF5C6EF8) : Colors.white,
              ),
              child: selected
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }


  Widget _buildTextCard({
    required String title,
    required String hint,
    required TextEditingController controller,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.titleLarge?.color ?? 
                     (Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white 
                      : const Color(0xFF2F2F2F)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFFFB74D)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiaryOption {
  const _DiaryOption({
    required this.label,
    required this.emoji,
  });

  final String label;
  final String emoji;
}

